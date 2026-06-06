
#import "PPFirebaseSessionBridge.h"

static UIWindow *ppAlertOverlayWindow = nil;
static UIViewController *ppAlertRootViewController = nil;

static NSString *PPAlertSanitizedText(NSString *text, NSString *fallbackKey)
{
    if (text.length == 0) return text;
    return [PPFirebaseSessionBridge publicMessageForText:text fallbackKey:fallbackKey] ?: text;
}

@implementation PPAlert {
    UIButton *_containerView;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UIButton *_confirmButton;
    UIButton *_cancelButton;
    UIColor *_typeColor;
    UITextField *_textField;   // ✅ add this
    void (^_cancelAction)(void);
    AlertCompletionBlock _alertBlock;
}

-(void)layoutSubviews
{
    [super layoutSubviews];
}
- (UIButton *)darkGlassButtonWithCornerStyle:(UIButtonConfigurationCornerStyle)corner {
    UIButton *btn;

    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.cornerStyle = corner;

        // Force DARK Glass
        cfg.baseBackgroundColor = [UIColor colorWithWhite:0 alpha:0.50]; // dark glass
        cfg.background.backgroundColor = [UIColor colorWithWhite:0 alpha:0.40];

        // Optional: darker border
        cfg.background.strokeWidth = 1.0;
        cfg.background.strokeColor = [UIColor colorWithWhite:1 alpha:0.45];

        // Optional: text color
        cfg.baseForegroundColor = UIColor.whiteColor;

        // Optional: inset tuning
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(12, 12, 12, 12);

        btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.configuration = cfg;
    } else {
        // iOS < 26 fallback
        btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
        btn.layer.cornerRadius = 16;
        btn.layer.masksToBounds = YES;
        [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    }

    return btn;
}
 
