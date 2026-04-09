//
//  FavoriteButton.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/05/2025.
//

#import "FavoriteButton.h"
@import FirebaseAuth;

@implementation FavoriteFixedSizeButton

#pragma mark - 🔧 Init

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) [self setupFloatingStyle];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) [self setupFloatingStyle];
    return self;
}

#pragma mark - 🎨 Setup

- (void)setupFloatingStyle {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.adjustsImageWhenHighlighted = YES;
    self.showsMenuAsPrimaryAction = NO;
    self.isFavorite = NO;

    // 🔹 iOS 26+ native glass configuration
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration tintedButtonConfiguration];
        cfg.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        cfg.buttonSize  = UIButtonConfigurationSizeLarge;
        cfg.background.cornerRadius = 25;
        cfg.baseBackgroundColor = [AppPrimaryClr colorWithAlphaComponent:1.1];
        cfg.baseForegroundColor = AppForgroundColr;
        cfg.background.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:1.1];
        cfg.background.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.25];
        cfg.background.strokeWidth = 1.0;
        
        UIImage *img = [UIImage systemImageNamed:@"heart"];
        cfg.image = img;
        cfg.preferredSymbolConfigurationForImage =
            [UIImageSymbolConfiguration configurationWithPointSize:16
                                                            weight:UIImageSymbolWeightRegular
                                                             scale:UIImageSymbolScaleDefault];
        self.configuration = cfg;
        self.tintColor = AppForgroundColr;
    }
    // 🔹 Legacy style for < iOS 26.0
    else {
        // Default state
        [self updateAppearance];

        // Shadow for lift
        self.layer.shadowColor = UIColor.blackColor.CGColor;
        self.layer.shadowOpacity = 0.15;
        self.layer.shadowRadius = 4.0;
        self.layer.shadowOffset = CGSizeMake(0, 3);
    }

    [self addTarget:self action:@selector(toggleFavorite:) forControlEvents:UIControlEventTouchUpInside];
}

#pragma mark - 💖 Appearance

- (void)updateAppearance {
    NSString *iconName = self.isFavorite ? @"heart.fill" : @"heart";
    UIColor *tintColor = AppForgroundColr;
    UIColor *backgroundColor = [AppPrimaryClr colorWithAlphaComponent:1.1];

    [self setImage:[UIImage systemImageNamed:iconName] forState:UIControlStateNormal];
    self.backgroundColor = backgroundColor;
    self.tintColor = tintColor;

    if (@available(iOS 15.0, *)) {
        UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:16
                                                        weight:UIImageSymbolWeightRegular
                                                         scale:UIImageSymbolScaleDefault];
        [self setPreferredSymbolConfiguration:config forImageInState:UIControlStateNormal];
    }
}

#pragma mark - 🔄 Sync Initial State

- (void)initValue {
    if (PPCurrentUser && PPCurrentFIRAuthUser) {
        [PetAdManager isAdFavorited:self.adID
                            forUser:PPCurrentUser.ID
                         collection:self.collection
                         completion:^(BOOL favorited) {
            self.isFavorite = favorited;
            self.selected = favorited;
            [self updateAppearance];
        }];
    }
}

#pragma mark - ✨ Glow Animation for Favorite Button

- (void)animateFavButtonGlow:(UIButton *)button {
    UIColor *glowColor = [AppPrimaryClr colorWithAlphaComponent:0.7];
    button.layer.shadowColor = glowColor.CGColor;
    button.layer.shadowRadius = 16;
    button.layer.shadowOpacity = 0.0;
    button.layer.shadowOffset = CGSizeZero;

    CABasicAnimation *glow = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
    glow.fromValue = @(0.0);
    glow.toValue = @(0.9);
    glow.duration = 0.25;
    glow.autoreverses = YES;
    glow.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

    CABasicAnimation *scale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scale.fromValue = @(1.0);
    scale.toValue = @(1.08);
    scale.duration = 0.25;
    scale.autoreverses = YES;
    scale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[glow, scale];
    group.duration = 0.5;
    group.removedOnCompletion = YES;

    [button.layer addAnimation:group forKey:@"favGlowPulse"];
}

#pragma mark - 🩷 Interaction

