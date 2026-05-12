//
//  PPDesignTokens.h
//  Pure Pets
//
//  Design System Tokens — Apple HIG-aligned
//  Centralized spacing, typography, corners, and shadow presets.
//  Import via PrefixHeader.pch for global availability.
//

#ifndef PPDesignTokens_h
#define PPDesignTokens_h

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Spacing (8pt Grid)

#define PPSpaceXXS   2.0f
#define PPSpaceXS    4.0f
#define PPSpaceSM    8.0f
#define PPSpaceMD    12.0f
#define PPSpaceMDHalf    6.0f
#define PPSpaceBase  16.0f
#define PPSpaceLG    20.0f
#define PPSpaceXL    24.0f
#define PPSpaceXXL   32.0f
#define PPSpaceXXXL  40.0f
#define PPSpace4XL   48.0f

#define PPScreenMargin 20.0f

#pragma mark - Corner Radii

#define PPCornerSmall    12.0f
#define PPCornerMedium   18.0f
#define PPCornerCard     22.0f
#define PPCornerHero     36.0f
#define PPCornerLarge    42.0f
#define PPCornerPill     9999.0f

#pragma mark - Typography Scale (Beiruti via GM helpers)
// GM.boldFontWithSize: adds +1pt internally, so subtract 1 from target.
// Target sizes follow Apple HIG type scale.

#define PPFontLargeTitle   33.0f   // → 34pt (screen titles)
#define PPFontTitle1       27.0f   // → 28pt (major sections)
#define PPFontTitle2       21.0f   // → 22pt (card titles, hero)
#define PPFontTitle3       18.0f   // → 20pt (sub-sections)
#define PPFontHeadline     16.0f   // → 17pt (list row primary)
#define PPFontBody         16.0f   // → 17pt (body text)
#define PPFontCallout      15.0f   // → 16pt (supporting body)
#define PPFontSubheadline  14.0f   // → 15pt (secondary info)
#define PPFontFootnote     12.0f   // → 13pt (captions, meta)
#define PPFontCaption1     11.0f   // → 12pt (badges, timestamps)
#define PPFontCaption2     10.0f   // → 11pt (legal, micro)

#pragma mark - Touch Targets (Apple HIG)

#define PPTouchTargetMin   44.0f
#define PPButtonHeightLG   52.0f
#define PPButtonHeightMD   48.0f
#define PPButtonHeightSM   44.0f
#define PPButtonHeightXS   36.0f

#pragma mark - Shadow Presets

// Card shadow: soft elevation
#define PPShadowCardRadius     24.0f
#define PPShadowCardOffsetY    8.0f
#define PPShadowCardOpacity    0.06f

// Elevated shadow: prominent cards
#define PPShadowElevatedRadius   24.0f
#define PPShadowElevatedOffsetY  14.0f
#define PPShadowElevatedOpacity  0.12f

// Button shadow
#define PPShadowButtonRadius   12.0f
#define PPShadowButtonOffsetY  6.0f
#define PPShadowButtonOpacity  0.15f

// Subtle shadow: icons, chips
#define PPShadowSubtleRadius   8.0f
#define PPShadowSubtleOffsetY  2.0f
#define PPShadowSubtleOpacity  0.04f

#pragma mark - Animation Constants

#define PPAnimDurationFast     0.12
#define PPAnimDurationNormal   0.25
#define PPAnimDurationSlow     0.4
#define PPAnimSpringDamping    0.75
#define PPAnimSpringVelocity   0.8

// Tap feedback scale values
#define PPTapScaleDown         0.96
#define PPTapCardScaleDown     0.98

#pragma mark - Semantic Color Macros