- (instancetype)initWithType:(PPAlertType)type
                      title:(NSString *)title
                   subtitle:(NSString *)subtitle
                       icon:(UIImage *)icon
                confirmTitle:(NSString * _Nullable)confirmTitle
                 cancelTitle:(NSString * _Nullable)cancelTitle
               confirmAction:(AlertCompletionBlock _Nullable)confirmAction
                cancelAction:(void(^ _Nullable)(void))cancelAction {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        // Setup background blur effect
        
        UIView *bg;
        if(PPIOS26())
        {
            UIButton *backgroundView = [self darkGlassButtonWithCornerStyle:UIButtonConfigurationCornerStyleFixed];
            backgroundView.translatesAutoresizingMaskIntoConstraints = NO;
            backgroundView.alpha = 1.0;
            
            [self addSubview:backgroundView];
            bg= backgroundView;
            [NSLayoutConstraint activateConstraints:@[
                [backgroundView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:-3],
                [backgroundView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:3],
                [backgroundView.topAnchor constraintEqualToAnchor:self.topAnchor constant:-3],
                [backgroundView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:3],
            ]];
        }
        else
        {
            UIVisualEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
            UIVisualEffectView *backgroundView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
            backgroundView.translatesAutoresizingMaskIntoConstraints = NO;
            backgroundView.alpha = 0.9;
            [self addSubview:backgroundView];
            bg= backgroundView;
            [NSLayoutConstraint activateConstraints:@[
                [backgroundView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
                [backgroundView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
                [backgroundView.topAnchor constraintEqualToAnchor:self.topAnchor],
                [backgroundView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
            ]];
        }
        
        // Initialize container view
        _containerView = [self setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleMedium];
        _containerView.translatesAutoresizingMaskIntoConstraints = NO;
        _containerView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.7];
        _containerView.layer.cornerRadius = 32.0;
         [self addSubview:_containerView];
        
        // Center container with fixed margins
        [NSLayoutConstraint activateConstraints:@[
            [_containerView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor constant:-40],
            [_containerView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_containerView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:50],
            [_containerView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-50]
        ]];
        
        
       
        
        // Determine type color and icon
        UIImage *iconImage = icon;
        switch (type) {
            case PPAlertTypeSuccess:
                _typeColor = [UIColor systemGreenColor];
                if (!iconImage) {
                    iconImage = [UIImage systemImageNamed:@"checkmark.circle"];
                }
                break;
            case PPAlertTypeError:
                _typeColor = [UIColor systemRedColor];
                if (!iconImage) {
                    iconImage = [UIImage systemImageNamed:@"multiply.circle"];
                }
                break;
            case PPAlertTypeWarning:
                _typeColor = [UIColor orangeColor];
                if (!iconImage) {
                    iconImage = [UIImage systemImageNamed:@"icon_warning"];
                }
                break;
            case PPAlertTypeInfo:
                _typeColor = AppPrimaryClr;
                if (!iconImage) {
                    iconImage = [UIImage systemImageNamed:@"info.circle"];
                }
                break;
            case PPAlertTypeConfirmation:
                _typeColor = AppPrimaryClr;
                if (!iconImage) {
                    iconImage = [UIImage systemImageNamed:@"info.circle"];
                }
            case PPAlertTypeTextInput:
                _typeColor = [AppPrimaryClr colorWithAlphaComponent:1.0];
                if (!iconImage) {
                    iconImage = [UIImage systemImageNamed:@"info.circle"];
                }
                break;
        }
        
        // Icon ImageView (if iconImage exists)
        if (iconImage) {
            UIImageView *iconView = [[UIImageView alloc] initWithImage:iconImage];
            iconView.translatesAutoresizingMaskIntoConstraints = NO;
            iconView.contentMode = UIViewContentModeScaleAspectFit;
            
            if(type != PPAlertTypeTextInput)
            {
                iconView.tintColor = AppPrimaryClr;
            }
            [_containerView addSubview:iconView];
            [NSLayoutConstraint activateConstraints:@[
                [iconView.topAnchor constraintEqualToAnchor:_containerView.topAnchor constant:30],
                [iconView.centerXAnchor constraintEqualToAnchor:_containerView.centerXAnchor constant:0],
                [iconView.widthAnchor constraintEqualToConstant:32],
                [iconView.heightAnchor constraintEqualToConstant:32]
            ]];
            if (@available(iOS 18.0, *)) {
                [iconView addSymbolEffect: [NSSymbolWiggleEffect effect]];
            } else {
                // Fallback on earlier versions
            }
            // Title Label below icon
            _titleLabel = [[UILabel alloc] init];
            _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
            _titleLabel.font = [GM boldFontWithSize:19];
            _titleLabel.textColor = [UIColor labelColor];
            _titleLabel.textAlignment = NSTextAlignmentCenter;
            _titleLabel.numberOfLines = 0;
            _titleLabel.text = title;
            [_containerView addSubview:_titleLabel];
            [NSLayoutConstraint activateConstraints:@[
                [_titleLabel.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:16],
                [_titleLabel.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor constant:16],
                [_titleLabel.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor constant:-16]
            ]];
        } else {
            // Title Label at top if no icon
            _titleLabel = [[UILabel alloc] init];
            _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
            _titleLabel.font = [GM boldFontWithSize:19];
            _titleLabel.textColor = [UIColor labelColor];
            _titleLabel.textAlignment = NSTextAlignmentCenter;
            _titleLabel.numberOfLines = 0;
            _titleLabel.text = title;
            [_containerView addSubview:_titleLabel];
            [NSLayoutConstraint activateConstraints:@[
                [_titleLabel.topAnchor constraintEqualToAnchor:_containerView.topAnchor constant:20],
                [_titleLabel.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor constant:16],
                [_titleLabel.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor constant:-16]
            ]];
        }
        
         // Subtitle Label
        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subtitleLabel.font = [GM MidFontWithSize:16];
        _subtitleLabel.textColor = [UIColor secondaryLabelColor];
        _subtitleLabel.textAlignment = NSTextAlignmentCenter;
        _subtitleLabel.numberOfLines = 0;
        _subtitleLabel.text = subtitle;
        [_containerView addSubview:_subtitleLabel];
        [NSLayoutConstraint activateConstraints:@[
            [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:8],
            [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor constant:16],
            [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor constant:-16]
        ]];

        // ✅ Text field under subtitle
        _textField = [[UITextField alloc] init];
        _textField.translatesAutoresizingMaskIntoConstraints = NO;
        _textField.font = [GM MidFontWithSize:16];
        _textField.textColor = UIColor.labelColor;
        _textField.textAlignment = GM.setAligment;
        _textField.borderStyle = UITextBorderStyleRoundedRect;
        _textField.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.06];
        _textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        _textField.returnKeyType = UIReturnKeyDone;
        _textField.placeholder = @"";   // you can expose API to configure it
        [_containerView addSubview:_textField];
        _textField.hidden = type != PPAlertTypeTextInput;
        [NSLayoutConstraint activateConstraints:@[
            [_textField.topAnchor constraintEqualToAnchor:_subtitleLabel.bottomAnchor constant:12],
            [_textField.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor constant:16],
            [_textField.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor constant:-16],
            [_textField.heightAnchor constraintEqualToConstant:40.0]
        ]];

        
        // Buttons
        if (cancelTitle) {
            // Two-button (confirmation) layout
            _cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
            _cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
            [_cancelButton setTitle:cancelTitle forState:UIControlStateNormal];
            _cancelButton.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.8];
            [_cancelButton setTitleColor:_typeColor forState:UIControlStateNormal];
            _cancelButton.titleLabel.font = [GM MidFontWithSize:17];
            _cancelButton.layer.cornerRadius = 24;
            _cancelButton.layer.borderWidth = 1;
            [_cancelButton pp_setBorderColor:_typeColor];
            [_cancelButton addTarget:self action:@selector(handleCancel) forControlEvents:UIControlEventTouchUpInside];
            [_containerView addSubview:_cancelButton];
            
            _confirmButton = [UIButton buttonWithType:UIButtonTypeCustom];
            _confirmButton.translatesAutoresizingMaskIntoConstraints = NO;
            [_confirmButton setTitle:confirmTitle forState:UIControlStateNormal];
            _confirmButton.backgroundColor = _typeColor;
            [_confirmButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            _confirmButton.titleLabel.font = [GM boldFontWithSize:17];
            _confirmButton.layer.cornerRadius = 24;
            [_confirmButton addTarget:self action:@selector(handleConfirm) forControlEvents:UIControlEventTouchUpInside];
            [_containerView addSubview:_confirmButton];
            NSLayoutYAxisAnchor *yAnchor = type == PPAlertTypeTextInput ? _textField.bottomAnchor : _subtitleLabel.bottomAnchor;
            [NSLayoutConstraint activateConstraints:@[
                [_cancelButton.topAnchor constraintEqualToAnchor:yAnchor constant:20],
                [_cancelButton.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor constant:16],
                [_cancelButton.bottomAnchor constraintEqualToAnchor:_containerView.bottomAnchor constant:-20],
                
                [_confirmButton.topAnchor constraintEqualToAnchor:yAnchor constant:20],
                [_confirmButton.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor constant:-16],
                [_confirmButton.bottomAnchor constraintEqualToAnchor:_containerView.bottomAnchor constant:-20],
                
                [_cancelButton.trailingAnchor constraintEqualToAnchor:_confirmButton.leadingAnchor constant:-8],
                [_cancelButton.widthAnchor constraintEqualToAnchor:_confirmButton.widthAnchor],
                
                [_cancelButton.heightAnchor constraintEqualToConstant:48],
                [_confirmButton.heightAnchor constraintEqualToConstant:48]
            ]];
            
            // Store actions
            _alertBlock = [confirmAction copy];
            _cancelAction = [cancelAction copy];
        } else {
            // Single button layout
            _confirmButton = [UIButton buttonWithType:UIButtonTypeCustom];
            _confirmButton.translatesAutoresizingMaskIntoConstraints = NO;
            NSString *okTitle = confirmTitle ? confirmTitle : @"OK";
            [_confirmButton setTitle:okTitle forState:UIControlStateNormal];
            _confirmButton.backgroundColor = _typeColor;
            [_confirmButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            _confirmButton.titleLabel.font = [GM boldFontWithSize:17];
            _confirmButton.layer.cornerRadius = 24;
            [_confirmButton addTarget:self action:@selector(handleConfirm) forControlEvents:UIControlEventTouchUpInside];
            [_containerView addSubview:_confirmButton];
            
            [NSLayoutConstraint activateConstraints:@[
                [_confirmButton.topAnchor constraintEqualToAnchor:_subtitleLabel.bottomAnchor constant:20],
                [_confirmButton.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor constant:16],
                [_confirmButton.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor constant:-16],
                [_confirmButton.bottomAnchor constraintEqualToAnchor:_containerView.bottomAnchor constant:-20],
                [_confirmButton.heightAnchor constraintEqualToConstant:48]
            ]];
            
            _alertBlock = [confirmAction copy];
            _cancelAction = [cancelAction copy];
        }
    }
    return self;
}

- (UIButton *)setButtonAsBackroundButtonWithStyle:(UIButtonConfigurationCornerStyle)style{
    if (@available(iOS 26.0, *)) {
        return [self setButtonAsBackroundButtonWithStyle:style configType:PPButtonConfigrationGlass];
    } else {
        return [self setButtonAsBackroundButtonWithStyle:style configType:PPButtonConfigrationFilled];
    }
}

- (UIButton *)setButtonAsBackroundButtonWithStyle:(UIButtonConfigurationCornerStyle)style configType:(PPButtonConfigration)configType{
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
         cfg.background.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.0];
        cfg.baseBackgroundColor = [AppForgroundColr colorWithAlphaComponent:0.0];
 
        if(style == UIButtonConfigurationCornerStyleFixed)
            cfg.background.cornerRadius = 50;

        bgButton = [UIButton  buttonWithType:UIButtonTypeSystem];
        bgButton.configuration = cfg;
     } else {
         
 
        // 🌫️ Fallback for iOS <26
        bgButton = [UIButton buttonWithType:UIButtonTypeSystem];
        bgButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        bgButton.layer.cornerRadius = 16;
        bgButton.layer.masksToBounds = YES;
        
    }

    bgButton.translatesAutoresizingMaskIntoConstraints = NO;
 
    [bgButton pp_setShadowColor:AppShadowClr];
    bgButton.layer.shadowOpacity = 0.15;
    bgButton.layer.shadowRadius = 8;
    bgButton.layer.shadowOffset = CGSizeMake(0, 2);
    
    return bgButton;
}
- (void)showInViewController:(UIViewController *)vc {
    // Always run on main thread
    dispatch_async(dispatch_get_main_queue(), ^{

        // 1) Create overlay window if needed
        if (!ppAlertOverlayWindow) {
            UIWindowScene *scene = nil;
            // prefer active foreground scene
            for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]] &&
                    s.activationState == UISceneActivationStateForegroundActive) {
                    scene = (UIWindowScene *)s;
                    break;
                }
            }
            // fallback to any UIWindowScene
            if (!scene) {
                for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
                    if ([s isKindOfClass:[UIWindowScene class]]) {
                        scene = (UIWindowScene *)s;
                        break;
                    }
                }
            }

            if (scene) {
                ppAlertOverlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
            } else {
                // iOS 12 or no scene available — use initWithFrame
                ppAlertOverlayWindow = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
            }

            ppAlertOverlayWindow.backgroundColor = [UIColor clearColor];
            // Keep above everything
            ppAlertOverlayWindow.windowLevel = UIWindowLevelAlert + 1;
            ppAlertOverlayWindow.hidden = NO;

            ppAlertRootViewController = [UIViewController new];
            ppAlertRootViewController.view.backgroundColor = [UIColor clearColor];
            ppAlertOverlayWindow.rootViewController = ppAlertRootViewController;

            // Make visible without stealing key status permanently
            ppAlertOverlayWindow.alpha = 1.0;
            ppAlertOverlayWindow.hidden = NO;
        }

        // 2) Ensure this view uses autolayout in the overlay root view
        self.translatesAutoresizingMaskIntoConstraints = NO;
        [ppAlertRootViewController.view addSubview:self];

        [NSLayoutConstraint activateConstraints:@[
            [self.leadingAnchor constraintEqualToAnchor:ppAlertRootViewController.view.leadingAnchor],
            [self.trailingAnchor constraintEqualToAnchor:ppAlertRootViewController.view.trailingAnchor],
            [self.topAnchor constraintEqualToAnchor:ppAlertRootViewController.view.topAnchor],
            [self.bottomAnchor constraintEqualToAnchor:ppAlertRootViewController.view.bottomAnchor]
        ]];

        // 3) Same appear animation as before
        self.alpha = 0;
        self->_containerView.transform = CGAffineTransformMakeScale(0.8, 0.8);

        __weak typeof(self) weakSelf = self;
        [UIView animateKeyframesWithDuration:0.55
                                       delay:0
                                     options:0
                                  animations:^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            // Fade in + pop up
            [UIView addKeyframeWithRelativeStartTime:0.0
                                    relativeDuration:0.5
                                          animations:^{
                self.alpha = 1;
                self->_containerView.transform = CGAffineTransformMakeScale(1.15, 1.15);
            }];

            // Overshoot down a little
            [UIView addKeyframeWithRelativeStartTime:0.5
                                    relativeDuration:0.45
                                          animations:^{
                self->_containerView.transform = CGAffineTransformMakeScale(0.95, 0.95);
            }];

            // Settle to normal size
            [UIView addKeyframeWithRelativeStartTime:0.85
                                    relativeDuration:0.35
                                          animations:^{
                self->_containerView.transform = CGAffineTransformIdentity;
            }];
        } completion:nil];
    });
}