- (void)toggleFavorite:(UIButton *)sender {
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    self.isFavorite = !self.isFavorite;
    [self updateAppearance];

    [UIView animateWithDuration:0.1 animations:^{
        self.transform = CGAffineTransformMakeScale(1.25, 1.25);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            self.transform = CGAffineTransformIdentity;
        }];
    }];

    UIImpactFeedbackGenerator *impact = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [impact impactOccurred];

    if (!PPIsNull(self.adID)) {
        if (self.isFavorite) {
            [PetAdManager addFavoriteAdWithID:self.adID
                                   collection:self.collection
                                    forUserID:[UserManager sharedManager].currentUser.ID];
            [self animateFavButtonGlow:sender];
        } else {
            [PetAdManager removeFavoriteAdWithID:self.adID
                                      collection:self.collection
                                       forUserID:[UserManager sharedManager].currentUser.ID];
        }
    }
}

@end












@implementation FavoriteFloatingButton

#pragma mark - 🔧 Init

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) [self setupFloatingStyle];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) [self setupFloatingStyle];
    return self;
}

#pragma mark - 🎨 Setup

- (void)setupFloatingStyle {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.adjustsImageWhenHighlighted = NO;
    self.showsMenuAsPrimaryAction = NO;
    self.isFavorite = NO;
    self.accessibilityLabel = NSLocalizedString(@"a11y_btn_favorite", @"Favorite");
    self.accessibilityHint  = NSLocalizedString(@"a11y_btn_favorite_hint", @"Double-tap to add or remove from favorites");
    self.accessibilityTraits = UIAccessibilityTraitButton;

    // Use a full 44pt hit target even though the visual stays compact.
    CGFloat size = 38.0;
    [NSLayoutConstraint activateConstraints:@[
        [self.widthAnchor constraintEqualToConstant:size],
        [self.heightAnchor constraintEqualToConstant:size]
    ]];

    self.layer.cornerRadius = size / 2.0;
    self.layer.masksToBounds = NO;

    // Subtle lift (not heavy shadow)
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = 0.08;
    self.layer.shadowRadius = 6.0;
    self.layer.shadowOffset = CGSizeMake(0, 3);

    [self updateAppearance];

    [self addTarget:self
             action:@selector(toggleFavorite)
   forControlEvents:UIControlEventTouchUpInside];
}

#pragma mark - 💖 Appearance

- (void)updateAppearance {
    NSString *iconName = self.isFavorite ? @"heart.fill" : @"heart";

    UIColor *bgColor;
    UIColor *iconColor;

    if (self.isFavorite) {
        // Active / favorited
        bgColor   = [AppForgroundColr colorWithAlphaComponent:0.85];
        iconColor = AppPrimaryClr;
    } else {
        // Idle / unfavorited
        bgColor   = [AppForgroundColr colorWithAlphaComponent:0.72];
        iconColor = UIColor.secondaryLabelColor;
    }

    self.backgroundColor = bgColor;
    self.tintColor = iconColor;

    // ── Accessibility: Update label based on favorite state ──
    self.accessibilityLabel = self.isFavorite
        ? NSLocalizedString(@"a11y_btn_unfavorite", @"Remove from favorites")
        : NSLocalizedString(@"a11y_btn_favorite", @"Favorite");

    [self setImage:[UIImage systemImageNamed:iconName]
          forState:UIControlStateNormal];

    if (@available(iOS 15.0, *)) {
        UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:16
                                                        weight:UIImageSymbolWeightMedium
                                                         scale:UIImageSymbolScaleMedium];

        if (self.isFavorite) {
            config = [config configurationByApplyingConfiguration:
                      [UIImageSymbolConfiguration configurationWithHierarchicalColor:iconColor]];
        }

        [self setPreferredSymbolConfiguration:config
                         forImageInState:UIControlStateNormal];
    }
}


#pragma mark - 🔄 Sync Initial State

- (void)initValue {
    if (PPCurrentUser && PPCurrentFIRAuthUser) {
        [PetAdManager isAdFavorited:self.adID
                            forUser:PPCurrentUser.ID
                         collection:self.collection
                         completion:^(BOOL favorited) {
            self.isFavorite = favorited;
            self.selected = favorited;
            [self updateAppearance];
        }];
    }
}

#pragma mark - 🩷 Interaction

