






#import "UIViewController+PPNavBar.h"
#import <objc/runtime.h>
#import "ChatPresenceManager.h"
#import "PPModernAvatarRenderer.h"
#pragma mark - Accessors

static inline UIView *PPBarForVC(UIViewController *vc) {
    return objc_getAssociatedObject(vc, kPPNavBarViewKey);
}
static inline UILabel *PPTitleForVC(UIViewController *vc) {
    return objc_getAssociatedObject(vc, kPPTitleLabelKey);
}
static inline UIStackView *PPLeftForVC(UIViewController *vc) {
    return objc_getAssociatedObject(vc, kPPLeftStackKey);
}
static inline UIStackView *PPRightForVC(UIViewController *vc) {
    return objc_getAssociatedObject(vc, kPPRightStackKey);
}
static inline NSMutableDictionary<NSString *, UIButton *> *PPDictForVC(UIViewController *vc, BOOL create) {
    NSMutableDictionary *d = objc_getAssociatedObject(vc, kPPButtonsDictKey);
    if (!d && create) {
        d = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(vc, kPPButtonsDictKey, d, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return d;
}

static NSString * const PPNavSupportAvatarToken = @"purepets://support-logo";

static BOOL PPNavUsesSupportLogo(UserModel *user) {
    NSString *avatarURL = user.UserImageUrl.absoluteString ?: @"";
    return [avatarURL hasPrefix:PPNavSupportAvatarToken];
}

static UIImage *PPNavSupportLogoImage(void) {
    return [UIImage imageNamed:@"newlogo"] ?: [UIImage systemImageNamed:@"person.crop.circle.fill"];
}

#pragma mark - Private helpers

@implementation UIViewController (PPNavBar)


-(id)presenceToken
{
    return objc_getAssociatedObject(self, @selector(presenceToken));
}

-(void)setPresenceToken:(id)presenceToken
{
    objc_setAssociatedObject(self,
                             @selector(presenceToken),
                             presenceToken,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIView *)pp_chatProfileHeaderViewWithUser:(UserModel *)user
{
    // Root container (fixed height, nav-bar safe)
    
    // Animate status + online dot
    __block NSString *newStatusText = @"";

    NSString *presenceUserID = user.ID.length > 0 ? user.ID : (user.ID ?: @"");

    if (user.isOnline) {
        newStatusText = kLang(@"Online");
    } else if (user.lastSeen) {
        newStatusText = [ChManager formattedLastSeen:user.lastSeen];
    } else {
        newStatusText = @"";
    }
    
   
 
    
    UIButtonConfiguration *config;
    if (@available(iOS 26.0, *)) {
        config = [UIButtonConfiguration glassButtonConfiguration];
    } else if (@available(iOS 15.0, *)) {
        config = [UIButtonConfiguration plainButtonConfiguration];
    }
    if (config) {
        config.background.backgroundColor = UIColor.clearColor;
        config.baseBackgroundColor = UIColor.clearColor;
    }
    UIButton *container = [UIButton buttonWithConfiguration:config primaryAction:nil];
    container.configuration = config;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = UIColor.clearColor;

    // Avatar
    UIImageView *avatar = [[UIImageView alloc] init];
    avatar.translatesAutoresizingMaskIntoConstraints = NO;
    avatar.contentMode = UIViewContentModeScaleAspectFill;
    avatar.clipsToBounds = YES;
    avatar.layer.cornerRadius = 16; // 32 / 2
    avatar.backgroundColor = UIColor.secondarySystemBackgroundColor;

    if (PPNavUsesSupportLogo(user)) {
        avatar.image = PPNavSupportLogoImage();
        avatar.contentMode = UIViewContentModeScaleAspectFit;
        avatar.backgroundColor = UIColor.whiteColor;
    } else if (user.UserImageUrl.absoluteString.length > 0) {
        avatar.contentMode = UIViewContentModeScaleAspectFill;
        avatar.backgroundColor = UIColor.secondarySystemBackgroundColor;
        avatar.image = [PPModernAvatarRenderer avatarImageForName:user.UserName size:32];
        [GM setImageFromUrlString:user.UserImageUrl.absoluteString
                        imageView:avatar
                          phImage:@"person.crop.circle.fill"
                        completion:nil];
    } else {
        avatar.image = [PPModernAvatarRenderer avatarImageForName:user.UserName size:32];
        avatar.contentMode = UIViewContentModeScaleAspectFill;
        avatar.backgroundColor = UIColor.secondarySystemBackgroundColor;
    }

    // Labels container
    UIView *labels = [UIView new];
    labels.translatesAutoresizingMaskIntoConstraints = NO;
    labels.backgroundColor = UIColor.clearColor;

    // Title (username)
    UILabel *titleLabel = [UILabel new];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:16];
    titleLabel.textColor = AppShadowClr;
    titleLabel.text = user.UserName ?: @"";
    titleLabel.numberOfLines = 1;
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    // Subtitle (online / typing / last seen)
    UILabel *subtitleLabel = [UILabel new];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:13];
    subtitleLabel.textColor = [AppShadowClr colorWithAlphaComponent:0.2];
    subtitleLabel.text = newStatusText ?: @"";
    
    
   
    
    
    // --- Animate status label crossfade ---
    if (![subtitleLabel.text isEqualToString:newStatusText]) {
        [UIView transitionWithView:subtitleLabel
                          duration:0.2
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            subtitleLabel.text = newStatusText;
        } completion:nil];
    }
    
    
    subtitleLabel.numberOfLines = 1;
    subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    
    // Online status dot
    UIView *onlineDot = [UIView new];
    onlineDot.translatesAutoresizingMaskIntoConstraints = NO;
    onlineDot.layer.cornerRadius = 4;
    onlineDot.layer.masksToBounds = YES;
    
    
    // Build hierarchy
    [container addSubview:avatar];
    [container addSubview:onlineDot];
    [container addSubview:labels];
    [labels addSubview:titleLabel];
    [labels addSubview:subtitleLabel];
     
    // Layout (ABSOLUTELY STABLE)
    [NSLayoutConstraint activateConstraints:@[
        
        [container.heightAnchor constraintEqualToConstant:44],

        
        // Avatar
        [avatar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:4],
        [avatar.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [avatar.widthAnchor constraintEqualToConstant:36],
        [avatar.heightAnchor constraintEqualToConstant:36],
       // [avatar.topAnchor constraintEqualToAnchor:container.topAnchor],
       // [avatar.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        
        
        // Labels container
        [labels.leadingAnchor constraintEqualToAnchor:avatar.trailingAnchor constant:10],
        [labels.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor constant:-8],
        [labels.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],

        // Title
        [titleLabel.topAnchor constraintEqualToAnchor:labels.topAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:labels.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:labels.trailingAnchor],
        
        

        // Subtitle
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:1],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:labels.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:labels.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:labels.bottomAnchor],
        
        // Online dot (tail)
        [onlineDot.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [onlineDot.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-8],
        [onlineDot.widthAnchor constraintEqualToConstant:8],
        [onlineDot.heightAnchor constraintEqualToConstant:8],
        // Extra trailing padding for container content
        [labels.trailingAnchor constraintLessThanOrEqualToAnchor:onlineDot.leadingAnchor constant:-8],
    ]];
    // Online / offline state handling
    onlineDot.hidden = NO;

    if (user.isOnline) {
        onlineDot.backgroundColor = UIColor.systemGreenColor;
        onlineDot.alpha = 1.0;
        [self pp_startOnlinePulse:onlineDot];
    } else {
        onlineDot.backgroundColor = UIColor.systemGray3Color;
        onlineDot.alpha = 1.0;
        [self pp_stopOnlinePulse:onlineDot];
    }
    
 
    void (^applyPresenceUI)(BOOL online, NSDate *lastSeen) = ^(BOOL online, NSDate *lastSeen) {
        if (online) {
            newStatusText = kLang(@"Online");
            onlineDot.backgroundColor = UIColor.systemGreenColor;
            onlineDot.alpha = 1.0;
            [self pp_startOnlinePulse:onlineDot];
        } else if (lastSeen) {
            newStatusText = [ChManager formattedLastSeen:lastSeen];
            onlineDot.backgroundColor = UIColor.systemGray3Color;
            onlineDot.alpha = 1.0;
            [self pp_stopOnlinePulse:onlineDot];
        } else {
            newStatusText = @"";
            onlineDot.backgroundColor = UIColor.systemGray3Color;
            onlineDot.alpha = 1.0;
            [self pp_stopOnlinePulse:onlineDot];
        }

        if (![subtitleLabel.text isEqualToString:newStatusText]) {
            [UIView transitionWithView:subtitleLabel
                              duration:0.2
                               options:UIViewAnimationOptionTransitionCrossDissolve
                            animations:^{
                subtitleLabel.text = newStatusText;
            } completion:nil];
        }
    };

    if (self.presenceToken) {
        [[ChatPresenceManager shared] removePresenceObserver:self.presenceToken];
        self.presenceToken = nil;
    }

    if (presenceUserID.length > 0) {
        [[ChatPresenceManager shared] startObservingUsers:@[presenceUserID]];

        BOOL online = [[ChatPresenceManager shared] isUserOnline:presenceUserID];
        NSDate *lastSeen = [[ChatPresenceManager shared] lastSeenForUser:presenceUserID];
        applyPresenceUI(online, lastSeen);

        self.presenceToken =
        [[ChatPresenceManager shared]
         addPresenceObserver:^(NSString *userID) {
            if (![userID isEqualToString:presenceUserID]) return;
            BOOL online = [[ChatPresenceManager shared] isUserOnline:userID];
            NSDate *lastSeen = [[ChatPresenceManager shared] lastSeenForUser:userID];
            applyPresenceUI(online, lastSeen);
        }];
    }
    
    
     
    return container;
}

// Pulse animation helpers for online dot
#pragma mark - Online Dot Animations

static NSString * const kPPOnlinePulseKey = @"pp_online_pulse";

- (void)pp_startOnlinePulse:(UIView *)dot
{
    if ([dot.layer animationForKey:kPPOnlinePulseKey]) return;

    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulse.fromValue = @1.0;
    pulse.toValue = @1.35;
    pulse.duration = 1.2;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    pulse.timingFunction =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

    [dot.layer addAnimation:pulse forKey:kPPOnlinePulseKey];
}

- (void)pp_stopOnlinePulse:(UIView *)dot
{
    [dot.layer removeAnimationForKey:kPPOnlinePulseKey];
    dot.transform = CGAffineTransformIdentity;
}


- (void)pp_navBarForceRefresh
{
    UINavigationBar *navBar = self.navigationController.navigationBar;
    if (!navBar) return;

    // 🧹 1. Force layout + appearance re-application
    [navBar setNeedsLayout];
    [navBar layoutIfNeeded];

    if (@available(iOS 15.0, *)) {
        UINavigationBarAppearance *appearance = navBar.standardAppearance ?: [[UINavigationBarAppearance alloc] init];
        [appearance configureWithTransparentBackground];
        appearance.backgroundColor = UIColor.clearColor;
        appearance.shadowColor = UIColor.clearColor;

        navBar.standardAppearance = appearance;
        navBar.scrollEdgeAppearance = appearance;
        navBar.compactAppearance = appearance;
    }

    // 🧠 2. Re-apply tint color & title color consistency
    UIColor *currentTint = navBar.tintColor ?: AppPrimaryTextClr ?: UIColor.labelColor;
    [self pp_navBarForceTintColor:currentTint];

    // 🪄 3. Rebuild any custom PPNavBar views if needed
    UIView *bar = objc_getAssociatedObject(self, kPPNavBarViewKey);
    if (bar) {
        [bar setNeedsLayout];
        [bar layoutIfNeeded];
        bar.alpha = 1.0;
    }

    // 🧩 4. Force redraw all nav items
    self.navigationItem.titleView.alpha = 0.99;
    [UIView animateWithDuration:0.15 animations:^{
        self.navigationItem.titleView.alpha = 1.0;
    }];

    // 🧱 5. (Optional) fix weird flicker in iOS 26 when translucency changes
    if (@available(iOS 26.0, *)) {
        navBar.translucent = YES;
        navBar.opaque = NO;
        [navBar setNeedsDisplay];
        [navBar layoutIfNeeded];
    }

    DLog(@"[PPNavBar] 🔄 Force-refreshed navigation bar (layout + tint reapplied)");
}

- (void)pp_navBarForceTintColor:(UIColor *)tintColor
{
    if (!tintColor) return;
    UINavigationBar *navBar = self.navigationController.navigationBar;
    if (!navBar) return;

    // --- Apply to UINavigationBarAppearance ---
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithTransparentBackground];
    appearance.backgroundColor = UIColor.clearColor;
    appearance.shadowColor = UIColor.clearColor;
    appearance.titleTextAttributes = @{ NSForegroundColorAttributeName: tintColor };
    appearance.largeTitleTextAttributes = @{ NSForegroundColorAttributeName: tintColor };

    navBar.tintColor = tintColor;
    navBar.standardAppearance = appearance;
    navBar.scrollEdgeAppearance = appearance;
    navBar.compactAppearance = appearance;

    // --- Apply to your custom PPNavBar container ---
    UIView *bar = objc_getAssociatedObject(self, kPPNavBarViewKey);
    if (bar) {
        bar.tintColor = tintColor;
        bar.backgroundColor = UIColor.clearColor;
    }

    // --- Custom title label ---
    UILabel *titleLbl = objc_getAssociatedObject(self, kPPTitleLabelKey);
    if (titleLbl) {
        titleLbl.textColor = tintColor;
    }

    // --- Left & Right stack buttons / labels ---
    UIStackView *left = objc_getAssociatedObject(self, kPPLeftStackKey);
    UIStackView *right = objc_getAssociatedObject(self, kPPRightStackKey);

    void (^applyToStack)(UIStackView *) = ^(UIStackView *stack) {
        for (UIView *view in stack.arrangedSubviews) {
            if ([view isKindOfClass:[UIButton class]]) {
                UIButton *btn = (UIButton *)view;
                btn.tintColor = tintColor;
                [btn setTitleColor:tintColor forState:UIControlStateNormal];
                if (btn.imageView) {
                    btn.imageView.tintColor = tintColor;
                }
            } else if ([view isKindOfClass:[UILabel class]]) {
                ((UILabel *)view).textColor = tintColor;
            } else if ([view isKindOfClass:[UIImageView class]]) {
                ((UIImageView *)view).tintColor = tintColor;
            }
        }
    };

    if (left) applyToStack(left);
    if (right) applyToStack(right);

    // --- Also iterate any registered buttons in PPDictForVC ---
    NSMutableDictionary *dict = PPDictForVC(self, NO);
    for (UIButton *btn in dict.allValues) {
        btn.tintColor = tintColor;
        [btn setTitleColor:tintColor forState:UIControlStateNormal];
        if (btn.imageView) btn.imageView.tintColor = tintColor;
    }

    // --- Apply globally for nav item bar button items (system-level) ---
    for (UIBarButtonItem *item in self.navigationItem.leftBarButtonItems) {
        item.tintColor = tintColor;
        [item setTitleTextAttributes:@{NSForegroundColorAttributeName: tintColor} forState:UIControlStateNormal];
    }
    for (UIBarButtonItem *item in self.navigationItem.rightBarButtonItems) {
        item.tintColor = tintColor;
        [item setTitleTextAttributes:@{NSForegroundColorAttributeName: tintColor} forState:UIControlStateNormal];
    }

    DLog(@"[PPNavBar] 🎨 Force-applied tint color to all nav bar elements: %@", tintColor);
}


