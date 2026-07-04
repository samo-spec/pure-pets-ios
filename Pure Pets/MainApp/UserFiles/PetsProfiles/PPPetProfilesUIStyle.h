#pragma once

#import <UIKit/UIKit.h>
#import "Language.h"
#import "GM.h"

NS_ASSUME_NONNULL_BEGIN

// ─── Dynamic Colors ─────────────────────────────────────────────
// Light mode returns the EXACT original values (unchanged).
// Dark mode returns a cohesive warm-neutral dark theme.

static inline UIColor *PPPetsUICanvasColor(void) {
    if (AppBackgroundClr) return AppBackgroundClr;
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
        }
        return [UIColor colorWithRed:0.969 green:0.961 blue:0.949 alpha:1.0];
    }];
}

static inline UIColor *PPPetsUISurfaceColor(void) {
    if (AppSurfColor) return AppSurfColor;
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.17 green:0.17 blue:0.19 alpha:0.92];
        }
        return [[UIColor whiteColor] colorWithAlphaComponent:0.82];
    }];
}

static inline UIColor *PPPetsUISurfaceTintColor(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.22 green:0.19 blue:0.17 alpha:0.60];
        }
        return [[UIColor colorWithRed:0.99 green:0.96 blue:0.93 alpha:1.0] colorWithAlphaComponent:0.72];
    }];
}

static inline UIColor *PPPetsUISurfaceBorderColor(void) {
    if (AppLightGrayColor) return AppLightGrayColor;
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.85 green:0.80 blue:0.78 alpha:0.10];
        }
        return [UIColor colorWithRed:0.25 green:0.17 blue:0.18 alpha:0.08];
    }];
}

static inline UIColor *PPPetsUIBrandColor(void) {
    return AppPrimaryClr ?: UIColor.systemOrangeColor;
}
 

static inline UIColor *PPPetsUISecondaryTextColor(void) {
    return [UIColor.secondaryLabelColor colorWithAlphaComponent:0.92];
}

static inline UIColor *PPPetsUIShadowColor(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:0.0 alpha:0.50];
        }
        return [UIColor colorWithWhite:0.0 alpha:1.0];
    }];
}

static inline UISemanticContentAttribute PPPetsCurrentSemanticAttribute(void) {
    return GM.setSemantic;
}

static inline NSString *PPPetsForwardChevronSymbolName(void) {
    return Language.isRTL ? @"chevron.left" : @"chevron.right";
}

// White overlay on card surface — light keeps original alpha, dark softens it
static inline UIColor *PPPetsCardOverlay(CGFloat lightAlpha) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat a = (tc.userInterfaceStyle == UIUserInterfaceStyleDark)
            ? lightAlpha * 0.18
            : lightAlpha;
        return [[UIColor whiteColor] colorWithAlphaComponent:a];
    }];
}

// Glow fill for backdrop orbs — warmer and subtler in dark mode
static inline UIColor *PPPetsGlowFill(CGFloat r, CGFloat g, CGFloat b, CGFloat lightAlpha) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat a = (tc.userInterfaceStyle == UIUserInterfaceStyleDark)
            ? lightAlpha * 0.40
            : lightAlpha;
        return [UIColor colorWithRed:r green:g blue:b alpha:a];
    }];
}

static inline UIView *PPPetsBuildGlowView(UIColor *fillColor,
                                          UIColor *shadowColor,
                                          CGFloat shadowOpacity,
                                          CGFloat shadowRadius) {
    UIView *glow = [[UIView alloc] init];
    glow.translatesAutoresizingMaskIntoConstraints = NO;
    glow.userInteractionEnabled = NO;
    glow.backgroundColor = fillColor;
    UITraitCollection *tc = UITraitCollection.currentTraitCollection;
    glow.layer.shadowColor = [shadowColor resolvedColorWithTraitCollection:tc].CGColor;
    BOOL isDark = (tc.userInterfaceStyle == UIUserInterfaceStyleDark);
    glow.layer.shadowOpacity = isDark ? shadowOpacity * 0.4 : shadowOpacity;
    glow.layer.shadowRadius = shadowRadius;
    glow.layer.shadowOffset = CGSizeZero;
    return glow;
}