- (void)handleConfirm {
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.2 animations:^{
        weakSelf.alpha = 0;
        self->_containerView.transform = CGAffineTransformMakeScale(0.8, 0.8);
    } completion:^(BOOL finished) {
        PPAlert *strongSelf = weakSelf;
        [strongSelf removeFromSuperview];

        // Clean up overlay window if this alert created it
        if (ppAlertOverlayWindow) {
            // hide and release
            ppAlertOverlayWindow.hidden = YES;
            ppAlertOverlayWindow.rootViewController = nil;
            ppAlertOverlayWindow = nil;
            ppAlertRootViewController = nil;
        }
        if (strongSelf->_alertBlock) {
            strongSelf->_alertBlock(strongSelf->_textField.text,YES);
        }
    }];
}

- (void)handleCancel {
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.2 animations:^{
        weakSelf.alpha = 0;
        self->_containerView.transform = CGAffineTransformMakeScale(0.8, 0.8);
    } completion:^(BOOL finished) {
        PPAlert *strongSelf = weakSelf;
        [strongSelf removeFromSuperview];

        // Clean up overlay window if this alert created it
        if (ppAlertOverlayWindow) {
            // hide and release
            ppAlertOverlayWindow.hidden = YES;
            ppAlertOverlayWindow.rootViewController = nil;
            ppAlertOverlayWindow = nil;
            ppAlertRootViewController = nil;
        }
        if (strongSelf->_cancelAction) {
            strongSelf->_cancelAction();
        }
    }];
}