#pragma mark - NavBar Color Reset (Light / Dark adaptive fix)
- (void)pp_navBarResetAppearanceForBackgroundIsDark:(BOOL)isDark
{
    UINavigationBar *navBar = self.navigationController.navigationBar;
    if (!navBar) return;

    // --- Appearance (applies to system items only) ---
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithTransparentBackground];
    appearance.backgroundColor = UIColor.clearColor;
    appearance.shadowColor = UIColor.clearColor;

    UIColor *tintColor = isDark ? UIColor.whiteColor : UIColor.darkGrayColor;

    appearance.titleTextAttributes = @{ NSForegroundColorAttributeName: tintColor };
    appearance.largeTitleTextAttributes = @{ NSForegroundColorAttributeName: tintColor };

    navBar.tintColor = tintColor;
    navBar.standardAppearance = appearance;
    navBar.scrollEdgeAppearance = appearance;
    navBar.compactAppearance = appearance;
    navBar.translucent = YES;

    // --- Force recolor your custom PPNavBar subviews ---
    UIView *bar = objc_getAssociatedObject(self, kPPNavBarViewKey);
    if (bar) {
        bar.tintColor = tintColor;
        bar.backgroundColor = UIColor.clearColor;
    }

    // Custom title label
    UILabel *titleLbl = objc_getAssociatedObject(self, kPPTitleLabelKey);
    if (titleLbl) {
        titleLbl.textColor = tintColor;
    }

    // Recolor any buttons in your left/right stacks
    UIStackView *left = objc_getAssociatedObject(self, kPPLeftStackKey);
    UIStackView *right = objc_getAssociatedObject(self, kPPRightStackKey);

    for (UIView *v in left.arrangedSubviews) {
        if ([v isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)v;
            btn.tintColor = tintColor;
            [btn setTitleColor:tintColor forState:UIControlStateNormal];
        } else if ([v isKindOfClass:[UILabel class]]) {
            ((UILabel *)v).textColor = tintColor;
        }
    }

    for (UIView *v in right.arrangedSubviews) {
        if ([v isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)v;
            btn.tintColor = tintColor;
            [btn setTitleColor:tintColor forState:UIControlStateNormal];
        } else if ([v isKindOfClass:[UILabel class]]) {
            ((UILabel *)v).textColor = tintColor;
        }
    }

    DLog(@"[PPNavBar] 🎨 Force refreshed custom title & icons to %@ color", isDark ? @"white" : @"black");
}
 
#pragma mark - Custom Title View (legacy center keeps working)

- (UIView * _Nullable)pp_navBarForeTitleView:(UIView *)navBarTitleView {
    // legacy behavior -> center
    return [self pp_navBarSetTitleViewCentered:navBarTitleView];
}

#pragma mark - New: Title View at Left / Center / Right