- (void)toggleFavorite {
    if (!UserManager.sharedManager.isUserLoggedIn) { [UserManager showPromptOnTopController]; return; }

    self.isFavorite = !self.isFavorite;
    [self updateAppearance];

    if (@available(iOS 18.0, *)) {
        [self.imageView addSymbolEffect:[NSSymbolBounceEffect effect]];
    }
    
    // Smooth "pop" feedback
    [UIView animateWithDuration:0.1 animations:^{
        self.transform = CGAffineTransformMakeScale(1.25, 1.25);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            self.transform = CGAffineTransformIdentity;
        }];
    }];
    
    // Optional haptic
    UIImpactFeedbackGenerator *impact = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [impact impactOccurred];
    
    // Sync to Firestore
    if (!PPIsNull(self.adID)) {
        if (self.isFavorite) {
            [PetAdManager addFavoriteAdWithID:self.adID
                                   collection:self.collection
                                    forUserID:[UserManager sharedManager].currentUser.ID];
        } else {
            [PetAdManager removeFavoriteAdWithID:self.adID
                                      collection:self.collection
                                       forUserID:[UserManager sharedManager].currentUser.ID];
        }
    }

    //if ([self.delegate respondsToSelector:@selector(favoriteButtonDidToggle:)]) {
    //    [self.delegate favoriteButtonDidToggle:self];
    //}
}

@end












@implementation FavoriteButton

#pragma mark - 🔧 Initializers

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit_FavoriteButton];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit_FavoriteButton];
    }
    return self;
}

#pragma mark - 🎨 Common Setup

/// Shared setup used by both initializers
- (void)commonInit_FavoriteButton {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.adjustsImageWhenHighlighted = YES;
    self.showsMenuAsPrimaryAction = NO;
    
    // Load initial style based on current favorite state
    [self refreshAppearance];

    [self addTarget:self action:@selector(favButtonTapped)
   forControlEvents:UIControlEventTouchUpInside];
}

#pragma mark - 💖 Styles

/// Default “not favorited” style
- (void)setStyleNormal {
    UIImage *heart = [Utils imageWithName:@"heart"
                                   Weight:UIImageSymbolWeightRegular
                                 andScale:UIImageSymbolScaleDefault
                                  andSize:16];
 
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration tintedButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.baseForegroundColor = AppForgroundColr;
        config.baseBackgroundColor = [AppButtonMixColorClr colorWithAlphaComponent:1.0];
        config.image = [UIImage systemImageNamed:@"heart"];
        config.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);

        self.configuration = config;
        [self setPreferredSymbolConfiguration:
            [UIImageSymbolConfiguration configurationWithPointSize:16
                                                            weight:UIImageSymbolWeightRegular
                                                             scale:UIImageSymbolScaleSmall]
                         forImageInState:UIControlStateNormal];
    } else {
        [self setImage:heart forState:UIControlStateNormal];
        self.backgroundColor = AppButtonMixColorClr;
        self.tintColor = AppForgroundColr;
        [self applyGlassStyleWithCornerRadius:12
                                         style:UIBlurEffectStyleSystemThinMaterialLight
                                   tintOverlay:[UIColor colorWithWhite:1.0 alpha:0.08]];
    }
}
- (void)applyGlassStyleWithCornerRadius:(CGFloat)radius
                                  style:(UIBlurEffectStyle)style
                            tintOverlay:(nullable UIColor *)tint
{
    self.layer.cornerRadius = radius;
    self.layer.masksToBounds = YES;
    self.backgroundColor = UIColor.clearColor;
    
    // Remove existing blur/tint if reapplying
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]] || sub.tag == 9999) {
            [sub removeFromSuperview];
        }
    }

    if (@available(iOS 13.0, *)) {
        // Create blur
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:style];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.translatesAutoresizingMaskIntoConstraints = NO;
        blurView.userInteractionEnabled = NO;
        blurView.layer.cornerRadius = radius;
        blurView.layer.masksToBounds = YES;
        [self insertSubview:blurView atIndex:0];

        // Constrain blur to fill button
        [NSLayoutConstraint activateConstraints:@[
            [blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor]
        ]];

        // Optional tint overlay (subtle highlight or darkening)
        if (tint) {
            UIView *overlay = [[UIView alloc] init];
            overlay.translatesAutoresizingMaskIntoConstraints = NO;
            overlay.backgroundColor = tint;
            overlay.userInteractionEnabled = NO;
            overlay.layer.cornerRadius = radius;
            overlay.layer.masksToBounds = YES;
            overlay.tag = 9999;
            [self insertSubview:overlay aboveSubview:blurView];

            [NSLayoutConstraint activateConstraints:@[
                [overlay.topAnchor constraintEqualToAnchor:self.topAnchor],
                [overlay.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
                [overlay.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
                [overlay.trailingAnchor constraintEqualToAnchor:self.trailingAnchor]
            ]];
        }

    } else {
        // Fallback for iOS 12 and earlier
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
    }
}
/// Highlighted “favorited” style
- (void)setStyleIsFav {
    UIImage *heartFill = [Utils imageWithName:@"heart.fill"
                                       Weight:UIImageSymbolWeightRegular
                                     andScale:UIImageSymbolScaleDefault
                                      andSize:16];
    
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.baseForegroundColor = AppForgroundColr;
        config.baseBackgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.95];
        config.image = [UIImage systemImageNamed:@"heart.fill"];
        config.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);

        self.configuration = config;
        [self setPreferredSymbolConfiguration:
            [UIImageSymbolConfiguration configurationWithPointSize:16
                                                            weight:UIImageSymbolWeightRegular
                                                             scale:UIImageSymbolScaleSmall]
                         forImageInState:UIControlStateNormal];
    } else {
        [self setImage:heartFill forState:UIControlStateNormal];
        self.tintColor = AppPrimaryClr;
        self.backgroundColor = AppForgroundColr;
        [self applyGlassStyleWithCornerRadius:12
                                         style:UIBlurEffectStyleSystemThinMaterialLight
                                   tintOverlay:[UIColor colorWithWhite:1.0 alpha:0.08]];
    }
}