@end

@implementation PPAlertHelper

+ (void)showTextFieldAlertIn:(UIViewController *)vc title:(NSString *)title subtitle:(NSString *)subtitle placeholder:(NSString *)placeholder initialText:(NSString *)initialText confirmText:(NSString *)confirmText cancelText:(NSString *)cancelText completion:(AlertCompletionBlock)completion
{
    
    if (!vc) {
        if (completion) completion(nil,NO);
        return;
    }
    
    UIImage *icon = [UIImage pp_symbolNamed:@"pencil.and.scribble" pointSize:20 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleLarge palette:@[AppPrimaryClr,UIColor.secondaryLabelColor] makeTemplate:YES];

    PPAlert *alert = [[PPAlert alloc] initWithType:PPAlertTypeTextInput
                                             title:title
                                          subtitle:subtitle
                                              icon:icon
                                      confirmTitle:kLang(@"OK")
                                       cancelTitle:kLang(@"Cancel")
                                     confirmAction:completion  // Pass completion as confirm action
                                      cancelAction:nil];
    
    [alert showInViewController:vc];
    
}

+ (void)showConfirmationIn:(UIViewController *)vc
                     title:(NSString *)title
                  subtitle:(NSString *)subtitle
               placeholder:(NSString * _Nullable)placeholder
             confirmButton:(NSString *)confirmTitle
              cancelButton:(NSString *)cancelTitle
                      icon:(UIImage * _Nullable)icon
               confirmBlock:(AlertCompletionBlock _Nullable)confirmBlock
                cancelBlock:(void(^ _Nullable)(void))cancelBlock
{
    // `placeholder` was used in the old FCAlertView text-field variant.
    // Our PPAlert confirmation has no text field, so we safely ignore it
    // and forward to the main confirmation helper.
    
    [self showConfirmationIn:vc
                       title:title
                    subtitle:subtitle
               confirmButton:confirmTitle
                cancelButton:cancelTitle
                        icon:icon
                 confirmBlock:confirmBlock
                  cancelBlock:cancelBlock];
}