static inline void PPPetsApplyCanvasBackground(UIViewController *viewController, UITableView * _Nullable tableView) {
    UIColor *canvasColor = PPPetsUICanvasColor();
    viewController.view.backgroundColor = canvasColor;
    viewController.view.opaque = YES;
    if (viewController.navigationController) {
        viewController.navigationController.view.backgroundColor = canvasColor;
    }

    if (!tableView) {
        return;
    }

    tableView.backgroundColor = UIColor.clearColor;
    tableView.opaque = NO;

    UIView *backgroundView = tableView.backgroundView;
    if (!backgroundView) {
        backgroundView = [[UIView alloc] initWithFrame:tableView.bounds];
        backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        tableView.backgroundView = backgroundView;
    }
    backgroundView.backgroundColor = canvasColor;
}

static inline void PPPetsApplySurfaceStyle(UIView *view, CGFloat cornerRadius) {
    view.backgroundColor = PPPetsUISurfaceColor();
    view.layer.cornerRadius = cornerRadius;
    if (@available(iOS 13.0, *)) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
    view.layer.borderWidth = 1.0;
    UITraitCollection *tc = view.traitCollection ?: UITraitCollection.currentTraitCollection;
    view.layer.borderColor = [PPPetsUISurfaceBorderColor() resolvedColorWithTraitCollection:tc].CGColor;
    view.layer.shadowColor = [PPPetsUIShadowColor() resolvedColorWithTraitCollection:tc].CGColor;
    BOOL isDark = (tc.userInterfaceStyle == UIUserInterfaceStyleDark);
    view.layer.shadowOpacity = isDark ? 0.30f : 0.08f;
    view.layer.shadowRadius = isDark ? 16.0 : 24.0;
    view.layer.shadowOffset = isDark ? CGSizeMake(0.0, 8.0) : CGSizeMake(0.0, 14.0);
    view.layer.masksToBounds = NO;
}