#pragma mark - 🩷 Favorite Toggle Logic

- (void)favButtonTapped {
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    self.isFavorite = !self.isFavorite;
    self.selected = self.isFavorite;

    // 💫 Animate “pop” feedback
    [UIView animateWithDuration:0.1 animations:^{
        self.transform = CGAffineTransformMakeScale(1.25, 1.25);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            self.transform = CGAffineTransformIdentity;
        }];
    }];

    // 🔄 Apply correct visual style
    [self refreshAppearance];

    // 🎯 Save favorite state in Firestore
    if (!PPIsNull(self.adID)) {
        if (self.isFavorite) {
            [PetAdManager addFavoriteAdWithID:self.adID
                                   collection:self.collection
                                    forUserID:[UserManager sharedManager].currentUser.ID];
        } else {
            [PetAdManager removeFavoriteAdWithID:self.adID
                                      collection:self.collection
                                       forUserID:[UserManager sharedManager].currentUser.ID];
        }
    }

    // 🔊 Optional delegate callback
    //if ([self.delegate respondsToSelector:@selector(favoriteButtonDidToggle:)]) {
    //    [self.delegate favoriteButtonDidToggle:self];
    //}

    // 🩷 Haptic feedback
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
}

#pragma mark - 🔄 Sync Initial State

- (void)initValue {
    [self refreshAppearance];
    if (PPCurrentUser && PPCurrentFIRAuthUser) {
        [PetAdManager isAdFavorited:self.adID
                            forUser:PPCurrentUser.ID
                         collection:self.collection
                         completion:^(BOOL favorited) {
            self.isFavorite = favorited;
            self.selected = favorited;
            [self refreshAppearance];
        }];
    }
}

- (void)refreshAppearance {
    if (self.isFavorite) {
        [self setStyleIsFav];
    } else {
        [self setStyleNormal];
    }
}

#pragma mark - 🎨 Tint Utilities

- (void)colosTint {
    self.tintColor = GM.AccentsColor;
}

- (void)colosTintForPurePrimaryColor {
    self.tintColor = [GM appPrimaryColor];
}

- (void)colosTintForAds {
    self.tintColor = AppPrimaryClr;
}

- (void)colosTintForViewer {
    self.tintColor = GM.AccentsColor;
}

- (void)whiteColosTintForViewer {
    self.tintColor = AppPrimaryClr;
}

@end