+ (void)showSuccessIn:(UIViewController *)vc
                title:(NSString *)title
             subtitle:(NSString *)subtitle
        confirmAction:(AlertCompletionBlock _Nullable)confirmAction
         cancelAction:(void (^)(void))cancelAction {

    UIImage *icon = [UIImage systemImageNamed:@"checkmark.circle"];
  
    
       
    PPAlert *alert =
    [[PPAlert alloc] initWithType:PPAlertTypeSuccess
                            title:title
                         subtitle:subtitle
                            icon:icon
                     confirmTitle:kLang(@"OK")
                      cancelTitle:nil
                    confirmAction:confirmAction
                     cancelAction:^{
                        if (cancelAction) cancelAction();
                    }];

    [alert showInViewController:vc];
}


+ (void)showSuccessIn:(UIViewController *)vc
                title:(NSString *)title
             subtitle:(NSString *)subtitle
               OKAction:(AlertCompletionBlock _Nullable)okAction {

    UIImage *icon = [UIImage systemImageNamed:@"checkmark.circle"];

    PPAlert *alert = [[PPAlert alloc] initWithType:PPAlertTypeSuccess
                                             title:title
                                          subtitle:subtitle
                                              icon:icon
                                       confirmTitle:kLang(@"OK")
                                        cancelTitle:nil
                                      confirmAction:okAction
                                       cancelAction:nil];

    [alert showInViewController:vc];
}