#define AppTertiaryTextClr     [UIColor colorNamed:@"TertiaryTextColor"]
#define AppPlaceholderTextClr  [UIColor colorNamed:@"PlaceholderTextColor"]
#define AppSuccessClr          [UIColor colorNamed:@"SuccessColor"]
#define AppWarningClr          [UIColor colorNamed:@"WarningColor"]
#define AppErrorClr            [UIColor colorNamed:@"ErrorColor"]
#define AppInfoClr             [UIColor colorNamed:@"InfoColor"]

#pragma mark - Gradient Tokens

// Hero gradient: brand warmth (3-stop)
#define PPGradientHeroStart    AppPrimaryClr
#define PPGradientHeroMid      AppPrimaryClrShiner
#define PPGradientHeroEnd      [UIColor hx_colorWithHexStr:@"#FF6B8A"]

// Card gradient: subtle blush
#define PPGradientCardStart    [UIColor whiteColor]
#define PPGradientCardEnd      [UIColor hx_colorWithHexStr:@"#FFF5F7"]

// Overlay gradient: text readability on images
#define PPGradientOverlayStart [[UIColor blackColor] colorWithAlphaComponent:0.0]
#define PPGradientOverlayEnd   [[UIColor blackColor] colorWithAlphaComponent:0.65]

#pragma mark - Convenience Helpers

static inline CALayer *PPLayerForDesignTokenTarget(id target) {
    if ([target isKindOfClass:[UIView class]]) {
        return ((UIView *)target).layer;
    }
    if ([target isKindOfClass:[CALayer class]]) {
        return (CALayer *)target;
    }
    return nil;
}

/// Apply card shadow to a view or layer
static inline void PPApplyCardShadow(id target) {
    CALayer *layer = PPLayerForDesignTokenTarget(target);
    if (!layer) { return; }
    layer.shadowColor = [UIColor blackColor].CGColor;
    layer.shadowOpacity = PPShadowCardOpacity;
    layer.shadowRadius = PPShadowCardRadius;
    layer.shadowOffset = CGSizeMake(0, PPShadowCardOffsetY);
}

/// Apply elevated shadow to a view or layer
static inline void PPApplyElevatedShadow(id target) {
    CALayer *layer = PPLayerForDesignTokenTarget(target);
    if (!layer) { return; }
    layer.shadowColor = [UIColor blackColor].CGColor;
    layer.shadowOpacity = PPShadowElevatedOpacity;
    layer.shadowRadius = PPShadowElevatedRadius;
    layer.shadowOffset = CGSizeMake(0, PPShadowElevatedOffsetY);
}

/// Apply button shadow to a view or layer
static inline void PPApplyButtonShadow(id target) {
    CALayer *layer = PPLayerForDesignTokenTarget(target);
    if (!layer) { return; }
    layer.shadowColor = [UIColor blackColor].CGColor;
    layer.shadowOpacity = PPShadowButtonOpacity;
    layer.shadowRadius = PPShadowButtonRadius;
    layer.shadowOffset = CGSizeMake(0, PPShadowButtonOffsetY);
}

/// Apply continuous corner curve (iOS 13+)
static inline void PPApplyContinuousCorners(id target, CGFloat radius) {
    CALayer *layer = PPLayerForDesignTokenTarget(target);
    if (!layer) { return; }
    layer.cornerRadius = radius;
    if (@available(iOS 13.0, *)) {
        layer.cornerCurve = kCACornerCurveContinuous;
    }
}

/// Tap feedback: scale down with spring
static inline void PPTapFeedbackDown(UIView *view) {
    [UIView animateWithDuration:PPAnimDurationFast
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        view.transform = CGAffineTransformMakeScale(PPTapScaleDown, PPTapScaleDown);
    } completion:nil];
}

/// Tap feedback: spring back
static inline void PPTapFeedbackUp(UIView *view) {
    [UIView animateWithDuration:PPAnimDurationNormal
                          delay:0
         usingSpringWithDamping:PPAnimSpringDamping
          initialSpringVelocity:PPAnimSpringVelocity
                        options:0
                     animations:^{
        view.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#endif /* PPDesignTokens_h */