static inline void PPPetsApplySurfaceCellStyle(UITableViewCell *cell, CGFloat cornerRadius) {
    cell.backgroundColor = UIColor.clearColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.clipsToBounds = NO;
    UITraitCollection *tc = cell.traitCollection ?: UITraitCollection.currentTraitCollection;
    BOOL isDark = (tc.userInterfaceStyle == UIUserInterfaceStyleDark);
    cell.layer.shadowColor = [PPPetsUIShadowColor() resolvedColorWithTraitCollection:tc].CGColor;
    cell.layer.shadowOpacity = isDark ? 0.25f : 0.05f;
    cell.layer.shadowRadius = isDark ? 8.0 : 12.0;
    cell.layer.shadowOffset = isDark ? CGSizeMake(0.0, 3.0) : CGSizeMake(0.0, 6.0);
    cell.layer.masksToBounds = NO;

    cell.contentView.backgroundColor = PPPetsUISurfaceColor();
    cell.contentView.layer.cornerRadius = cornerRadius;
    if (@available(iOS 13.0, *)) {
        cell.contentView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    cell.contentView.layer.borderWidth = 1.0;
    cell.contentView.layer.borderColor = [PPPetsUISurfaceBorderColor() resolvedColorWithTraitCollection:tc].CGColor;
    cell.contentView.layer.masksToBounds = YES;
}

// Call from traitCollectionDidChange: to refresh CALayer CGColor properties
static inline void PPPetsRefreshDynamicLayerColors(UITableView * _Nullable tableView) {
    if (!tableView) return;
    for (UITableViewCell *cell in tableView.visibleCells) {
        PPPetsApplySurfaceCellStyle(cell, cell.contentView.layer.cornerRadius);
    }
}

static inline UIView *PPPetsBuildSectionHeaderView(NSString * _Nullable title, NSString * _Nullable subtitle) {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = UIColor.clearColor;

    UIView *accentBar = [[UIView alloc] init];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = PPPetsUIBrandColor();
    accentBar.layer.cornerRadius = 2.0;
    [container addSubview:accentBar];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.text = title ?: @"";
    [container addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    subtitleLabel.textColor = PPPetsUISecondaryTextColor();
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.numberOfLines = 2;
    subtitleLabel.text = subtitle ?: @"";
    [container addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [accentBar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20.0],
        [accentBar.topAnchor constraintEqualToAnchor:container.topAnchor constant:14.0],
        [accentBar.widthAnchor constraintEqualToConstant:28.0],
        [accentBar.heightAnchor constraintEqualToConstant:4.0],

        [titleLabel.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:9.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:accentBar.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:container.bottomAnchor constant:-8.0],
    ]];

    return container;
}

static inline UIButton *PPPetsBuildHeroButton(NSString *title,
                                              NSString *systemImageName,
                                              BOOL filled) {
    UIColor *fg  = filled ? UIColor.whiteColor : PPPetsUIBrandColor();
    UIColor *bg  = filled ? PPPetsUIBrandColor() : [AppPrimaryClr colorWithAlphaComponent:0.80];

    UIButtonConfiguration *config = filled
        ? [UIButtonConfiguration filledButtonConfiguration]
        : [UIButtonConfiguration tintedButtonConfiguration];
    config.imagePlacement    = NSDirectionalRectEdgeTop;
    config.imagePadding      = 6.0;
    config.contentInsets     = NSDirectionalEdgeInsetsMake(10.0, 14.0, 10.0, 14.0);
    config.attributedTitle   = [[NSAttributedString alloc] initWithString:title ?: @""
                                                              attributes:@{
        NSFontAttributeName: [GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold],
        NSForegroundColorAttributeName: fg
    }];
    config.image             = [UIImage systemImageNamed:(systemImageName ?: @"plus")
                                       withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:22.0
                                                                                                        weight:UIImageSymbolWeightMedium]];
    config.baseForegroundColor = fg;
    config.baseBackgroundColor = bg;
    config.cornerStyle         = UIButtonConfigurationCornerStyleLarge;

    UIButton *button = [UIButton buttonWithConfiguration:config primaryAction:nil];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    if (!filled) {
        config.cornerStyle         = UIButtonConfigurationCornerStyleLarge;
        button.layer.borderWidth = 0.0;
        button.layer.borderColor = [PPPetsUIBrandColor() colorWithAlphaComponent:0.16].CGColor;
    }
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [NSLayoutConstraint activateConstraints:@[
        [button.heightAnchor constraintGreaterThanOrEqualToConstant:64.0],
    ]];
    return button;
}

// ─── Animated Floating Circles ────────────────────────────────
//
// Adds an organic, gently breathing layer of soft translucent circles
// that drift behind all content for a lively canvas. Call once to
// create, then start animations in viewDidAppear: so they restart
// after app-backgrounding or navigation transitions.