- (UIView * _Nullable)pp_navBarSetTitleView:(UIView * _Nullable)titleView
                                   position:(PPNavBarTitlePosition)position
                            replaceExisting:(BOOL)replaceExisting
{
    NSAssert(self.navigationController, @"pp_navBarSetTitleView requires a UINavigationController.");

    // Ensure our custom bar exists
    UIView *bar = PPBarForVC(self);
    if (!bar) { bar = [self pp_navBarAttachWithTitle:nil]; }

 
    UIStackView *left  = PPLeftForVC(self);
    UIStackView *right = PPRightForVC(self);

    
    left.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    right.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    // 1) remove the default centered UILabel if any (we’re taking over the title role)
    UILabel *lbl = PPTitleForVC(self);
    if (lbl) {
        [lbl removeFromSuperview];
        objc_setAssociatedObject(self, kPPTitleLabelKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    // 2) remove previously inserted custom centered view (if any)
    //    find any subview pinned to bar center and clear its constraints
    //    (we identify by checking constraints to bar.centerX/centerY)
    for (UIView *v in bar.subviews) {
        if (v == left || v == right) continue;
        BOOL pinnedCenter = NO;
        for (NSLayoutConstraint *c in bar.constraints) {
            if ((c.firstItem == v && c.firstAttribute == NSLayoutAttributeCenterX) ||
                (c.firstItem == v && c.firstAttribute == NSLayoutAttributeCenterY)) {
                pinnedCenter = YES; break;
            }
        }
        if (pinnedCenter) { [v removeFromSuperview]; }
    }

    // 3) Add the new title view depending on position
    if (!titleView) { return nil; }
    titleView.translatesAutoresizingMaskIntoConstraints = NO;

    switch (position) {
        case PPNavBarTitlePositionLeft: {
            
            
            if (!left) { return nil; }
            if (replaceExisting) {
                for (UIView *v in [left.arrangedSubviews copy]) {
                    [left removeArrangedSubview:v]; [v removeFromSuperview];
                }
            }
            [left addArrangedSubview:titleView];
            // give it sane hugging so it doesn't push buttons
             
            [titleView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                       forAxis:UILayoutConstraintAxisHorizontal];
            [titleView setContentHuggingPriority:UILayoutPriorityRequired
                                         forAxis:UILayoutConstraintAxisHorizontal];

            
            //[titleView.widthAnchor constraintGreaterThanOrEqualToConstant:self.view.hx_w*0.6].active = YES;
        } break;

        case PPNavBarTitlePositionRight: {
            if (!right) { return nil; }
            if (replaceExisting) {
                for (UIView *v in [right.arrangedSubviews copy]) {
                    [right removeArrangedSubview:v]; [v removeFromSuperview];
                }
            }
            [right addArrangedSubview:titleView];
            [titleView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
            [titleView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        } break;

        case PPNavBarTitlePositionCenterSmall: {
            // add as a plain subview centered in the bar, with guards so it doesn’t overlap stacks
            [bar addSubview:titleView];
            [NSLayoutConstraint activateConstraints:@[
                [titleView.centerXAnchor constraintEqualToAnchor:bar.centerXAnchor],
                 // keep clear of the left/right stacks
                [titleView.leadingAnchor constraintEqualToAnchor:left.leadingAnchor constant:90.0],
                [titleView.trailingAnchor constraintEqualToAnchor:right.trailingAnchor constant:-90.0],
                [titleView.heightAnchor constraintEqualToAnchor:bar.heightAnchor],
            ]];
            [titleView setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
            [titleView setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        } break;
            
        case PPNavBarTitlePositionTabBar: {
            // add as a plain subview centered in the bar, with guards so it doesn’t overlap stacks
            [bar addSubview:titleView];
            [NSLayoutConstraint activateConstraints:@[
                [titleView.centerXAnchor constraintEqualToAnchor:bar.centerXAnchor],
                [titleView.topAnchor constraintEqualToAnchor:bar.topAnchor constant:0],
                // keep clear of the left/right stacks
                [titleView.leadingAnchor constraintEqualToAnchor:left.leadingAnchor constant:90.0],
                [titleView.trailingAnchor constraintEqualToAnchor:right.trailingAnchor constant:-90.0],
            ]];
            [titleView setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
            [titleView setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        } break;
            
            
        case PPNavBarTitlePositionCenter:
        default: {
            // add as a plain subview centered in the bar, with guards so it doesn’t overlap stacks
            [bar addSubview:titleView];
            [NSLayoutConstraint activateConstraints:@[
                [titleView.centerXAnchor constraintEqualToAnchor:bar.centerXAnchor],
                [titleView.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor constant:0],
                // keep clear of the left/right stacks
                [titleView.leadingAnchor constraintGreaterThanOrEqualToAnchor:left.trailingAnchor constant:8.0],
                [titleView.trailingAnchor constraintLessThanOrEqualToAnchor:right.leadingAnchor constant:-8.0],
            ]];
            [titleView setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
            [titleView setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        } break;
    }
    
   
    //titleView.backgroundColor = UIColor.whiteColor;
    return titleView;
}
// Safe Presentation Helper
- (void)safePresentViewController:(UIViewController *)vc
                         animated:(BOOL)animated
                       completion:(void (^)(void))completion {
    if (self.presentedViewController) {
        // Wait for current presentation to finish dismissing
        [self dismissViewControllerAnimated:YES completion:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentViewController:vc animated:animated completion:completion];
            });
        }];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentViewController:vc animated:animated completion:completion];
        });
    }
}

- (UIView * _Nullable)pp_navBarSetTitleViewOnLeft:(UIView * _Nullable)titleView replace:(BOOL)replaceExisting {
    return [self pp_navBarSetTitleView:titleView position:PPNavBarTitlePositionLeft replaceExisting:replaceExisting];
}

- (UIView * _Nullable)pp_navBarSetTitleViewOnRight:(UIView * _Nullable)titleView replace:(BOOL)replaceExisting {
    return [self pp_navBarSetTitleView:titleView position:PPNavBarTitlePositionRight replaceExisting:replaceExisting];
}

- (UIView * _Nullable)pp_navBarSetTitleViewCentered:(UIView * _Nullable)titleView {
    return [self pp_navBarSetTitleView:titleView position:PPNavBarTitlePositionCenter replaceExisting:YES];
}

- (UIView * _Nullable)pp_navBarSetTitleViewCenteredSmallWidth:(UIView * _Nullable)titleView {
    return [self pp_navBarSetTitleView:titleView position:PPNavBarTitlePositionCenterSmall replaceExisting:YES];
}

#pragma mark - Attach base bar (left/title/right)
- (UIView *)pp_navBarAttachWithTitle:(NSString * _Nullable)titleString {
    NSAssert(self.navigationController, @"pp_navBar requires a UINavigationController.");

    UINavigationBar *navBar = self.navigationController.navigationBar;
    navBar.backgroundColor = UIColor.clearColor;
    [navBar setSemanticContentAttribute:
        Language.isRTL ? UISemanticContentAttributeForceRightToLeft
                       : UISemanticContentAttributeForceLeftToRight];

    UIView *bar = PPBarForVC(self);
    if (bar) {
        UILabel *titleLabel = PPTitleForVC(self);
        if (titleLabel) {
            titleLabel.text = titleString ?: (self.title ?: @"");
        }
        return bar;
    }

    // ✅ Use the pass-through container
    PPNavBarContainer *container = [PPNavBarContainer new];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = UIColor.clearColor;
    [container setSemanticContentAttribute:
        Language.isRTL ? UISemanticContentAttributeForceRightToLeft
                       : UISemanticContentAttributeForceLeftToRight];

    // Keep your old behavior for back button visibility as you wish.
    self.navigationItem.hidesBackButton = YES;

    // Create Left Stack for buttons
    UIStackView *left = [[UIStackView alloc] init];
    left.translatesAutoresizingMaskIntoConstraints = NO;
    left.axis = UILayoutConstraintAxisHorizontal;
    left.alignment = UIStackViewAlignmentCenter;
    left.spacing = 8;

    // Create Title Label
    UILabel *titleLbl = [UILabel new];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    titleLbl.font = [GM boldFontWithSize:20];
    titleLbl.textColor = AppPrimaryTextClr;
    titleLbl.textAlignment = NSTextAlignmentCenter;
    titleLbl.adjustsFontSizeToFitWidth = YES;
    titleLbl.minimumScaleFactor = 0.75;

    // Create Right Stack for buttons
    UIStackView *right = [[UIStackView alloc] init];
    right.translatesAutoresizingMaskIntoConstraints = NO;
    right.axis = UILayoutConstraintAxisHorizontal;
    right.alignment = UIStackViewAlignmentCenter;
    right.spacing = 6;

    // Add the container below the navigation bar’s own content (critical)
    [navBar addSubview:container];
    // ⬇️ Make sure it's behind UIBarButtonItems / title views so taps on them are not blocked
    [navBar sendSubviewToBack:container];

    [container addSubview:left];
    [container addSubview:titleLbl];
    [container addSubview:right];

    CGFloat navBarPadding = 6;
    CGFloat navBarHeight = 44;
    if (@available(iOS 26.0, *))
    {
        navBarPadding = 0;
        navBarHeight = 44;
    }

    UILayoutGuide *m = navBar.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        
        
        // Container constraints
        [container.topAnchor constraintEqualToAnchor:navBar.topAnchor],
        [container.heightAnchor constraintEqualToConstant:navBarHeight],
        [container.leadingAnchor constraintEqualToAnchor:m.leadingAnchor constant:navBarPadding],
        [container.trailingAnchor constraintEqualToAnchor:m.trailingAnchor constant:-navBarPadding],
        
        // Left stack (buttons) constraints
        [left.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [left.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],

        // Right stack (buttons) constraints
        [right.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [right.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],

        // Title label constraints
        [titleLbl.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [titleLbl.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [titleLbl.leadingAnchor constraintGreaterThanOrEqualToAnchor:left.trailingAnchor constant:-15],
        [titleLbl.trailingAnchor constraintLessThanOrEqualToAnchor:right.leadingAnchor constant:15],
    ]];
    
    navBar.backgroundColor =[UIColor.brownColor colorWithAlphaComponent:0.0];
    container.backgroundColor = [UIColor.yellowColor colorWithAlphaComponent:0.0];
    container.opaque = NO;
    navBar.translucent = YES;   // very important for showing content behind
    navBar.opaque = NO;         // makes sure it doesn’t flatten blending
    NSLog(@"NavBar opaque=%d translucent=%d background=%@",
          self.navigationController.navigationBar.isOpaque,
          self.navigationController.navigationBar.isTranslucent,
          self.navigationController.navigationBar.backgroundColor);


    objc_setAssociatedObject(self, kPPNavBarViewKey, container, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, kPPTitleLabelKey, titleLbl, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, kPPLeftStackKey, left, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, kPPRightStackKey, right, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    PPDictForVC(self, YES);

    // Set the title for the navigation bar
    [self pp_navBarSetTitle:titleString];
   
    return container;
}


+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method origAppear = class_getInstanceMethod(self, @selector(viewWillAppear:));
        Method swzAppear  = class_getInstanceMethod(self, @selector(pp_swz_viewWillAppear:));
        method_exchangeImplementations(origAppear, swzAppear);
        
        Method origDisappear = class_getInstanceMethod(self, @selector(viewWillDisappear:));
        Method swzDisappear  = class_getInstanceMethod(self, @selector(pp_swz_viewWillDisappear:));
        method_exchangeImplementations(origDisappear, swzDisappear);

        Class class = [UIViewController class];
        SEL originalSelector = @selector(viewDidLoad);
        SEL swizzledSelector = @selector(pp_swizzledViewDidLoad);
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        BOOL didAdd = class_addMethod(class,
                                      originalSelector,
                                      method_getImplementation(swizzledMethod),
                                      method_getTypeEncoding(swizzledMethod));
        if (didAdd) {
            class_replaceMethod(class,
                                swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

-(void)onDissmiss
{
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}

#pragma mark - Swizzled implementations

- (void)pp_swz_viewWillAppear:(BOOL)animated {
    // call original
    [self pp_swz_viewWillAppear:animated];
    
    // if this VC already has a PPNavBar attached, make sure it's visible
    UIView *bar = objc_getAssociatedObject(self, kPPNavBarViewKey);
    if (bar) {
        [self pp_navBarSetVisible:YES animated:NO];
    }
}

- (void)pp_swz_viewWillDisappear:(BOOL)animated {
    [self pp_swz_viewWillDisappear:animated];

    if (self.presenceToken) {
        [[ChatPresenceManager shared] removePresenceObserver:self.presenceToken];
        self.presenceToken = nil;
    }

    [self pp_removeNavBar];
}
 
- (void)pp_navBarSetTitle:(NSString *)titleString {
    UILabel *lbl = PPTitleForVC(self);
    if (!lbl) {
        if (!PPBarForVC(self)) {
            [self pp_navBarAttachWithTitle:titleString];
            lbl = PPTitleForVC(self);
        }
        if (!lbl) {
            return;
        }
    }
    lbl.text = titleString ?: (self.title ?: @"");
}

#pragma mark - Your original API (compat)

- (UIView *)pp_navBarWithOtherButton:(UIButton * _Nullable)otherBtn
                               title:(NSString * _Nullable)titleString
{
    UIView *bar = [self pp_navBarAttachWithTitle:titleString];
    
    // Ensure default back on LEFT (your old behavior)
    if (!PPDictForVC(self, NO)[kPPKeyBaseBack]) {
        UIButton *back = [self pp_ButtonWithSystemName:PPChevronName action:@selector(onBack)];
        [self _pp_addLeftButton:back key:kPPKeyBaseBack];
    }
    
    // Trailing "other" (RIGHT)
    if (otherBtn) {
        [self _pp_addRightButton:otherBtn key:kPPKeyBaseButton];
    } else {
        [self pp_navBarRemoveButtonForKey:kPPKeyBaseButton];
    }
    return bar;
}

- (void)pp_removeNavBar {
    UIView *bar = PPBarForVC(self);
    if (bar) [bar removeFromSuperview];
    objc_setAssociatedObject(self, kPPNavBarViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, kPPTitleLabelKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, kPPLeftStackKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, kPPRightStackKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, kPPButtonsDictKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Base layout you asked for

- (UIView * _Nullable)pp_navBarApplyBase:(PPNavBarBaseLayout)layout
                                  button:(UIButton * _Nullable)button
                                   title:(NSString * _Nullable)title
                                showBack:(BOOL)showBack
{
    // [nil][nil][nil] → remove bar
    if (!button && !title && !showBack) { [self pp_removeNavBar]; return nil; }
    
    // Attach (or reuse)
    UIView *bar = [self pp_navBarAttachWithTitle:title];

    // Clean current base items
    [self pp_navBarRemoveButtonForKey:kPPKeyBaseBack];
    [self pp_navBarRemoveButtonForKey:kPPKeyBaseButton];
    
    // Ensure default back on LEFT (your old behavior)
    if (showBack) {
        /* The check below is redundant because kPPKeyBaseBack was removed above. If showBack is YES, the back button will always be added. */
        if (!PPDictForVC(self, NO)[kPPKeyBaseBack]) {
            UIButton *back = [self pp_ButtonWithSystemName:PPChevronName action:@selector(onBack)];
            [self _pp_addLeftButton:back key:kPPKeyBaseBack];
        }
    }
    
    if (button) {
        [self _pp_addRightButton:button key:kPPKeyBaseButton];
    } else {
        [self pp_navBarRemoveButtonForKey:kPPKeyBaseButton];
    }
    
    // Title (center)
    [self pp_navBarSetTitle:title];
    
    return bar;
}


#pragma mark - Base layout you asked for


#pragma mark - Default back
-(void)onBackBar:(UIBarButtonItem *)sender
{
    [self onBack];
}
-(void)onBack:(UIButton *)sender
{
    [self onBack];
}
- (void)onBack {
    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (UIView *)PPLTRNavigationBarWithButton:(UIButton *)button title:(NSString *)title showBack:(BOOL)showBack {
    return [self pp_navBarApplyBase:PPNavBarBaseLayoutLTR button:button title:title showBack:showBack];
}
- (UIView *)PPRTLNavigationBarWithButton:(UIButton *)button title:(NSString *)title showBack:(BOOL)showBack {
    return [self pp_navBarApplyBase:PPNavBarBaseLayoutRTL button:button title:title showBack:showBack];
}

#pragma mark - Visibility

- (void)pp_navBarSetVisible:(BOOL)visible animated:(BOOL)animated {
    
    UIView *bar = PPBarForVC(self);
    UINavigationBar *navBar = self.navigationController.navigationBar;
    
    if (visible) {
        
        // 🔹 Show system nav bar
        [self.navigationController setNavigationBarHidden:NO animated:animated];
        
        // Reset appearance
        navBar.alpha = 1.0;
        navBar.backgroundColor = nil;
        navBar.translucent = YES;
        
        // Custom bar
        if (bar) {
            if (!animated) {
                bar.hidden = NO;
                bar.alpha = 1.0;
            } else {
                bar.hidden = NO;
                bar.alpha = 0;
                [UIView animateWithDuration:0.25 animations:^{
                    bar.alpha = 1.0;
                }];
            }
        }
        
    } else {
        
        // 🔻 Make system nav bar transparent BEFORE hiding
        navBar.alpha = 0.0;
        navBar.backgroundColor = UIColor.clearColor;
        
        // iOS 13+ clean transparent appearance
        if (@available(iOS 13.0, *)) {
            UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
            [appearance configureWithTransparentBackground];
            navBar.standardAppearance = appearance;
            navBar.scrollEdgeAppearance = appearance;
        }
        
        // Hide system nav bar
        [self.navigationController setNavigationBarHidden:YES animated:animated];
        
        // Custom bar
        if (bar) {
            if (!animated) {
                bar.alpha = 0;
                bar.hidden = YES;
            } else {
                [UIView animateWithDuration:0.25 animations:^{
                    bar.alpha = 0;
                } completion:^(BOOL finished) {
                    bar.hidden = YES;
                }];
            }
        }
    }
}

#pragma mark - Keyed icon buttons (advanced)

- (UIButton *)pp_navBarSetRightIcon:(NSString *)systemImage key:(NSString *)key
                             target:(id)target action:(SEL)action
                                tap:(PPNavBarTapBlock)tapBlock
{
    UIView *bar = PPBarForVC(self); if (!bar) [self pp_navBarAttachWithTitle:nil];
    UIButton *btn = PPDictForVC(self, YES)[key];
    if (!btn) {
        btn = [self _pp_makeIconButton:systemImage target:target action:action tap:tapBlock];
        [self _pp_addRightButton:btn key:key];
    } else {
        [btn setImage:[UIImage systemImageNamed:systemImage] forState:UIControlStateNormal];
        [self _pp_updateButton:btn target:target action:action tap:tapBlock];
    }
    return btn;
}

- (UIButton *)pp_navBarSetLeftIcon:(NSString *)systemImage  key:(NSString *)key
                            target:(id)target action:(SEL)action
                               tap:(PPNavBarTapBlock)tapBlock
{
    UIView *bar = PPBarForVC(self); if (!bar) [self pp_navBarAttachWithTitle:nil];
    UIButton *btn = PPDictForVC(self, YES)[key];
    if (!btn) {
        btn = [self _pp_makeIconButton:systemImage target:target action:action tap:tapBlock];
        [self _pp_addLeftButton:btn key:key];
    } else {
        [btn setImage:[UIImage systemImageNamed:systemImage] forState:UIControlStateNormal];
        [self _pp_updateButton:btn target:target action:action tap:tapBlock];
    }
    return btn;
}

- (void)pp_navBarHideButtonForKey:(NSString *)key hidden:(BOOL)hidden animated:(BOOL)animated {
    UIButton *btn = PPDictForVC(self, NO)[key];
    if (!btn) return;
    if (!animated) { btn.hidden = hidden; return; }
    [UIView animateWithDuration:0.2 animations:^{ btn.alpha = hidden ? 0.f : 1.f; } completion:^(BOOL f){ btn.hidden = hidden; }];
}

- (void)pp_navBarRemoveButtonForKey:(NSString *)key {
    NSMutableDictionary *dict = PPDictForVC(self, NO);
    UIButton *btn = dict[key]; if (!btn) return;
    [btn removeFromSuperview];
    [dict removeObjectForKey:key];
}

 
- (UIButton *)makeIOS26PlainButtonWithTitle:(NSString *)title
                                      image:(UIImage *)image
                                     action:(SEL)action {

    UIButton *button = [UIButton new];
    CGFloat btnSize = PPIOS26() ? 38 :38 ;
    
    
    
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
 
 
        config.baseForegroundColor = UIColor.labelColor;
        config.background.backgroundColor = UIColor.clearColor;
         button.configuration = config;

        

    } else {
        [button setTitle:title forState:UIControlStateNormal];
        [button setImage:image forState:UIControlStateNormal];
        button.tintColor = UIColor.labelColor;
     }
    [button setImage:image forState:UIControlStateNormal];

    button.adjustsImageWhenHighlighted = NO;
    button.layer.cornerRadius = btnSize/2;
    button.clipsToBounds = YES;
    
   

    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];

    return button;
}
#pragma mark - PPButton circle button helper
- (UIButton *)pp_ButtonWithSystemName:(NSString *)imageName action:(SEL)action {
    UIButton *btn;
    CGFloat btnSize = PPIOS26() ? 44 :38 ;

    if (@available(iOS 26.0, *)) {
        
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
        //cfg.background.backgroundColor = AppBackgroundClrShiner ?: [UIColor colorWithWhite:0.95 alpha:1.0];

        btn = [UIButton new];
        btn.configuration = cfg;
        [btn setImage:[UIImage systemImageNamed:imageName] forState:UIControlStateNormal];
    }
    else if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
        
        // ✅ Set background color through configuration
        cfg.background.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.6] ?: [UIColor colorWithWhite:0.95 alpha:1.0];
        cfg.background.cornerRadius = btnSize / 2;
        
        btn = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
        btn.clipsToBounds = YES;
    } else {
        btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.contentEdgeInsets = UIEdgeInsetsMake(6, 6, 6, 6);
         btn.layer.cornerRadius = btnSize/2;
         btn.clipsToBounds = YES;
    }

    // Try SF Symbol first → fallback to asset
    UIImage *icon = [UIImage systemImageNamed:imageName];
    if (!icon) {
        icon = [UIImage imageNamed:imageName];
        icon = [UIImage pp_resizedImage:icon toPointSize:PPIOS26() ? 18 : 15];
    }

    if (!icon) {
        DLog(@"[pp_circleButton] ⚠️ No image found for name: %@", imageName);
        icon = [UIImage new]; // fallback empty
    }
    
    if([imageName isEqualToString:@"headset"]) {
        icon = [[UIImage pp_resizedImage:icon toPointSize:18] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }

    [btn setImage:icon forState:UIControlStateNormal];

    btn.translatesAutoresizingMaskIntoConstraints = NO;
    
    
    // ✅ Remove the old backgroundColor assignment for iOS 15+
    if (@available(iOS 26.0, *)) {
        // Background is already set in configuration
        //btn.tintColor = AppPrimaryClr ?: [UIColor systemBlueColor];
    } else {
        btn.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.6] ?: [UIColor colorWithWhite:0.95 alpha:1.0];
        btn.layer.cornerRadius = btnSize/2;
        btn.layer.masksToBounds = YES;
        
        btn.tintColor = UIColor.labelColor;
        
        [self addLiquidGlassBorderToView:btn];
    }

    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    
    [btn.widthAnchor constraintEqualToConstant:btnSize].active = YES;
    [btn.heightAnchor constraintEqualToConstant:btnSize].active = YES;
    
    [btn pp_setShadowColor:AppShadowClr];
    btn.layer.shadowOpacity = 0.07;
    btn.layer.shadowOffset = CGSizeMake(0, 2);
    btn.layer.shadowRadius = 6;
    btn.layer.masksToBounds = NO; // shadow needs this

    
    // 🔹 If it's SF Symbol, apply config
    if ([UIImage systemImageNamed:imageName]) {
        UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:20
                                                        weight:UIImageSymbolWeightRegular
                                                         scale:UIImageSymbolScaleMedium];
        [btn setImage:[icon imageByApplyingSymbolConfiguration:config]
              forState:UIControlStateNormal];
        btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    } else {
        btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    
    //[PPButtonHelper attachTapAnimationToButton:btn style:PPButtonAnimationStylePulse];
    return btn;
}


#pragma mark - PPButton circle button helper
- (UIButton *)pp_ButtonWithSystemNameForNav:(NSString *)imageName action:(SEL)action {
    UIButton *btn;
    CGFloat btnSize = PPIOS26() ? 44 :38 ;

    if (@available(iOS 26.0, *)) {
        
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
        //cfg.background.backgroundColor = AppBackgroundClrShiner ?: [UIColor colorWithWhite:0.95 alpha:1.0];

        btn = [UIButton new];
        btn.configuration = cfg;
        [btn setImage:[UIImage systemImageNamed:imageName] forState:UIControlStateNormal];
    }
    else if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
        
        // ✅ Set background color through configuration
        cfg.background.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.6] ?: [UIColor colorWithWhite:0.95 alpha:1.0];
        cfg.background.cornerRadius = btnSize / 2;
        
        btn = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
        btn.clipsToBounds = YES;
    } else {
        btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.contentEdgeInsets = UIEdgeInsetsMake(6, 6, 6, 6);
         btn.layer.cornerRadius = btnSize/2;
         btn.clipsToBounds = YES;
    }

    // Try SF Symbol first → fallback to asset
    UIImage *icon = [UIImage systemImageNamed:imageName];
    if (!icon) {
        icon = [UIImage imageNamed:imageName];
        icon = [UIImage pp_resizedImage:icon toPointSize:PPIOS26() ? 18 : 15];
    }

    if (!icon) {
        DLog(@"[pp_circleButton] ⚠️ No image found for name: %@", imageName);
        icon = [UIImage new]; // fallback empty
    }
    
    if([imageName isEqualToString:@"headset"]) {
        icon = [[UIImage pp_resizedImage:icon toPointSize:18] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }

    [btn setImage:icon forState:UIControlStateNormal];

    btn.translatesAutoresizingMaskIntoConstraints = NO;
    
    
    // ✅ Remove the old backgroundColor assignment for iOS 15+
    if (@available(iOS 26.0, *)) {
        // Background is already set in configuration
        //btn.tintColor = AppPrimaryClr ?: [UIColor systemBlueColor];
    } else {
        btn.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.6] ?: [UIColor colorWithWhite:0.95 alpha:1.0];
        btn.layer.cornerRadius = btnSize/2;
        btn.layer.masksToBounds = YES;
        
        btn.tintColor = UIColor.labelColor;
        
        [self addLiquidGlassBorderToView:btn];
    }

    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    
    [btn.widthAnchor constraintEqualToConstant:btnSize].active = YES;
    [btn.heightAnchor constraintEqualToConstant:btnSize].active = YES;
    
    [btn pp_setShadowColor:AppShadowClr];
    btn.layer.shadowOpacity = 0.07;
    btn.layer.shadowOffset = CGSizeMake(0, 2);
    btn.layer.shadowRadius = 6;
    btn.layer.masksToBounds = NO; // shadow needs this

    
    // 🔹 If it's SF Symbol, apply config
    if ([UIImage systemImageNamed:imageName]) {
        UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:20
                                                        weight:UIImageSymbolWeightRegular
                                                         scale:UIImageSymbolScaleMedium];
        [btn setImage:[icon imageByApplyingSymbolConfiguration:config]
              forState:UIControlStateNormal];
        btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    } else {
        btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    
    //[PPButtonHelper attachTapAnimationToButton:btn style:PPButtonAnimationStylePulse];
    return btn;
}

#pragma mark - PPButton circle button helper
- (UIButton *)pp_ZeroButtonWithSystemName:(NSString *)imageName action:(nullable SEL)action {
    UIButton *btn;
 
    if (@available(iOS 26.0, *)) {
        
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
        btn = [UIButton new];
        btn.configuration = cfg;
        [btn setImage:[UIImage systemImageNamed:imageName] forState:UIControlStateNormal];
    }
    else if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
        
        // ✅ Set background color through configuration
        cfg.background.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.6] ?: [UIColor colorWithWhite:0.95 alpha:1.0];
 
        btn = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
        btn.clipsToBounds = YES;
    } else {
        btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.contentEdgeInsets = UIEdgeInsetsMake(6, 6, 6, 6);
        btn.clipsToBounds = YES;
        btn.layer.cornerRadius = 22;
     }

    // Try SF Symbol first → fallback to asset
    UIImage *icon = [UIImage systemImageNamed:imageName];
    if (!icon) {
        icon = [UIImage imageNamed:imageName];
        icon = [UIImage pp_resizedImage:icon toPointSize:PPIOS26() ? 18 : 15];
    }

    if (!icon) {
        DLog(@"[pp_circleButton] ⚠️ No image found for name: %@", imageName);
        icon = [UIImage new]; // fallback empty
    }
    
    if([imageName isEqualToString:@"headset"]) {
        icon = [[UIImage pp_resizedImage:icon toPointSize:18] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }

    [btn setImage:icon forState:UIControlStateNormal];

    btn.translatesAutoresizingMaskIntoConstraints = NO;
    
    
    // ✅ Remove the old backgroundColor assignment for iOS 15+
    if (@available(iOS 26.0, *)) {
        // Background is already set in configuration
        //btn.tintColor = AppPrimaryClr ?: [UIColor systemBlueColor];
    } else {
        btn.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.6] ?: [UIColor colorWithWhite:0.95 alpha:1.0];
        btn.layer.masksToBounds = YES;
        btn.tintColor = UIColor.labelColor;
        [self addLiquidGlassBorderToView:btn];
    }

    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    
    [btn pp_setShadowColor:AppShadowClr];
    btn.layer.shadowOpacity = 0.04;
    btn.layer.shadowOffset = CGSizeMake(0, 2);
    btn.layer.shadowRadius = 6;
    btn.layer.masksToBounds = NO; // shadow needs this

    
    // 🔹 If it's SF Symbol, apply config
    if ([UIImage systemImageNamed:imageName]) {
        UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:20
                                                        weight:UIImageSymbolWeightRegular
                                                         scale:UIImageSymbolScaleMedium];
        [btn setImage:[icon imageByApplyingSymbolConfiguration:config]
              forState:UIControlStateNormal];
        btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    } else {
        btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    
    //[PPButtonHelper attachTapAnimationToButton:btn style:PPButtonAnimationStylePulse];
    return btn;
}



- (void)addLiquidGlassBorderToView:(UIView *)view {
    // Remove any old effect
    for (CALayer *layer in view.layer.sublayers.copy) {
        if ([layer.name isEqualToString:@"liquidGlassBorder"]) {
            [layer removeFromSuperlayer];
        }
    }

    // Outer glow
    CALayer *glow = [CALayer layer];
    glow.name = @"liquidGlassBorder";
    glow.frame = view.bounds;
    glow.cornerRadius = 18.0;
    glow.borderWidth = 1.0;
    glow.borderColor = [[UIColor colorWithWhite:1 alpha:0.5] CGColor];
    glow.shadowColor = AppShadowClr.CGColor;
    glow.shadowOpacity = 0.9;
    glow.shadowRadius = 8;
    glow.shadowOffset = CGSizeMake(0, 0);
    glow.shouldRasterize = YES;
    glow.rasterizationScale = UIScreen.mainScreen.scale;
    [view.layer addSublayer:glow];

    // Keep it updated on layout
    glow.needsDisplayOnBoundsChange = YES;

   

   /*
    // Animate shimmer (slow)
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    anim.fromValue = @0;
    anim.toValue = @(M_PI * 2);
    anim.duration = 12.0;
    anim.repeatCount = HUGE_VALF;
    [gradient addAnimation:anim forKey:@"liquidShimmer"];
    */
}

#pragma mark - PPButton circle button helper
- (UIButton *)pp_ButtonForNav:(NSString *)imageName action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    
    btn.contentEdgeInsets = UIEdgeInsetsMake(6, 6, 6, 6);
    if (@available(iOS 26.0, *)) {
    }
    else  {
        btn.backgroundColor = AppForgroundColr ?: [UIColor colorWithWhite:0.95 alpha:1.0];
        btn.layer.cornerRadius = 22;
        btn.layer.masksToBounds = NO;
        
        [btn pp_setShadowColor:AppShadowClr];
        btn.layer.shadowOpacity = 0.07;
        btn.layer.shadowOffset = CGSizeMake(0, 2);
        btn.layer.shadowRadius = 6;
        btn.layer.masksToBounds = NO; // shadow needs this

    }

    // Try SF Symbol first → fallback to asset
    UIImage *icon = [UIImage systemImageNamed:imageName];
    if (!icon) {
        icon = [UIImage imageNamed:imageName];
        icon = [UIImage pp_resizedImage:icon toPointSize:18];
    }
    
    
    [btn setImage:icon forState:UIControlStateNormal];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.tintColor = AppPrimaryClr ?:AppButtonMixColorClr;
     

    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    
    if (@available(iOS 26.0, *)) {}
    else
    {
        [btn.widthAnchor constraintEqualToConstant:44].active = YES;
        [btn.heightAnchor constraintEqualToConstant:44].active = YES;
    }
     
    return btn;
}




/* The above old implementation of pp_ButtonWithSystemName is left in comments.
 * If it's no longer needed, consider removing it to avoid confusion and keep the code clean. */

#pragma mark - Button plumbing

/*- (void)_pp_addRightButton:(UIButton *)btn key:(NSString *)key {
    UIStackView *right = PPRightForVC(self); if (!right) return;
    PPDictForVC(self, YES)[key] = btn;
    [right addArrangedSubview:btn];
}*/

- (void)_pp_addRightButton:(UIButton *)btn key:(NSString *)key {
    UIStackView *right = PPRightForVC(self);
    if (!right) return;
    
    // Add the button to the stack view
    [right addArrangedSubview:btn];
    PPDictForVC(self, YES)[key] = btn;
}

- (void)_pp_addLeftButton:(UIButton *)btn key:(NSString *)key {
    UIStackView *left = PPLeftForVC(self); if (!left) return;
    PPDictForVC(self, YES)[key] = btn;
    [left addArrangedSubview:btn];
}
- (void)_pp_updateButton:(UIButton *)btn target:(id)target action:(SEL)action tap:(PPNavBarTapBlock)tapBlock {
    [btn removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    if (target && action) [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    objc_setAssociatedObject(btn, kPPTapBlockKey, tapBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [btn addTarget:self action:@selector(_pp_tapRelay:) forControlEvents:UIControlEventTouchUpInside];
}
- (UIButton *)_pp_makeIconButton:(NSString *)systemImage target:(id)target action:(SEL)action tap:(PPNavBarTapBlock)tapBlock {
    UIButton *b = [self pp_ButtonWithSystemName:systemImage action:action ?: @selector(_pp_dummy)];
    [self _pp_updateButton:b target:target action:action tap:tapBlock];
    return b;
}
- (void)_pp_dummy {}
- (void)_pp_tapRelay:(UIButton *)sender {
    PPNavBarTapBlock blk = objc_getAssociatedObject(sender, kPPTapBlockKey);
    if (blk) blk();
}

#pragma mark - Force Replace Helpers (RTL/LTR aware)

- (void)forceReplaceLeftButtonWith:(UIButton *)btn {
    UIStackView *left = PPLeftForVC(self);
    if (!left) return;
    
    // 🔥 Remove existing left buttons
    for (UIView *v in left.arrangedSubviews) {
        [left removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    
    // 🔹 Add new one
    if (btn) {
        [left addArrangedSubview:btn];
        // store with a stable key
        PPDictForVC(self, YES)[@"forceLeft"] = btn;
    }
    
    DLog(@"[PPNavBar] 🔄 Force replaced LEFT button (RTL=%d)", Language.isRTL);
}

- (void)forceReplaceRightButtonWith:(UIButton *)btn {
    UIStackView *right = PPRightForVC(self);
    if (!right) return;
    
    // 🔥 Remove existing right buttons
    for (UIView *v in right.arrangedSubviews) {
        [right removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    
    // 🔹 Add new one
    if (btn) {
        [right addArrangedSubview:btn];
        PPDictForVC(self, YES)[@"forceRight"] = btn;
    }
    
    DLog(@"[PPNavBar] 🔄 Force replaced RIGHT button (RTL=%d)", Language.isRTL);
}


- (void)setProfileContainer:(UIView *)container
                  barHeight:(CGFloat)barHeight
                      Image:(UIImage * _Nullable)image
                   andTitle:(NSString * _Nullable)title
                andSubtitle:(NSString * _Nullable)subtitle
                  userModel:(UserModel * _Nullable)usr
                 finalStack:(UIStackView * _Nullable * _Nonnull)finalStackPtr

{
    
    // --- 2️⃣ Animation (if not logged in)
        LOTAnimationView *animationView = nil;
    if (!PPCurrentFIRAuthUser &&
        [[NSBundle mainBundle] pathForResource:@"AddUserIconAnimation" ofType:@"json"].length > 0) {
        animationView = [LOTAnimationView animationNamed:@"AddUserIconAnimation"];
        animationView.translatesAutoresizingMaskIntoConstraints = NO;
        animationView.loopAnimation = YES;
        animationView.hidden = NO;
        animationView.contentMode = UIViewContentModeScaleAspectFit;
        [NSLayoutConstraint activateConstraints:@[
            [animationView.widthAnchor constraintEqualToConstant:barHeight],
            [animationView.heightAnchor constraintEqualToConstant:barHeight]
        ]];
        [animationView play];
    }

    // --- 3️⃣ Image container (for user or static icon)
    UIView *imageContainer = [self createImageContainerWithSize:barHeight image:image userModel:usr];

    // --- 4️⃣ Title label
    PPInsetLabel *titleLabel = [self configuredLabelWithText:(PPCurrentFIRAuthUser ? title : kLang(@"JoinUs"))
                                                        font:[GM boldFontWithSize:18]
                                                   textColor:(AppPrimaryTextClr ?: UIColor.labelColor)];
    
    // --- 5️⃣ Subtitle label (optional)
    PPInsetLabel *subtitleLabel = nil;
    if (subtitle.length > 0) {
        subtitleLabel = [self configuredLabelWithText:(PPCurrentFIRAuthUser ? subtitle : kLang(@"Register"))
                                                 font:[GM MidFontWithSize:11]
                                            textColor:(AppSecondaryTextClr ?: UIColor.secondaryLabelColor)];
    }

    // --- 6️⃣ Vertical text stack
    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:
                              subtitleLabel ? @[titleLabel, subtitleLabel] : @[titleLabel]];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.alignment = UIStackViewAlignmentLeading;
    textStack.spacing = 2;
    textStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    // --- 7️⃣ Horizontal main stack
    NSArray *horizontalItems = PPCurrentFIRAuthUser ? @[imageContainer, textStack] : @[animationView ?: imageContainer, textStack];
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:horizontalItems];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 6;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.distribution = UIStackViewDistributionFill;
    stack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    [container addSubview:stack];

    // assign to the caller’s variable via pointer
    if (finalStackPtr) {
        *finalStackPtr = stack;
    }

    
}
- (UIView * _Nullable)pp_Profile26Image:(UIImage * _Nullable)image
                              andTitle:(NSString * _Nullable)title
                           andSubtitle:(NSString * _Nullable)subtitle
                             userModel:(UserModel * _Nullable)usr
{
    // --- 1️⃣ Container (UIButton gives tap support)
    UIView *container =  (UIView *)[PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleCapsule];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.layer.cornerRadius = self.navigationController.navigationBar.hx_h / 2;
    container.clipsToBounds = YES;
    CGFloat barHeight =  44;
    
    if (!PPIOS26()) {
        container.backgroundColor = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
    }
    //else
       // [container.heightAnchor constraintEqualToConstant:barHeight].active = YES;
   

    UIStackView *finalStack = nil;
    [self setProfileContainer:container
                    barHeight:barHeight
                        Image:image
                     andTitle:title
                  andSubtitle:subtitle
                    userModel:usr
                   finalStack:&finalStack];

    // --- 8️⃣ Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        [finalStack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:0],
         [finalStack.topAnchor constraintEqualToAnchor:container.topAnchor],
        [finalStack.heightAnchor constraintEqualToAnchor:container.heightAnchor],
       // [stack.heightAnchor constraintEqualToAnchor:container.heightAnchor]

    ]];

    // --- 9️⃣ Let the container auto-size its width
  
    if (@available(iOS 26.0, *)) {
        
    } else {
        [container.heightAnchor constraintEqualToConstant:barHeight].active = YES;
    }

    [container setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [container setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    return container;
}

- (UIButton * _Nullable)pp_viewWithImage:(UIImage * _Nullable)image
                              andTitle:(NSString * _Nullable)title
                           andSubtitle:(NSString * _Nullable)subtitle
                             userModel:(UserModel * _Nullable)usr
{
    // --- 1️⃣ Container (UIButton gives tap support)
    UIView *container = [UIButton buttonWithType:UIButtonTypeSystem];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.layer.cornerRadius = self.navigationController.navigationBar.hx_h / 2;
    container.clipsToBounds = YES;
    
    if (!PPIOS26()) {
        container.backgroundColor = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
    }
    
     CGFloat barHeight =  self.navigationController.navigationBar.hx_h;


    UIStackView *finalStack = nil;
    [self setProfileContainer:container
                    barHeight:barHeight
                        Image:image
                     andTitle:title
                  andSubtitle:subtitle
                    userModel:usr
                   finalStack:&finalStack];

    // --- 8️⃣ Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        [finalStack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:0],
         [finalStack.topAnchor constraintEqualToAnchor:container.topAnchor],
        [finalStack.widthAnchor constraintGreaterThanOrEqualToConstant:250],
        [container.widthAnchor constraintGreaterThanOrEqualToConstant:250]
       // [stack.heightAnchor constraintEqualToAnchor:container.heightAnchor]

    ]];

    // --- 9️⃣ Let the container auto-size its width
  
    if (@available(iOS 26.0, *)) {
        
    } else {
        [container.heightAnchor constraintEqualToConstant:barHeight].active = YES;
    }

    [container setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [container setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    return (UIView *)container;
}
#pragma mark - Helper: Image Container
- (UIView *)createImageContainerWithSize:(CGFloat)size
                                   image:(UIImage *)image
                               userModel:(UserModel * _Nullable)usr
{
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
    container.layer.cornerRadius = size / 2;
    container.clipsToBounds = YES;

    // Border / Glow
    [container pp_setBorderColor:[UIColor colorWithWhite:1 alpha:0.25]];
    container.layer.borderWidth = 0.5;
    [container pp_setShadowColor:[UIColor colorWithWhite:0 alpha:0.2]];
    container.layer.shadowOpacity = 0.3;
    container.layer.shadowOffset = CGSizeMake(0, 2);
    container.layer.shadowRadius = 4;

    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.tintColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    imageView.backgroundColor = UIColor.clearColor;
    imageView.layer.cornerRadius = (size-4) / 2;
    imageView.clipsToBounds = YES;

    [container addSubview:imageView];

    [NSLayoutConstraint activateConstraints:@[
        [imageView.topAnchor constraintEqualToAnchor:container.topAnchor constant:2],
        [imageView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-2],
        [imageView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:2],
        [imageView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-2],
        [container.widthAnchor constraintEqualToConstant:size],
        [container.heightAnchor constraintEqualToConstant:size]
    ]];

    if (usr) {
        imageView.image = [PPModernAvatarRenderer avatarImageForName:usr.UserName size:size - 4];
        [GM setImageFromUrlString:PPSafeString(usr.UserImageUrl.absoluteString)
                        imageView:imageView
                         phImage:@"sysUserIcon"];
    } else {
        imageView.image = [PPModernAvatarRenderer avatarImageForName:nil size:size - 4];
    }

    return container;
}

#pragma mark - Helper: Text Label
- (PPInsetLabel *)configuredLabelWithText:(NSString *)text
                                     font:(UIFont *)font
                                textColor:(UIColor *)color
{
    PPInsetLabel *label = [PPInsetLabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.textAlignment = GM.setAligment;
    label.textInsets = UIEdgeInsetsMake(2, 5, 2, 5);
    label.numberOfLines = 1;
    return label;
}

- (UIButton * _Nullable)pp_viewWithTitle:(NSString * _Nullable)title
                                Subtitle:(NSString * _Nullable)subtitle
                                   Image:(UIImage * _Nullable)image
                           showBackround:(BOOL)showBackround
{
    return [self pp_viewWithTitle:title Subtitle:subtitle textColor:AppPrimaryClr Image:image showBackround:showBackround];
}

#pragma mark - Pill View [Image + Title + Subtitle]
- (UIButton * _Nullable)pp_viewWithTitle:(NSString * _Nullable)title
                                Subtitle:(NSString * _Nullable)subtitle
                               textColor:(UIColor * _Nullable)textColor
                                   Image:(UIImage * _Nullable)image
                           showBackround:(BOOL)showBackround
{
    UIButton *container = nil;
    UIButtonConfiguration *cfg = nil;

    if (@available(iOS 26.0, *)) {
        // 🧊 iOS 26+: native glass-style button
        cfg =  showBackround ? [UIButtonConfiguration glassButtonConfiguration] : [UIButtonConfiguration filledButtonConfiguration];
        if (@available(iOS 15.0, *)) {
            // 🧊 إعداد الزر الزجاجي
            cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
            cfg.buttonSize = UIButtonConfigurationSizeLarge;

       
            cfg.baseForegroundColor = textColor ?: AppPrimaryTextClr;

            // 🏷️ العنوان الرئيسي
           //cfg.title = title;

            // 🪶 العنوان الفرعي (Subtitle)
            //cfg.subtitle = subtitle;
            cfg.subtitleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> * (NSDictionary<NSAttributedStringKey, id> *incoming) {
                NSMutableDictionary *attrs = [incoming mutableCopy];
                attrs[NSFontAttributeName] =[GM MidFontWithSize:14];
                attrs[NSForegroundColorAttributeName] =  textColor ?: AppPrimaryTextClr;
                return attrs;
            };

            // ✨ العنوان الرئيسي بخط ثقيل قليلاً
            cfg.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> * (NSDictionary<NSAttributedStringKey, id> *incoming) {
                NSMutableDictionary *attrs = [incoming mutableCopy];
                attrs[NSFontAttributeName] = [GM boldFontWithSize:17];
                attrs[NSForegroundColorAttributeName] =  textColor ?:  AppPrimaryClr;
                 return attrs;
            };
            
            cfg.titleAlignment =  UIButtonConfigurationTitleAlignmentCenter;
            cfg.titlePadding = 6;        // vertical spacing between title and subtitle
             if(image)
            {
                cfg.image = image;
                cfg.imagePlacement = NSDirectionalRectEdgeLeading;
            }
            
            // 💳 أيقونة للزر
           if(!showBackround)
           {
               cfg.background.backgroundColor = [UIColor.labelColor colorWithAlphaComponent:0.35];
               cfg.baseBackgroundColor = [UIColor.labelColor colorWithAlphaComponent:0.35];
           }// إنشاء الزر بالتكوين الجديد
            
            container = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
            container.configuration = cfg;
            container.translatesAutoresizingMaskIntoConstraints = NO;
            // 🌙 يمكنك فرض النمط الداكن فقط على الزر (اختياري)
           
            
 
        }

    }
    
    else {
        // Fallback on iOS <26 — solid "pill" button
        if (@available(iOS 15.0, *)) {
            cfg = showBackround ? [UIButtonConfiguration filledButtonConfiguration] : [UIButtonConfiguration plainButtonConfiguration];
            cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
            cfg.buttonSize = UIButtonConfigurationSizeLarge;
            cfg.baseForegroundColor = textColor ?: AppPrimaryTextClr;
            cfg.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> * (NSDictionary<NSAttributedStringKey, id> *incoming) {
                NSMutableDictionary *attrs = [incoming mutableCopy];
                attrs[NSFontAttributeName] = [GM boldFontWithSize:17];
                attrs[NSForegroundColorAttributeName] = textColor ?: AppPrimaryClr;
                return attrs;
            };
            cfg.subtitleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> * (NSDictionary<NSAttributedStringKey, id> *incoming) {
                NSMutableDictionary *attrs = [incoming mutableCopy];
                attrs[NSFontAttributeName] = [GM MidFontWithSize:14];
                attrs[NSForegroundColorAttributeName] = textColor ?: AppPrimaryTextClr;
                return attrs;
            };
            cfg.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;
            cfg.titlePadding = 6;
            if (image) {
                cfg.image = image;
                cfg.imagePlacement = NSDirectionalRectEdgeLeading;
            }
            if (!showBackround) {
                cfg.background.backgroundColor = [UIColor.labelColor colorWithAlphaComponent:0.35];
                cfg.baseBackgroundColor = [UIColor.labelColor colorWithAlphaComponent:0.35];
            }
        }
        container = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
        container.configuration = cfg;
        container.translatesAutoresizingMaskIntoConstraints = NO;

        // Subtle blur overlay for pseudo-glass feel
        if(@available(iOS 13.0, *))
        {
            if (showBackround) {
                UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:
                                            [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]];
                blur.translatesAutoresizingMaskIntoConstraints = NO;
                blur.userInteractionEnabled = NO;
                blur.layer.cornerRadius = 25;
                blur.layer.masksToBounds = YES;
                [container insertSubview:blur atIndex:0];
                [NSLayoutConstraint activateConstraints:@[
                    [blur.topAnchor constraintEqualToAnchor:container.topAnchor],
                    [blur.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
                    [blur.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
                    [blur.trailingAnchor constraintEqualToAnchor:container.trailingAnchor]
                ]];
            }
        }
        
    }

    // Common styling
    container.layer.cornerRadius = 22;
    container.clipsToBounds = YES;
    container.translatesAutoresizingMaskIntoConstraints = NO;


    [NSLayoutConstraint activateConstraints:@[
        [container.heightAnchor constraintGreaterThanOrEqualToConstant:44],
    ]];

    // ─────────── Subviews (icon + title + subtitle) ───────────
    UIImageView *iv = nil;
    if (image) {
        iv = [[UIImageView alloc] initWithImage:image];
        iv.translatesAutoresizingMaskIntoConstraints = NO;
        iv.contentMode = UIViewContentModeScaleAspectFit;
        iv.tintColor = AppPrimaryClrShiner ?: UIColor.systemBlueColor;
        [iv pp_setShadowColor:[AppShadowClr colorWithAlphaComponent:0.4]];
        iv.layer.shadowOpacity = 0.20;
        iv.layer.shadowOffset = CGSizeMake(0, 2);
        iv.layer.shadowRadius = 6;

        [NSLayoutConstraint activateConstraints:@[
            [iv.widthAnchor constraintEqualToConstant:36],
            [iv.heightAnchor constraintEqualToConstant:36],
        ]];
    }

    UILabel *lbl = [UILabel new];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.text = title ?: @"";
    lbl.font = [GM boldFontWithSize:17];
    lbl.textColor =  AppPrimaryTextClr;
    lbl.textAlignment = NSTextAlignmentCenter;
    lbl.numberOfLines = 0;

    UILabel *subtitleLbl = nil;
    if (subtitle.length > 0) {
        subtitleLbl = [UILabel new];
        subtitleLbl.translatesAutoresizingMaskIntoConstraints = NO;

        subtitleLbl.text = subtitle;
        subtitleLbl.font = [GM MidFontWithSize:14];
        subtitleLbl.textColor =  AppSecondaryTextClr;
        subtitleLbl.textAlignment = NSTextAlignmentCenter;
        subtitleLbl.numberOfLines = 0;
        subtitleLbl.lineBreakMode = NSLineBreakByWordWrapping;
    }

    // Stack for text
    UIStackView *textStack = [[UIStackView alloc] init];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.alignment = UIStackViewAlignmentCenter;
    textStack.spacing = -4;
    textStack.distribution = UIStackViewDistributionEqualSpacing;
    [textStack setSemanticContentAttribute:
        Language.isRTL ? UISemanticContentAttributeForceRightToLeft
                       : UISemanticContentAttributeForceLeftToRight];
    [textStack addArrangedSubview:lbl];
    if (subtitleLbl) [textStack addArrangedSubview:subtitleLbl];

    // Horizontal stack for icon + text
    NSArray *stackArray = iv ? @[iv, textStack] : @[textStack];
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:stackArray];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = iv ? 0 : 0;
    stack.distribution = UIStackViewDistributionFill;
    [stack setSemanticContentAttribute:
        Language.isRTL ? UISemanticContentAttributeForceRightToLeft
                       : UISemanticContentAttributeForceLeftToRight];

     [container addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.widthAnchor constraintEqualToAnchor:container.widthAnchor],
        [stack.heightAnchor constraintEqualToAnchor:container.widthAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [stack.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
    ]];
   
    // 🔹 فرض النمط الداكن فقط على الزر
    if (@available(iOS 13.0, *)) {
       // container.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }


    return container;
}




- (void)setWidthForLabel:(UILabel *)label
                 withText:(NSString *)text
             padding:(CGFloat)padding {

    if (!text || text.length == 0) return;

    // calculate width of text with current font
    NSDictionary *attrs = @{ NSFontAttributeName: label.font };
    CGFloat textWidth = [text sizeWithAttributes:attrs].width;

    CGFloat finalWidth = textWidth + padding;
    CGFloat maxWidth = UIScreen.mainScreen.bounds.size.width - 44; // prevent overflow
    finalWidth = MIN(finalWidth, maxWidth);

    // remove old width constraints
    for (NSLayoutConstraint *c in label.constraints) {
        if (c.firstAttribute == NSLayoutAttributeWidth) {
            [label removeConstraint:c];
        }
    }

    // apply new width constraint
    [label.widthAnchor constraintEqualToConstant:finalWidth].active = YES;
}


#pragma mark - Pill View [Image+Title] or [Title+Image]

- (UIView * _Nullable)pp_viewWithImageName:(NSString *)imageName andTitle:(NSString *)title {
    BOOL isRTL = Language.isRTL;
    
    UIView *container = [[UIView alloc] initWithFrame:CGRectZero];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    //container.backgroundColor = [AppBackgroundClrDarker colorWithAlphaComponent:0.9] ?: UIColor.whiteColor;  //D6D6D6
    container.layer.cornerRadius = 22; // half of 44
    container.layer.masksToBounds = NO;
    [container pp_setShadowColor:[UIColor colorWithWhite:0 alpha:0.2]];
    container.layer.shadowOpacity = 0.35;
    container.layer.shadowOffset = CGSizeMake(0, 2);
    container.layer.shadowRadius = 3;
    
    UIImage *img = [UIImage imageNamed:imageName];
    if (!img) img = [UIImage systemImageNamed:imageName];
    
    UIImageView *iv = [[UIImageView alloc] initWithImage:img];
    iv.translatesAutoresizingMaskIntoConstraints = NO;
    iv.contentMode = UIViewContentModeScaleToFill;
    iv.tintColor = AppSecondaryTextClr ?: UIColor.systemBlueColor;
    
    iv.layer.masksToBounds = NO;
    [iv pp_setShadowColor:[UIColor colorWithWhite:0 alpha:0.2]];
    iv.layer.shadowOpacity = 0.20;
    iv.layer.shadowOffset = CGSizeMake(0, 2);
    iv.layer.shadowRadius = 6;
    
    [NSLayoutConstraint activateConstraints:@[
        [iv.heightAnchor constraintEqualToConstant:36],
        [iv.widthAnchor constraintEqualToConstant:36]
    ]];
    
    UILabel *lbl = [UILabel new];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.text = title;
    lbl.font = [GM boldFontWithSize:20];
    lbl.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    lbl.textAlignment = GM.setAligment;

    // --- calculate text width ---
    CGFloat maxWidth = UIScreen.mainScreen.bounds.size.width - 32; // don’t exceed screen
    NSDictionary *attrs = @{ NSFontAttributeName: lbl.font };
    CGFloat textWidth = [title sizeWithAttributes:attrs].width;

    // add 50 padding as you asked
    CGFloat finalWidth = MIN(textWidth + 50.0, maxWidth);

    // --- set constraint ---
    [NSLayoutConstraint activateConstraints:@[
        [lbl.widthAnchor constraintEqualToConstant:finalWidth]
    ]];

    
    
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:isRTL ? @[lbl, iv] : @[iv, lbl]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 8;
    [stack setSemanticContentAttribute:
       Language.isRTL ? UISemanticContentAttributeForceRightToLeft
                      : UISemanticContentAttributeForceLeftToRight];
    [container addSubview:stack];
    
    [NSLayoutConstraint activateConstraints:@[
        [container.heightAnchor constraintEqualToConstant:self.navigationController.navigationBar.hx_h],
        [stack.heightAnchor constraintEqualToAnchor:container.heightAnchor],
        [stack.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:container.leadingAnchor constant:5],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor constant:-5]
    ]];
    
    return container;
}

#pragma mark - Force custom views on NavBar (Left/Right)

- (UIView * _Nullable)PPNavBarForceLeftView:(UIView *)navBarTitleView {
    NSAssert(self.navigationController, @"PPNavBarForceLeftView requires a UINavigationController.");
    UIView *bar = PPBarForVC(self);
    UIStackView *left = PPLeftForVC(self);
    /* If no custom nav bar is present yet, attach a new one (with no title) so we can add the custom left view.
     * (Note: forceReplaceLeftButtonWith: did not auto-attach; adding here for completeness.) */
    if (!bar) {
        bar = [self pp_navBarAttachWithTitle:nil];
        left = PPLeftForVC(self);
    }
    if (!left) return nil;
    /* Remove all existing subviews from the left stack (e.g., the default back button or other icons) before adding the new view.
     * Note: Any removed buttons/views still have entries in PPDictForVC (e.g., __base_back), which you might clear to avoid stale references. */
    for (UIView *v in left.arrangedSubviews) {
        [left removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    if (navBarTitleView) {
        [left addArrangedSubview:navBarTitleView];
        /* Storing the custom view in the dictionary under key "forceLeft" (originally used for forced left button).
         * This works (since UIView shares base properties with UIButton), but consider using a separate key or a generalized dictionary if needed for clarity. */
        UIButton *bgButton = [self addBackroundButton];
        bgButton.bounds = navBarTitleView.frame;
        [bgButton addSubview:navBarTitleView];
        PPDictForVC(self, YES)[@"forceLeft"] = bgButton;
    }
    DLog(@"[PPNavBar] 🔄 Force replaced LEFT custom view (RTL=%d)", Language.isRTL);
    return navBarTitleView;
}
- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleDarkContent; // ✅ Always dark text
}

- (UIView * _Nullable)PPNavBarForceRightView:(UIView *)navBarTitleView {
    NSAssert(self.navigationController, @"PPNavBarForceRightView requires a UINavigationController.");
    UIView *bar = PPBarForVC(self);
    UIStackView *right = PPRightForVC(self);
    /* If no custom nav bar is present yet, attach a new one so we can add the custom right view. */
    if (!bar) {
        bar = [self pp_navBarAttachWithTitle:nil];
        right = PPRightForVC(self);
    }
    if (!right) return nil;
    /* Remove all existing subviews from the right stack before adding the new view.
     * Note: Removed items (like a __base_button or any forced right button) still have entries in the PPNavBar dictionary. You may want to remove those keys too to avoid confusion. */
    for (UIView *v in right.arrangedSubviews) {
        [right removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    if (navBarTitleView) {
        [right addArrangedSubview:navBarTitleView];
        /* Storing the custom view in the dictionary under key "forceRight" (used for forced right button).
         * This is okay, but if you need to differentiate this from a forced button, you might use a distinct key or data structure. */
        UIButton *bgButton = [self addBackroundButton];
        bgButton.bounds = navBarTitleView.frame;
        [bgButton addSubview:navBarTitleView];
        PPDictForVC(self, YES)[@"forceRight"] = bgButton;
    }
    DLog(@"[PPNavBar] 🔄 Force replaced RIGHT custom view (RTL=%d)", Language.isRTL);
    return navBarTitleView;
}


- (UIButton*)addBackroundButton {
    UIButton *bgbutton;

    if (@available(iOS 26.0, *)) {
        // 🧊 iOS 26+: modern glass button style
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(12, 16, 12, 16);
        cfg.baseBackgroundColor = [AppForgroundColr colorWithAlphaComponent:0.15];
        cfg.baseForegroundColor = AppPrimaryClr;
        cfg.buttonSize = UIButtonConfigurationSizeLarge;
        
        bgbutton = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
        bgbutton.translatesAutoresizingMaskIntoConstraints = NO;
        bgbutton.layer.cornerRadius = 25;
        bgbutton.clipsToBounds = YES;
    }
    else {
        // 🎨 Fallback: plain solid button with subtle blur overlay
        bgbutton = [UIButton buttonWithType:UIButtonTypeSystem];
        bgbutton.translatesAutoresizingMaskIntoConstraints = NO;
        bgbutton.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.9];
        bgbutton.tintColor = AppForgroundColr;
        bgbutton.layer.cornerRadius = 25;
        bgbutton.layer.masksToBounds = YES;

        // Optional: add subtle shadow for depth
        [bgbutton pp_setShadowColor:[UIColor blackColor]];
        bgbutton.layer.shadowOpacity = 0.2;
        bgbutton.layer.shadowOffset = CGSizeMake(0, 4);
        bgbutton.layer.shadowRadius = 8;

        // Optional fallback “glass” feel using blur
        if (@available(iOS 13.0, *)) {
            UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialLight]];
            blur.translatesAutoresizingMaskIntoConstraints = NO;
            blur.userInteractionEnabled = NO;
            blur.layer.cornerRadius = 25;
            blur.layer.masksToBounds = YES;
            [bgbutton insertSubview:blur atIndex:0];
            [NSLayoutConstraint activateConstraints:@[
                [blur.topAnchor constraintEqualToAnchor:bgbutton.topAnchor],
                [blur.bottomAnchor constraintEqualToAnchor:bgbutton.bottomAnchor],
                [blur.leadingAnchor constraintEqualToAnchor:bgbutton.leadingAnchor],
                [blur.trailingAnchor constraintEqualToAnchor:bgbutton.trailingAnchor]
            ]];
        }
    }

    return bgbutton;
}




#pragma mark - Status Bar Handling
- (void)pp_enableTransparentStatusBar {
    // Make sure nav bar is fully transparent
    if (@available(iOS 15.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithTransparentBackground];
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
        self.navigationController.navigationBar.compactAppearance = appearance;
    } else {
        [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
        [self.navigationController.navigationBar setShadowImage:[UIImage new]];
        self.navigationController.navigationBar.translucent = YES;
    }
    
    // Extend content behind status bar
    //self.extendedLayoutIncludesOpaqueBars = YES;
    //self.edgesForExtendedLayout = UIRectEdgeAll;
 
    // Force re-layout to apply
    [self setNeedsStatusBarAppearanceUpdate];
}
#pragma mark - Disable Transparent Status Bar

- (void)pp_disableTransparentStatusBar {
    UINavigationBar *navBar = self.navigationController.navigationBar;
    if (!navBar) return;

    if (@available(iOS 15.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithDefaultBackground]; // restores default system background
        appearance.backgroundColor = UIColor.clearColor ?: UIColor.systemBackgroundColor;
        appearance.shadowColor = UIColor.separatorColor;
        appearance.titleTextAttributes = @{ NSForegroundColorAttributeName: AppPrimaryTextClr ?: UIColor.labelColor };
        
        navBar.standardAppearance = appearance;
        navBar.scrollEdgeAppearance = appearance;
        navBar.compactAppearance = appearance;
    } else {
        [navBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
        [navBar setShadowImage:nil];
        navBar.translucent = NO;
        navBar.backgroundColor = AppClearClr ?: UIColor.systemBackgroundColor;
    }
    
    // Restore normal layout behavior
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.extendedLayoutIncludesOpaqueBars = NO;

    // Force UIKit to redraw the status bar & navigation bar
    [navBar setNeedsDisplay];
    [navBar layoutIfNeeded];
    [self setNeedsStatusBarAppearanceUpdate];

    DLog(@"[PPNavBar] 🧱 Transparent status bar disabled — restored to default appearance.");
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}




+ (void)lockNavBarAppearanceWithTint:(UIColor *)tintColor
                        titleColor:(UIColor *)titleColor
                      statusStyle:(UIStatusBarStyle)statusStyle
{
    if (@available(iOS 15.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithTransparentBackground];
        
        appearance.backgroundColor = UIColor.clearColor;
        appearance.shadowColor = UIColor.clearColor;
        appearance.titleTextAttributes = @{ NSForegroundColorAttributeName: titleColor ?: UIColor.blackColor };
        appearance.largeTitleTextAttributes = @{ NSForegroundColorAttributeName: titleColor ?: UIColor.blackColor };
        
        UINavigationBar *navBarAppearance = [UINavigationBar appearance];
        navBarAppearance.standardAppearance = appearance;
        navBarAppearance.scrollEdgeAppearance = appearance;
        navBarAppearance.compactAppearance = appearance;
        navBarAppearance.tintColor = tintColor ?: UIColor.blackColor;
        navBarAppearance.barStyle = (statusStyle == UIStatusBarStyleLightContent)
            ? UIBarStyleBlack
            : UIBarStyleDefault;
    }

    // Optional: force app to light mode globally (no auto switching)
    if (@available(iOS 13.0, *)) {
     }
}



/* ==============================  AppVC Helpers ==========================*/

- (void)firstLeftTapped:(nonnull UIButton *)sender {
}

- (void)firstRightTapped:(nonnull UIButton *)sender {
}

- (void)secondLeftTapped:(nonnull UIButton *)sender {
}

- (void)secondRightTapped:(nonnull UIButton *)sender {
}

- (void)centerTapped:(nonnull UIButton *)sender {
}




+ (UIButton *)setButtonAsBackroundButtonWithStyle:(UIButtonConfigurationCornerStyle)style{
    if (@available(iOS 26.0, *)) {
        return [self setButtonAsBackroundButtonWithStyle:style configType:PPButtonConfigrationGlass];
    } else {
        return [self setButtonAsBackroundButtonWithStyle:style configType:PPButtonConfigrationFilled];
    }
}

+ (UIButton *)setButtonAsBackroundButtonWithStyle:(UIButtonConfigurationCornerStyle)style configType:(PPButtonConfigration)configType{
    UIButton *bgButton;
    
    

    
    if (@available(iOS 26.0, *)) {
        // 🧊 iOS 26+ system glass button
        UIButtonConfiguration *cfg = configType == PPButtonConfigrationGlass ? [UIButtonConfiguration glassButtonConfiguration] :
        configType == PPButtonConfigrationClearGlass ? [UIButtonConfiguration glassButtonConfiguration] :
        configType == PPButtonConfigrationFilled ? [UIButtonConfiguration filledButtonConfiguration] :
        configType == PPButtonConfigrationPromp ? [UIButtonConfiguration prominentGlassButtonConfiguration] :
        configType == PPButtonConfigrationClearPromp ? [UIButtonConfiguration prominentClearGlassButtonConfiguration] :
        configType == PPButtonConfigrationTintedBorderd ? [UIButtonConfiguration borderedTintedButtonConfiguration] :
        configType == PPButtonConfigrationTinted ? [UIButtonConfiguration tintedButtonConfiguration] : [UIButtonConfiguration plainButtonConfiguration] ;
        
        cfg.cornerStyle = style;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(12, 12, 12, 12);
        cfg.background.cornerRadius = 0;
        cfg.background.backgroundColor = [UIColor clearColor];
        cfg.baseBackgroundColor =[UIColor clearColor];
 
        bgButton = [UIButton  buttonWithType:UIButtonTypeSystem];
        bgButton.configuration = cfg;
        bgButton.clipsToBounds = NO;
        bgButton.backgroundColor  = [UIColor clearColor];
        bgButton.layer.masksToBounds = NO;
     } else {
         
  
        // 🌫️ Fallback for iOS <26 (iOS 15+)
        bgButton = [UIButton buttonWithType:UIButtonTypeSystem];
        UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
        cfg.cornerStyle = style;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(12, 12, 12, 12);
        cfg.background.cornerRadius = 16;
        cfg.background.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        cfg.baseBackgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        bgButton.configuration = cfg;
        bgButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        bgButton.layer.cornerRadius = 16;
        bgButton.layer.masksToBounds = YES;
        [bgButton pp_setShadowColor:AppShadowClr];
        bgButton.layer.shadowOpacity = 0.15;
        bgButton.layer.shadowRadius = 8;
        bgButton.layer.shadowOffset = CGSizeMake(0, 4);
    }

    bgButton.translatesAutoresizingMaskIntoConstraints = NO;
 
    return bgButton;
}

#pragma mark - Global Background Color Swizzle

- (void)pp_swizzledViewDidLoad {
    [self pp_swizzledViewDidLoad];
    if (![self isKindOfClass:UIAlertController.class] &&
        ![self isKindOfClass:UIImagePickerController.class] &&
        ![NSStringFromClass(self.class) hasPrefix:@"UI"]) {
        self.view.backgroundColor = AppBageColor();
    }
}


@end
//[self.view bringSubviewToFront:self.accessBar];
//[self PPNavBarForceLeftView:self.profileRowStack];   // replaces the whole left side with profileRow

/*
 
 
 
 
 - (void)SecondLeftBtnTapped:(UIButton *)sender
{
    
}
- (void)FristLeftBtnTapped:(UIButton *)sender
{
    
}
- (void)SecondrightBtnTapped:(UIButton *)sender
{
    
}
- (void)FristRightBtnTapped:(UIButton *)sender
{
    
}

- (void)CenterBtnTapped:(UIButton *)sender
{
    
}
 
 
 
 
 
 //
 //  UIViewController.m
 //  PurePetsAdmin
 //
 //  Created by Mohammed Ahmed on 23/08/2025.
 //


 #import "UIViewController+PPNavBar.h"
 #import <objc/runtime.h>

 #pragma mark - Accessors

 static inline UIView *PPBarForVC(UIViewController *vc) {
     return objc_getAssociatedObject(vc, kPPNavBarViewKey);
 }
 static inline UILabel *PPTitleForVC(UIViewController *vc) {
     return objc_getAssociatedObject(vc, kPPTitleLabelKey);
 }
 static inline UIStackView *PPLeftForVC(UIViewController *vc) {
     return objc_getAssociatedObject(vc, kPPLeftStackKey);
 }
 static inline UIStackView *PPRightForVC(UIViewController *vc) {
     return objc_getAssociatedObject(vc, kPPRightStackKey);
 }
 static inline NSMutableDictionary<NSString *, UIButton *> *PPDictForVC(UIViewController *vc, BOOL create) {
     NSMutableDictionary *d = objc_getAssociatedObject(vc, kPPButtonsDictKey);
     if (!d && create) {
         d = [NSMutableDictionary dictionary];
         objc_setAssociatedObject(vc, kPPButtonsDictKey, d, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
     }
     return d;
 }

 #pragma mark - Private helpers

 static BOOL PPIsRTL(UIViewController *vc) {
     Class Lang = NSClassFromString(@"Language");
     if (Lang && [Lang respondsToSelector:@selector(isRTL)]) {
         BOOL (*isRTLFunc)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
         return isRTLFunc(Lang, @selector(isRTL));
     }
     
     return Language.isRTL;// (dir == UIUserInterfaceLayoutDirectionRightToLeft);
 }



 @implementation UIViewController (PPNavBar)

 #pragma mark - Attach base bar (left/title/right)

 - (UIView *)pp_navBarAttachWithTitle:(NSString *)titleString {
     
     
     NSAssert(self.navigationController, @"pp_navBar requires a UINavigationController.");
     UINavigationBar *navBar = self.navigationController.navigationBar;
     navBar.tintColor = UIColor.clearColor;
     navBar.backgroundColor = UIColor.clearColor;
     UIView *bar = PPBarForVC(self);
     if (bar) {
         UILabel *titleLabel = PPTitleForVC(self);
         if (titleLabel) {
             titleLabel.text = titleString ?: (self.title ?: @"");
         }
         return bar;
     }
     
     bar = [UIView new];
     bar.translatesAutoresizingMaskIntoConstraints = NO;
     bar.backgroundColor = UIColor.clearColor;
     
     self.navigationItem.hidesBackButton = YES; // 🔒 Hide default back arrow
     
     UIStackView *left = [[UIStackView alloc] init];
     left.translatesAutoresizingMaskIntoConstraints = NO;
     left.axis = UILayoutConstraintAxisHorizontal;
     left.alignment = UIStackViewAlignmentCenter;
     left.spacing = 12;
     
     UILabel *titleLbl = [UILabel new];
     titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
     titleLbl.font = [GM boldFontWithSize:22];
     titleLbl.textColor = AppPrimaryTextClr;
     titleLbl.textAlignment = NSTextAlignmentCenter;
     titleLbl.adjustsFontSizeToFitWidth = YES;
     titleLbl.minimumScaleFactor = 0.75;
     
     UIStackView *right = [[UIStackView alloc] init];
     right.translatesAutoresizingMaskIntoConstraints = NO;
     right.axis = UILayoutConstraintAxisHorizontal;
     right.alignment = UIStackViewAlignmentCenter;
     right.spacing = 8;
     
     [navBar addSubview:bar];
     [bar addSubview:left];
     [bar addSubview:titleLbl];
     [bar addSubview:right];
     
     UILayoutGuide *m = navBar.layoutMarginsGuide;
     [NSLayoutConstraint activateConstraints:@[
         [bar.topAnchor constraintEqualToAnchor:navBar.topAnchor],
         [bar.bottomAnchor constraintEqualToAnchor:navBar.bottomAnchor],
         [bar.leadingAnchor constraintEqualToAnchor:m.leadingAnchor constant:5],
         [bar.trailingAnchor constraintEqualToAnchor:m.trailingAnchor constant:-5],
         
         [left.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
         [left.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
         
         [right.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
         [right.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
         
         [titleLbl.centerXAnchor constraintEqualToAnchor:bar.centerXAnchor],
         [titleLbl.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
         [titleLbl.leadingAnchor constraintGreaterThanOrEqualToAnchor:left.trailingAnchor constant:8],
         [titleLbl.trailingAnchor constraintLessThanOrEqualToAnchor:right.leadingAnchor constant:-8],
     ]];
     
     objc_setAssociatedObject(self, kPPNavBarViewKey, bar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
     objc_setAssociatedObject(self, kPPTitleLabelKey, titleLbl, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
     objc_setAssociatedObject(self, kPPLeftStackKey, left, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
     objc_setAssociatedObject(self, kPPRightStackKey, right, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
     PPDictForVC(self, YES);
     
     [self pp_navBarSetTitle:titleString];
     return bar;
 }


 + (void)load {
     static dispatch_once_t onceToken;
     dispatch_once(&onceToken, ^{
         Method origAppear = class_getInstanceMethod(self, @selector(viewWillAppear:));
         Method swzAppear  = class_getInstanceMethod(self, @selector(pp_swz_viewWillAppear:));
         method_exchangeImplementations(origAppear, swzAppear);
         
         Method origDisappear = class_getInstanceMethod(self, @selector(viewWillDisappear:));
         Method swzDisappear  = class_getInstanceMethod(self, @selector(pp_swz_viewWillDisappear:));
         method_exchangeImplementations(origDisappear, swzDisappear);
     });
 }

 #pragma mark - Swizzled implementations

 - (void)pp_swz_viewWillAppear:(BOOL)animated {
     // call original
     [self pp_swz_viewWillAppear:animated];
     
     // if this VC already has a PPNavBar attached, make sure it's visible
     UIView *bar = objc_getAssociatedObject(self, kPPNavBarViewKey);
     if (bar) {
         [self pp_navBarSetVisible:YES animated:NO];
     }
 }

 - (void)pp_swz_viewWillDisappear:(BOOL)animated {
     // call original
     [self pp_swz_viewWillDisappear:animated];
     
     // 🔴 Auto-hide & remove nav bar so parent doesn't overlap with pushed VC
     [self pp_removeNavBar];
 }





	 - (void)pp_navBarSetTitle:(NSString *)titleString {
	     UILabel *lbl = PPTitleForVC(self);
	     if (!lbl) {
	         if (!PPBarForVC(self)) {
	             [self pp_navBarAttachWithTitle:titleString];
	             lbl = PPTitleForVC(self);
	         }
	         if (!lbl) {
	             return;
	         }
	     }
	     lbl.text = titleString ?: (self.title ?: @"");
	 }

 #pragma mark - Your original API (compat)

 - (UIView *)pp_navBarWithOtherButton:(UIButton * _Nullable)otherBtn
                                title:(NSString * _Nullable)titleString
 {
     UIView *bar = [self pp_navBarAttachWithTitle:titleString];
     
     // Ensure default back on LEFT (your old behavior)
     if (!PPDictForVC(self, NO)[kPPKeyBaseBack]) {
         UIButton *back = [self pp_ButtonWithSystemName:@"arrow.backward" action:@selector(onBack)];
         [self _pp_addLeftButton:back key:kPPKeyBaseBack];
     }
     
     // Trailing "other" (RIGHT)
     if (otherBtn) {
         [self _pp_addRightButton:otherBtn key:kPPKeyBaseButton];
     } else {
         [self pp_navBarRemoveButtonForKey:kPPKeyBaseButton];
     }
     return bar;
 }

 - (void)pp_removeNavBar {
     UIView *bar = PPBarForVC(self);
     if (bar) [bar removeFromSuperview];
     objc_setAssociatedObject(self, kPPNavBarViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
     objc_setAssociatedObject(self, kPPTitleLabelKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
     objc_setAssociatedObject(self, kPPLeftStackKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
     objc_setAssociatedObject(self, kPPRightStackKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
     objc_setAssociatedObject(self, kPPButtonsDictKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
 }

 #pragma mark - Base layout you asked for

 - (UIView * _Nullable)pp_navBarApplyBase:(PPNavBarBaseLayout)layout
                                   button:(UIButton * _Nullable)button
                                    title:(NSString * _Nullable)title
                                 showBack:(BOOL)showBack
 {
     // [nil][nil][nil] → remove bar
     if (!button && !title && !showBack) { [self pp_removeNavBar]; return nil; }
     
     // Attach (or reuse)
     UIView *bar = [self pp_navBarAttachWithTitle:title];
     
     // Decide layout
     //BOOL isRTL = (layout == PPNavBarBaseLayoutRTL)
     //           || (layout == PPNavBarBaseLayoutAuto && PPIsRTL(self));
     
     //BOOL isRTL = Language.isRTL;
     
     
     // Clean current base items
     [self pp_navBarRemoveButtonForKey:kPPKeyBaseBack];
     [self pp_navBarRemoveButtonForKey:kPPKeyBaseButton];
     
    
     // Ensure default back on LEFT (your old behavior)
     if (showBack) {
         if (!PPDictForVC(self, NO)[kPPKeyBaseBack]) {
             UIButton *back = [self pp_ButtonWithSystemName:@"arrow.backward" action:@selector(onBack)];
             [self _pp_addLeftButton:back key:kPPKeyBaseBack];
         }
     }
     
     if (button) {
         [self _pp_addRightButton:button key:kPPKeyBaseButton];
     } else {
         [self pp_navBarRemoveButtonForKey:kPPKeyBaseButton];
     }

     
     // Title (center)
     [self pp_navBarSetTitle:title];
     
     
     return bar;
 }

 - (UIView *)PPLTRNavigationBarWithButton:(UIButton *)button title:(NSString *)title showBack:(BOOL)showBack {
     return [self pp_navBarApplyBase:PPNavBarBaseLayoutLTR button:button title:title showBack:showBack];
 }
 - (UIView *)PPRTLNavigationBarWithButton:(UIButton *)button title:(NSString *)title showBack:(BOOL)showBack {
     return [self pp_navBarApplyBase:PPNavBarBaseLayoutRTL button:button title:title showBack:showBack];
 }

 #pragma mark - Visibility

 - (void)pp_navBarSetVisible:(BOOL)visible animated:(BOOL)animated {
     UIView *bar = PPBarForVC(self); if (!bar) return;
     if (!animated) { bar.hidden = !visible; return; }
     if (visible) {
         bar.hidden = NO; bar.alpha = 0;
         [UIView animateWithDuration:0.2 animations:^{ bar.alpha = 1; }];
     } else {
         [UIView animateWithDuration:0.2 animations:^{ bar.alpha = 0; } completion:^(BOOL f){ bar.hidden = YES; }];
     }
 }

 #pragma mark - Keyed icon buttons (advanced)

 - (UIButton *)pp_navBarSetRightIcon:(NSString *)systemImage key:(NSString *)key
                              target:(id)target action:(SEL)action
                                 tap:(PPNavBarTapBlock)tapBlock
 {
     UIView *bar = PPBarForVC(self); if (!bar) [self pp_navBarAttachWithTitle:nil];
     UIButton *btn = PPDictForVC(self, YES)[key];
     if (!btn) {
         btn = [self _pp_makeIconButton:systemImage target:target action:action tap:tapBlock];
         [self _pp_addRightButton:btn key:key];
     } else {
         [btn setImage:[UIImage systemImageNamed:systemImage] forState:UIControlStateNormal];
         [self _pp_updateButton:btn target:target action:action tap:tapBlock];
     }
     //btn.backgroundColor  = UIColor.clearColor;
     return btn;
 }

 - (UIButton *)pp_navBarSetLeftIcon:(NSString *)systemImage  key:(NSString *)key
                             target:(id)target action:(SEL)action
                                tap:(PPNavBarTapBlock)tapBlock
 {
     UIView *bar = PPBarForVC(self); if (!bar) [self pp_navBarAttachWithTitle:nil];
     UIButton *btn = PPDictForVC(self, YES)[key];
     if (!btn) {
         btn = [self _pp_makeIconButton:systemImage target:target action:action tap:tapBlock];
         [self _pp_addLeftButton:btn key:key];
     } else {
         [btn setImage:[UIImage systemImageNamed:systemImage] forState:UIControlStateNormal];
         [self _pp_updateButton:btn target:target action:action tap:tapBlock];
     }
     return btn;
 }

 - (void)pp_navBarHideButtonForKey:(NSString *)key hidden:(BOOL)hidden animated:(BOOL)animated {
     UIButton *btn = PPDictForVC(self, NO)[key];
     if (!btn) return;
     if (!animated) { btn.hidden = hidden; return; }
     [UIView animateWithDuration:0.2 animations:^{ btn.alpha = hidden ? 0.f : 1.f; } completion:^(BOOL f){ btn.hidden = hidden; }];
 }

 - (void)pp_navBarRemoveButtonForKey:(NSString *)key {
     NSMutableDictionary *dict = PPDictForVC(self, NO);
     UIButton *btn = dict[key]; if (!btn) return;
     [btn removeFromSuperview];
     [dict removeObjectForKey:key];
 }

 #pragma mark - Default back

 - (void)onBack {
     if (self.navigationController.viewControllers.count > 1) {
         [self.navigationController popViewControllerAnimated:YES];
     } else {
         [self dismissViewControllerAnimated:YES completion:nil];
     }
 }

 #pragma mark - Your circle button helper


 - (UIButton *)pp_ButtonWithSystemName:(NSString *)imageName action:(SEL)action {
     UIButton *btn;
     CGFloat btnSize = 40;

     if (@available(iOS 26.0, *)) {
          UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
         cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
         //cfg.background.backgroundColor = AppBackgroundClrShiner ?: [UIColor colorWithWhite:0.95 alpha:1.0];

         btn = [UIButton new];
         btn.configuration = cfg;
         [btn setImage:[UIImage systemImageNamed:imageName] forState:UIControlStateNormal];
     }
     else if (@available(iOS 15.0, *)) {
         UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
         cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
         
         // ✅ Set background color through configuration
         cfg.background.backgroundColor = AppBackgroundClr ?: [UIColor colorWithWhite:0.95 alpha:1.0];
         cfg.background.cornerRadius = 22;
         
         btn = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
     } else {
         btn = [UIButton buttonWithType:UIButtonTypeSystem];
         btn.contentEdgeInsets = UIEdgeInsetsMake(6, 6, 6, 6);
         btn.backgroundColor = AppBackgroundClr ?: [UIColor colorWithWhite:0.95 alpha:1.0];
         btn.layer.cornerRadius = 22;
         btn.clipsToBounds = YES;
     }

     // Try SF Symbol first → fallback to asset
     UIImage *icon = [UIImage systemImageNamed:imageName];
     if (!icon) {
         icon = [UIImage imageNamed:imageName];
         icon = [UIImage pp_resizedImage:icon toPointSize:18];
     }

     if (!icon) {
         DLog(@"[pp_circleButton] ⚠️ No image found for name: %@", imageName);
         icon = [UIImage new]; // fallback empty
     }
     
     if([imageName isEqualToString:@"headset"]) {
         icon = [[UIImage pp_resizedImage:icon toPointSize:18] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
     }

     [btn setImage:icon forState:UIControlStateNormal];

     btn.translatesAutoresizingMaskIntoConstraints = NO;
     btn.tintColor = AppPrimaryClr ?: [UIColor systemBlueColor];
     
     // ✅ Remove the old backgroundColor assignment for iOS 15+
     if (@available(iOS 15.0, *)) {
         // Background is already set in configuration
     } else {
         btn.backgroundColor = AppForgroundColr ?: [UIColor colorWithWhite:0.95 alpha:1.0];
         btn.layer.cornerRadius = 22;
         btn.layer.masksToBounds = YES;
     }

     [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
     [btn.widthAnchor constraintEqualToConstant:btnSize].active = YES;
     [btn.heightAnchor constraintEqualToConstant:btnSize].active = YES;

     [btn pp_setShadowColor:AppShadowClr];
     btn.layer.shadowOpacity = 0.10;
     btn.layer.shadowOffset = CGSizeMake(0, 2);
     btn.layer.shadowRadius = 6;
     btn.layer.masksToBounds = NO; // shadow needs this

     
     // 🔹 If it's SF Symbol, apply config
     if ([UIImage systemImageNamed:imageName]) {
         UIImageSymbolConfiguration *config =
         [UIImageSymbolConfiguration configurationWithPointSize:20
                                                         weight:UIImageSymbolWeightRegular
                                                          scale:UIImageSymbolScaleMedium];
         [btn setImage:[icon imageByApplyingSymbolConfiguration:config]
               forState:UIControlStateNormal];
         btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
     } else {
         btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
     }

     //[PPButtonHelper attachTapAnimationToButton:btn style:PPButtonAnimationStylePulse];
     return btn;
 }

 #pragma mark - Button plumbing

 - (void)_pp_addRightButton:(UIButton *)btn key:(NSString *)key {
     UIStackView *right = PPRightForVC(self); if (!right) return;
     PPDictForVC(self, YES)[key] = btn;
     [right addArrangedSubview:btn];
 }
 - (void)_pp_addLeftButton:(UIButton *)btn key:(NSString *)key {
     UIStackView *left = PPLeftForVC(self); if (!left) return;
     PPDictForVC(self, YES)[key] = btn;
     [left addArrangedSubview:btn];
 }
 - (void)_pp_updateButton:(UIButton *)btn target:(id)target action:(SEL)action tap:(PPNavBarTapBlock)tapBlock {
     [btn removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
     if (target && action) [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
     objc_setAssociatedObject(btn, kPPTapBlockKey, tapBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
     [btn addTarget:self action:@selector(_pp_tapRelay:) forControlEvents:UIControlEventTouchUpInside];
 }
 - (UIButton *)_pp_makeIconButton:(NSString *)systemImage target:(id)target action:(SEL)action tap:(PPNavBarTapBlock)tapBlock {
     UIButton *b = [self pp_ButtonWithSystemName:systemImage action:action ?: @selector(_pp_dummy)];
     [self _pp_updateButton:b target:target action:action tap:tapBlock];
     return b;
 }
 - (void)_pp_dummy {}
 - (void)_pp_tapRelay:(UIButton *)sender {
     PPNavBarTapBlock blk = objc_getAssociatedObject(sender, kPPTapBlockKey);
     if (blk) blk();
 }


 #pragma mark - Force Replace Helpers
 #pragma mark - Force Replace Helpers (RTL/LTR aware)

 - (void)forceReplaceLeftButtonWith:(UIButton *)btn {
     UIStackView *left = PPLeftForVC(self);
     if (!left) return;
     
     // 🔥 Remove existing left buttons
     for (UIView *v in left.arrangedSubviews) {
         [left removeArrangedSubview:v];
         [v removeFromSuperview];
     }
     
     // 🔹 Add new one
     if (btn) {
         [left addArrangedSubview:btn];
         // store with a stable key
         PPDictForVC(self, YES)[@"forceLeft"] = btn;
     }
     
     DLog(@"[PPNavBar] 🔄 Force replaced LEFT button (RTL=%d)", PPIsRTL(self));
 }

 - (void)forceReplaceRightButtonWith:(UIButton *)btn {
     UIStackView *right = PPRightForVC(self);
     if (!right) return;
     
     // 🔥 Remove existing right buttons
     for (UIView *v in right.arrangedSubviews) {
         [right removeArrangedSubview:v];
         [v removeFromSuperview];
     }
     
     // 🔹 Add new one
     if (btn) {
         [right addArrangedSubview:btn];
         PPDictForVC(self, YES)[@"forceRight"] = btn;
     }
     
     DLog(@"[PPNavBar] 🔄 Force replaced RIGHT button (RTL=%d)", PPIsRTL(self));
 }




 //  ======================    Custom Title View

 #pragma mark - Custom Title View

 - (UIView * _Nullable)pp_navBarForeTitleView:(UIView *)navBarTitleView {
     NSAssert(self.navigationController, @"pp_navBarForeTitleView requires a UINavigationController.");
     
     // Remove old title if any
     UILabel *lbl = PPTitleForVC(self);
     if (lbl) {
         [lbl removeFromSuperview];
         objc_setAssociatedObject(self, kPPTitleLabelKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
     }
     
     UIView *bar = PPBarForVC(self);
     if (!bar) {
         bar = [self pp_navBarAttachWithTitle:nil];
     }
     
     if (navBarTitleView) {
         navBarTitleView.translatesAutoresizingMaskIntoConstraints = NO;
         [bar addSubview:navBarTitleView];
         [NSLayoutConstraint activateConstraints:@[
             [navBarTitleView.centerXAnchor constraintEqualToAnchor:bar.centerXAnchor],
             [navBarTitleView.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor]
         ]];
     }
     
     return navBarTitleView;
 }

 #pragma mark - Pill View [Image+Title] or [Title+Image]


 - (UIView * _Nullable)pp_viewWithImage:(NSString *)imageName andTitle:(NSString *)title {
     BOOL isRTL = PPIsRTL(self);
     
     UIView *container = [[UIView alloc] initWithFrame:CGRectZero];
     container.translatesAutoresizingMaskIntoConstraints = NO;
     container.backgroundColor = AppForgroundColr ?: UIColor.whiteColor;
      container.layer.masksToBounds = NO;
     [container pp_setShadowColor:[UIColor colorWithWhite:0 alpha:0.2]];
     container.layer.shadowOpacity = 0.35;
     container.layer.shadowOffset = CGSizeMake(0, 2);
     container.layer.shadowRadius = 6;
     
     UIImage *img = [UIImage imageNamed:imageName];
     if (!img) img = [UIImage systemImageNamed:imageName];
     
     
     UIImageView *iv = [[UIImageView alloc] initWithImage:img];
     iv.translatesAutoresizingMaskIntoConstraints = NO;
     iv.contentMode = UIViewContentModeScaleToFill;
     iv.tintColor = AppPrimaryClr ?: UIColor.systemBlueColor;
     
     iv.layer.masksToBounds = NO;
     [iv pp_setShadowColor:[UIColor colorWithWhite:0 alpha:0.2]];
     iv.layer.shadowOpacity = 0.20;
     iv.layer.shadowOffset = CGSizeMake(0, 2);
     iv.layer.shadowRadius = 6;
     
     
 
     UILabel *lbl = [UILabel new];
     lbl.translatesAutoresizingMaskIntoConstraints = NO;
     lbl.text = title;
     lbl.font = [GM MidFontWithSize:16];
     lbl.textColor = AppPrimaryClrDarker ?: UIColor.labelColor;
     lbl.textAlignment = NSTextAlignmentCenter;
     
     UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:isRTL ? @[lbl, iv] : @[iv, lbl]];
     stack.translatesAutoresizingMaskIntoConstraints = NO;
     stack.axis = UILayoutConstraintAxisHorizontal;
     stack.alignment = UIStackViewAlignmentCenter;
     stack.spacing = 8;
     
     [container addSubview:stack];
     
     [NSLayoutConstraint activateConstraints:@[

 [stack.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
         [stack.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
         [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:container.leadingAnchor constant:42],
         [stack.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor constant:-42]
     ]];
     
     return container;
 }


 @end



 Should the reusable container view use image downloading (e.g., from URL using SDWebImage or similar)? Or should it assume local images only? i will add my loading image finc later i have it already , once you done i will add it before  testing
 
 i will use
 + (void)setImageFromUrlString:(NSString *)urlString imageView:(UIImageView *)imageView phImage:(NSString *)phImage completion:(_Nullable ImageCompletionBlock)completion;;
on class GM

 Should the badge be shown even if badge == 0 or hidden in that case? hidden

 Do you want the container to support tap gestures, or will you handle that externally? support
 
 
 */