+ (void)showSuccessIn:(UIViewController *)vc title:(NSString *)title subtitle:(NSString * _Nullable)subtitle {
    UIImage *icon = [UIImage systemImageNamed:@"checkmark.circle"];
    PPAlert *alert = [[PPAlert alloc] initWithType:PPAlertTypeSuccess title:title subtitle:subtitle icon:icon confirmTitle:kLang(@"OK") cancelTitle:nil confirmAction:nil cancelAction:nil];
    [alert showInViewController:vc];
}

+ (void)showErrorIn:(UIViewController *)vc title:(NSString *)title subtitle:(NSString * _Nullable)subtitle {
    UIImage *icon = [UIImage systemImageNamed:@"multiply.circle"];
    NSString *safeTitle = PPAlertSanitizedText(title, @"Error");
    NSString *safeSubtitle = PPAlertSanitizedText(subtitle, @"SomethingWentWrong");
    PPAlert *alert = [[PPAlert alloc] initWithType:PPAlertTypeError title:safeTitle subtitle:safeSubtitle icon:icon confirmTitle:kLang(@"OK") cancelTitle:nil confirmAction:nil cancelAction:nil];
    [alert showInViewController:vc];
}

+ (void)showWarningIn:(UIViewController *)vc title:(NSString *)title subtitle:(NSString * _Nullable)subtitle {
    UIImage *icon = [UIImage systemImageNamed:@"icon_warning"];
    NSString *safeTitle = PPAlertSanitizedText(title, @"warningTitle");
    NSString *safeSubtitle = PPAlertSanitizedText(subtitle, @"SomethingWentWrong");
    PPAlert *alert = [[PPAlert alloc] initWithType:PPAlertTypeWarning title:safeTitle subtitle:safeSubtitle icon:icon confirmTitle:kLang(@"OK") cancelTitle:nil confirmAction:nil cancelAction:nil];
    [alert showInViewController:vc];
}