static inline NSArray<UIView *> *PPPetsBuildFloatingCircles(UIView *parentView) {
    NSMutableArray<UIView *> *result = [NSMutableArray array];
    CGFloat w = MAX(parentView.bounds.size.width, UIScreen.mainScreen.bounds.size.width);
    CGFloat h = MAX(parentView.bounds.size.height, UIScreen.mainScreen.bounds.size.height);

    BOOL isDark = (parentView.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    CGFloat alphaScale = isDark ? 0.35 : 1.0; // reduce circle prominence in dark mode

    struct { CGFloat rx, ry, d, r, g, b, a; } specs[] = {
        {0.14, 0.20,  56,  0.98, 0.84, 0.68, 0.07},   // warm peach
        {0.80, 0.30,  42,  0.80, 0.70, 0.93, 0.06},   // soft lavender
        {0.42, 0.52,  48,  0.68, 0.90, 0.80, 0.06},   // mint
        {0.86, 0.66,  36,  0.95, 0.72, 0.60, 0.05},   // coral
        {0.20, 0.76,  62,  0.96, 0.90, 0.65, 0.05},   // gold
    };

    NSInteger count = sizeof(specs) / sizeof(specs[0]);

    for (NSInteger i = 0; i < count; i++) {
        CGFloat diameter = specs[i].d;
        CGFloat radius   = diameter * 0.5;
        CGFloat x = specs[i].rx * w - radius;
        CGFloat y = specs[i].ry * h - radius;

        UIView *c = [[UIView alloc] initWithFrame:CGRectMake(x, y, diameter, diameter)];
        c.backgroundColor = [UIColor colorWithRed:specs[i].r
                                            green:specs[i].g
                                             blue:specs[i].b
                                            alpha:specs[i].a * alphaScale];
        c.layer.cornerRadius        = radius;
        c.userInteractionEnabled    = NO;
        c.alpha                     = specs[i].a * alphaScale;

        // Colored glow halo
        c.layer.shadowColor   = [UIColor colorWithRed:specs[i].r green:specs[i].g blue:specs[i].b alpha:1.0].CGColor;
        c.layer.shadowOpacity = (float)(specs[i].a * 2.5);
        c.layer.shadowRadius  = diameter * 0.45;
        c.layer.shadowOffset  = CGSizeZero;

        [parentView insertSubview:c atIndex:0];
        [result addObject:c];
    }

    return [result copy];
}

static inline void PPPetsBeginFloatingAnimations(UIView * _Nullable glowTop,
                                                 UIView * _Nullable glowBottom,
                                                 NSArray<UIView *> * _Nullable extraCircles) {

    UIViewAnimationOptions opts =
        UIViewAnimationOptionRepeat
      | UIViewAnimationOptionAutoreverse
    | UIViewAnimationOptionCurveEaseInOut
      | UIViewAnimationOptionAllowUserInteraction;

    // ── Animate existing large glow orbs (transform-only — they use Auto Layout) ──

    if (glowTop) {
        [glowTop.layer removeAllAnimations];
        glowTop.transform = CGAffineTransformIdentity;
        [UIView animateWithDuration:8.0 delay:0.0 options:opts animations:^{
            glowTop.transform = CGAffineTransformConcat(
                CGAffineTransformMakeScale(1.10, 1.10),
                CGAffineTransformMakeTranslation(16.0, 12.0));
        } completion:nil];
    }

    if (glowBottom) {
        [glowBottom.layer removeAllAnimations];
        glowBottom.transform = CGAffineTransformIdentity;
        [UIView animateWithDuration:10.5 delay:0.4 options:opts animations:^{
            glowBottom.transform = CGAffineTransformConcat(
                CGAffineTransformMakeScale(1.14, 1.14),
                CGAffineTransformMakeTranslation(-14.0, -10.0));
        } completion:nil];
    }

    // ── Animate small floating circles ──

    struct { NSTimeInterval dur; CGFloat dx, dy, sc, am; } anims[] = {
        { 7.0,   20,  16, 1.16, 1.7},
        {10.0,  -14,  20, 1.12, 1.6},
        { 8.5,   16, -18, 1.18, 1.8},
        { 9.5,  -18, -14, 1.10, 1.5},
        {11.0,   22, -12, 1.20, 1.7},
    };

    NSInteger animCount = sizeof(anims) / sizeof(anims[0]);

    for (NSInteger i = 0; i < (NSInteger)extraCircles.count && i < animCount; i++) {
        UIView *circle = extraCircles[i];
        [circle.layer removeAllAnimations];
        circle.transform = CGAffineTransformIdentity;

        CGFloat baseAlpha  = circle.alpha;
        CGFloat scale      = anims[i].sc;
        CGFloat translationX = anims[i].dx;
        CGFloat translationY = anims[i].dy;
        NSTimeInterval duration = anims[i].dur;
        CGFloat endAlpha   = baseAlpha * anims[i].am;

        [UIView animateWithDuration:duration
                              delay:0.3 + i * 0.5
                            options:opts
                         animations:^{
            circle.transform = CGAffineTransformConcat(
                CGAffineTransformMakeScale(scale, scale),
                CGAffineTransformMakeTranslation(translationX, translationY));
            circle.alpha = endAlpha;
        } completion:nil];
    }
}

NS_ASSUME_NONNULL_END