+ (void)showInfoIn:(UIViewController *)vc title:(NSString *)title subtitle:(NSString * _Nullable)subtitle {
    UIImage *icon = [UIImage systemImageNamed:@"icon_info"];
    NSString *safeTitle = PPAlertSanitizedText(title, @"Info");
    NSString *safeSubtitle = PPAlertSanitizedText(subtitle, @"SomethingWentWrong");
    PPAlert *alert = [[PPAlert alloc] initWithType:PPAlertTypeInfo title:safeTitle subtitle:safeSubtitle icon:icon confirmTitle:kLang(@"OK") cancelTitle:nil confirmAction:nil cancelAction:nil];
    [alert showInViewController:vc];
}

// Updated with completion blocks
+ (void)showWarningIn:(UIViewController *)vc
                title:(NSString *)title
             subtitle:(NSString * _Nullable)subtitle
           completion:(void (^ _Nullable)(void))completion {
    
    UIImage *icon = [UIImage systemImageNamed:@"icon_warning"];
    
    AlertCompletionBlock wrappedConfirm = ^(NSString * _Nullable text, BOOL didConfirm) {
        completion();
    };
    
    PPAlert *alert = [[PPAlert alloc] initWithType:PPAlertTypeWarning
                                             title:title
                                          subtitle:subtitle
                                              icon:icon
                                      confirmTitle:kLang(@"OK")
                                       cancelTitle:nil
                                     confirmAction:wrappedConfirm  // Pass completion as confirm action
                                      cancelAction:nil];
    
    [alert showInViewController:vc];
}

+ (void)showInfoIn:(UIViewController *)vc
             title:(NSString *)title
          subtitle:(NSString * _Nullable)subtitle
        completion:(void (^ _Nullable)(void))completion {
    
    UIImage *icon = [UIImage systemImageNamed:@"icon_info"];
    
    AlertCompletionBlock wrappedConfirm = ^(NSString * _Nullable text, BOOL didConfirm) {
        completion();
    };
    
    PPAlert *alert = [[PPAlert alloc] initWithType:PPAlertTypeInfo
                                             title:title
                                          subtitle:subtitle
                                              icon:icon
                                      confirmTitle:kLang(@"OK")
                                       cancelTitle:nil
                                     confirmAction:wrappedConfirm  // Pass completion as confirm action
                                      cancelAction:nil];
    
    [alert showInViewController:vc];
}

+ (void)showConfirmationIn:(UIViewController *)vc
                     title:(NSString *)title
                  subtitle:(NSString *)subtitle
             confirmButton:(NSString *)confirmTitle
              cancelButton:(NSString *)cancelTitle
                      icon:(UIImage * _Nullable)icon
               confirmBlock:(AlertCompletionBlock _Nullable)confirmBlock
                cancelBlock:(void(^ _Nullable)(void))cancelBlock {
    UIImage *iconImage = icon;
    if (!iconImage) {
        iconImage = [UIImage imageNamed:@"icon_info"];
    }
    
   
    
    PPAlert *alert = [[PPAlert alloc] initWithType:PPAlertTypeConfirmation title:title subtitle:subtitle icon:iconImage confirmTitle:confirmTitle cancelTitle:cancelTitle confirmAction:confirmBlock cancelAction:cancelBlock];
    [alert showInViewController:vc];
}

+ (void)showThreeActionConfirmationIn:(UIViewController *)vc
                                title:(NSString *)title
                             subtitle:(NSString * _Nullable)subtitle
                        primaryButton:(NSString *)primaryTitle
                         primaryStyle:(UIAlertActionStyle)primaryStyle
                      secondaryButton:(NSString *)secondaryTitle
                       secondaryStyle:(UIAlertActionStyle)secondaryStyle
                       tertiaryButton:(NSString *)tertiaryTitle
                        tertiaryStyle:(UIAlertActionStyle)tertiaryStyle
                         primaryBlock:(PPAlertSimpleActionBlock _Nullable)primaryBlock
                       secondaryBlock:(PPAlertSimpleActionBlock _Nullable)secondaryBlock
                        tertiaryBlock:(PPAlertSimpleActionBlock _Nullable)tertiaryBlock
{
    if (!vc) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presenter = vc;
        while (presenter.presentedViewController) {
            presenter = presenter.presentedViewController;
        }

        UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:title
                                            message:subtitle
                                     preferredStyle:UIAlertControllerStyleAlert];
        alert.view.tintColor = [GM appPrimaryColor];

        UIAlertAction *primaryAction =
        [UIAlertAction actionWithTitle:primaryTitle
                                 style:primaryStyle
                               handler:^(__unused UIAlertAction *action) {
            if (primaryBlock) {
                primaryBlock();
            }
        }];

        UIAlertAction *secondaryAction =
        [UIAlertAction actionWithTitle:secondaryTitle
                                 style:secondaryStyle
                               handler:^(__unused UIAlertAction *action) {
            if (secondaryBlock) {
                secondaryBlock();
            }
        }];

        UIAlertAction *tertiaryAction =
        [UIAlertAction actionWithTitle:tertiaryTitle
                                 style:tertiaryStyle
                               handler:^(__unused UIAlertAction *action) {
            if (tertiaryBlock) {
                tertiaryBlock();
            }
        }];

        [alert addAction:primaryAction];
        [alert addAction:secondaryAction];
        [alert addAction:tertiaryAction];
        alert.preferredAction = primaryAction;

        [presenter presentViewController:alert animated:YES completion:nil];
    });
}


// Show a fail alert with completion handler
+ (void)showFailIn:(UIViewController *)vc
             title:(NSString *)title
          subtitle:(NSString * _Nullable)subtitle
        completion:(void (^ _Nullable)(void))completion
{
    UIImage *icon = [UIImage systemImageNamed:@"xmark.octagon.fill"];

    AlertCompletionBlock wrappedConfirm = ^(NSString * _Nullable text, BOOL didConfirm) {
        if (completion) {
            completion();
        }
    };

    PPAlert *alert =
    [[PPAlert alloc] initWithType:PPAlertTypeError
                            title:title
                         subtitle:subtitle
                            icon:icon
                     confirmTitle:kLang(@"OK")
                      cancelTitle:nil
                    confirmAction:wrappedConfirm
                     cancelAction:nil];

    [alert showInViewController:vc];
}

@end








