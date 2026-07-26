//
//  PPBackgroundViewApexBridge.m
//  Pure Pets
//
//  Objective-C compatibility adapter for the Swift PPHeroApexView. The
//  PPBackgroundView.h contract remains unchanged so existing
//  hero call sites keep their current ownership and layout behavior.
//

#import "PPBackgroundView.h"

#if PP_HERO_APEX_ENABLED

#import <Pure_Pets-Swift.h>
#import <math.h>

static BOOL PPHeroGlassIsDark(UITraitCollection *traitCollection)
{
    if (@available(iOS 13.0, *)) {
        return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

static UIColor *PPHeroGlassStrokeColor(BOOL darkMode)
{
    return [UIColor.whiteColor colorWithAlphaComponent:darkMode ? 0.12 : 0.78];
}

static CGFloat PPHeroGlassFiniteNonnegative(CGFloat value)
{
    return isfinite(value) ? MAX(value, 0.0) : 0.0;
}

static PPHeroGlassAccentStyle PPHeroGlassResolvedAccentStyle(NSInteger rawValue)
{
    switch (rawValue) {
        case PPHeroGlassAccentStyleBar:
        case PPHeroGlassAccentStyleCornerGlow:
        case PPHeroGlassAccentStyleFullScreen:
        case PPHeroGlassAccentStyleSolid:
        case PPHeroGlassAccentStyleFullScreenPink:
        case PPHeroGlassAccentStyleFullScreenPage:
        case PPHeroGlassAccentStyleBBBaseBackground:
            return (PPHeroGlassAccentStyle)rawValue;
        default:
            return PPHeroGlassAccentStyleBar;
    }
}

static PPHeroGlowDirection PPHeroGlassResolvedGlowDirection(NSInteger rawValue)
{
    switch (rawValue) {
        case 0:
        case 1:
        case 2:
            return (PPHeroGlowDirection)rawValue;
        default:
            return (PPHeroGlowDirection)0;
    }
}

@interface PPBackgroundView ()
@property (nonatomic, strong) PPHeroApexView *apexView;
- (void)pp_applyContainerPaletteReapplyingApex:(BOOL)reapplyApex;
- (void)pp_setResolvedBorderColor:(UIColor *)color;
@end

@implementation PPBackgroundView

@synthesize accentColorOverride = _accentColorOverride;
@synthesize overrideCenterGlowColor = _overrideCenterGlowColor;
@synthesize overrideBottomGlowColor = _overrideBottomGlowColor;
@synthesize overrideTopGlowColor = _overrideTopGlowColor;
@synthesize overrideSurfureColor = _overrideSurfureColor;
@synthesize overrideSurfaceColor = _overrideSurfaceColor;
@synthesize accentStyle = _accentStyle;
@synthesize cornerGlowOpacityMultiplier = _cornerGlowOpacityMultiplier;
@synthesize glowDirection = _glowDirection;
@synthesize PPHeroApexUseShimmer = _PPHeroApexUseShimmer;
@synthesize PPHeroApexUseUnderFingerMotion = _PPHeroApexUseUnderFingerMotion;

@synthesize overrideCornerRadius = _overrideCornerRadius;
@synthesize overrideCornerRaduis = _overrideCornerRaduis;
@synthesize overrideSolidColor = _overrideSolidColor;
@synthesize overrideBorders = _overrideBorders;
@synthesize overrideBorderColor = _overrideBorderColor;

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self pp_installApexImplementation];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self pp_installApexImplementation];
    }
    return self;
}

- (void)pp_installApexImplementation
{
    self.userInteractionEnabled = NO;
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;

    _accentStyle = PPHeroGlassAccentStyleBar;
    _cornerGlowOpacityMultiplier = 1.0;
    _glowDirection = 0; // Default: systemDirection
    // Apex defaults: optical sweep and passive under-finger response are on.
    // Both remain externally switchable through the existing Objective-C API.
    _PPHeroApexUseShimmer = YES;
    _PPHeroApexUseUnderFingerMotion = YES;

    _overrideCornerRadius = 0.0;
    _overrideCornerRaduis = 0.0;
    _overrideSolidColor = nil;
    _overrideBorders = NO;
    _overrideBorderColor = nil;

    PPHeroApexView *apexView = [[PPHeroApexView alloc] initWithFrame:self.bounds];
    apexView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    apexView.accentStyle = _accentStyle;
    apexView.cornerGlowOpacityMultiplier = _cornerGlowOpacityMultiplier;
    apexView.glowDirection = _glowDirection;
    apexView.PPHeroApexUseShimmer = _PPHeroApexUseShimmer;
    apexView.PPHeroApexUseUnderFingerMotion = _PPHeroApexUseUnderFingerMotion;
    [self addSubview:apexView];
    self.apexView = apexView;
    [self pp_applyContainerPaletteReapplyingApex:NO];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.apexView.frame = self.bounds;

    CGFloat resolvedCornerRadius = PPHeroGlassFiniteNonnegative(self.overrideCornerRadius);
    if (resolvedCornerRadius <= 0.0) {
        resolvedCornerRadius = PPHeroGlassFiniteNonnegative(self.layer.cornerRadius);
    }
    if (resolvedCornerRadius <= 0.5) {
        resolvedCornerRadius = PPHeroGlassFiniteNonnegative(self.superview.layer.cornerRadius);
    }
    if (resolvedCornerRadius <= 0.5) {
        resolvedCornerRadius = 30.0;
    }

    self.layer.cornerRadius = resolvedCornerRadius;
    if (@available(iOS 13.0, *)) {
        self.layer.cornerCurve = kCACornerCurveContinuous;
    }

    self.apexView.heroCornerRadius = resolvedCornerRadius;
}

- (void)setAccentColorOverride:(UIColor *)accentColorOverride
{
    if (_accentColorOverride == accentColorOverride ||
        [_accentColorOverride isEqual:accentColorOverride]) {
        return;
    }

    _accentColorOverride = accentColorOverride;
    self.apexView.accentColorOverride = accentColorOverride;
}

- (void)setOverrideCenterGlowColor:(UIColor *)overrideCenterGlowColor
{
    if (_overrideCenterGlowColor == overrideCenterGlowColor ||
        [_overrideCenterGlowColor isEqual:overrideCenterGlowColor]) {
        return;
    }

    _overrideCenterGlowColor = overrideCenterGlowColor;
    self.apexView.overrideCenterGlowColor = overrideCenterGlowColor;
}

- (void)setOverrideBottomGlowColor:(UIColor *)overrideBottomGlowColor
{
    if (_overrideBottomGlowColor == overrideBottomGlowColor ||
        [_overrideBottomGlowColor isEqual:overrideBottomGlowColor]) {
        return;
    }

    _overrideBottomGlowColor = overrideBottomGlowColor;
    self.apexView.overrideBottomGlowColor = overrideBottomGlowColor;
}

- (void)setOverrideTopGlowColor:(UIColor *)overrideTopGlowColor
{
    if (_overrideTopGlowColor == overrideTopGlowColor ||
        [_overrideTopGlowColor isEqual:overrideTopGlowColor]) {
        return;
    }

    _overrideTopGlowColor = overrideTopGlowColor;
    self.apexView.overrideTopGlowColor = overrideTopGlowColor;
}

- (void)setOverrideSurfureColor:(UIColor *)overrideSurfureColor
{
    [self setOverrideSurfaceColor:overrideSurfureColor];
}

- (UIColor *)overrideSurfureColor
{
    return self.overrideSurfaceColor;
}

- (void)setOverrideSurfaceColor:(UIColor *)overrideSurfaceColor
{
    if (_overrideSurfaceColor == overrideSurfaceColor ||
        [_overrideSurfaceColor isEqual:overrideSurfaceColor]) {
        return;
    }

    _overrideSurfaceColor = overrideSurfaceColor;
    _overrideSurfureColor = overrideSurfaceColor;
    self.apexView.overrideSurfaceColor = overrideSurfaceColor;
}

- (void)setAccentStyle:(PPHeroGlassAccentStyle)accentStyle
{
    PPHeroGlassAccentStyle resolvedStyle = PPHeroGlassResolvedAccentStyle(accentStyle);
    if (_accentStyle == resolvedStyle) {
        return;
    }

    _accentStyle = resolvedStyle;
    self.apexView.accentStyle = resolvedStyle;
    [self pp_applyContainerPaletteReapplyingApex:NO];
    [self setNeedsLayout];
}

- (void)setCornerGlowOpacityMultiplier:(CGFloat)cornerGlowOpacityMultiplier
{
    if (!isfinite(cornerGlowOpacityMultiplier)) {
        return;
    }
    CGFloat clamped = MIN(MAX(cornerGlowOpacityMultiplier, 0.0), 1.0);
    if (fabs(_cornerGlowOpacityMultiplier - clamped) < 0.001) {
        return;
    }

    _cornerGlowOpacityMultiplier = clamped;
    self.apexView.cornerGlowOpacityMultiplier = clamped;
}

- (void)setGlowDirection:(NSInteger)glowDirection
{
    PPHeroGlowDirection resolvedDirection = PPHeroGlassResolvedGlowDirection(glowDirection);
    if (_glowDirection == resolvedDirection) {
        return;
    }

    _glowDirection = resolvedDirection;
    self.apexView.glowDirection = resolvedDirection;
}

- (void)setPPHeroApexUseShimmer:(BOOL)PPHeroApexUseShimmer
{
    if (_PPHeroApexUseShimmer == PPHeroApexUseShimmer) {
        return;
    }

    _PPHeroApexUseShimmer = PPHeroApexUseShimmer;
    self.apexView.PPHeroApexUseShimmer = PPHeroApexUseShimmer;
}

- (void)setPPHeroApexUseUnderFingerMotion:(BOOL)PPHeroApexUseUnderFingerMotion
{
    if (_PPHeroApexUseUnderFingerMotion == PPHeroApexUseUnderFingerMotion) {
        return;
    }

    _PPHeroApexUseUnderFingerMotion = PPHeroApexUseUnderFingerMotion;
    self.apexView.PPHeroApexUseUnderFingerMotion = PPHeroApexUseUnderFingerMotion;
}

- (void)setOverrideCornerRadius:(CGFloat)overrideCornerRadius
{
    CGFloat resolvedRadius = PPHeroGlassFiniteNonnegative(overrideCornerRadius);
    if (fabs(_overrideCornerRadius - resolvedRadius) < 0.001) {
        return;
    }
    _overrideCornerRadius = resolvedRadius;
    [self setNeedsLayout];
}

- (void)setOverrideCornerRaduis:(CGFloat)overrideCornerRaduis
{
    self.overrideCornerRadius = overrideCornerRaduis;
}

- (CGFloat)overrideCornerRaduis
{
    return self.overrideCornerRadius;
}

- (void)setOverrideSolidColor:(UIColor *)overrideSolidColor
{
    if (_overrideSolidColor == overrideSolidColor || [_overrideSolidColor isEqual:overrideSolidColor]) {
        return;
    }
    _overrideSolidColor = overrideSolidColor;
    [self pp_applyContainerPaletteReapplyingApex:NO];
}

- (void)setOverrideBorders:(BOOL)overrideBorders
{
    if (_overrideBorders == overrideBorders) {
        return;
    }
    _overrideBorders = overrideBorders;
    [self pp_applyContainerPaletteReapplyingApex:NO];
}

- (void)setOverrideBorderColor:(UIColor *)overrideBorderColor
{
    if (_overrideBorderColor == overrideBorderColor || [_overrideBorderColor isEqual:overrideBorderColor]) {
        return;
    }
    _overrideBorderColor = overrideBorderColor;
    [self pp_applyContainerPaletteReapplyingApex:NO];
}

- (void)startAnimations
{
    [self.apexView startAnimations];
}

- (void)stopAnimations
{
    [self.apexView stopAnimations];
}

- (void)reapplyPalette
{
    [self pp_applyContainerPaletteReapplyingApex:YES];
}

- (void)pp_applyContainerPaletteReapplyingApex:(BOOL)reapplyApex
{
    BOOL isSolid = (self.accentStyle == PPHeroGlassAccentStyleSolid);
    self.apexView.hidden = isSolid;
    self.clipsToBounds = isSolid;

    if (isSolid) {
        UIColor *bgColor = self.overrideSolidColor ?: (AppBackgroundClr ?: [UIColor systemBackgroundColor]);
        self.backgroundColor = bgColor;
        
        BOOL darkMode = PPHeroGlassIsDark(self.traitCollection);
        if (self.overrideBorders) {
            if (self.overrideBorderColor) {
                self.layer.borderWidth = 1.0;
                [self pp_setResolvedBorderColor:self.overrideBorderColor];
            } else {
                self.layer.borderWidth = 0.0;
                [self pp_setResolvedBorderColor:UIColor.clearColor];
            }
        } else {
            self.layer.borderWidth = 1.0;
            [self pp_setResolvedBorderColor:PPHeroGlassStrokeColor(darkMode)];
        }
        
        self.layer.shadowOpacity = 0.0f;
    } else {
        self.backgroundColor = UIColor.clearColor;
        self.layer.borderWidth = 0.0;
        [self pp_setResolvedBorderColor:UIColor.clearColor];
    }

    if (reapplyApex) {
        [self.apexView reapplyPalette];
    }
}

- (void)pp_setResolvedBorderColor:(UIColor *)color
{
    UIColor *resolvedColor = color;
    if (@available(iOS 13.0, *)) {
        resolvedColor = [color resolvedColorWithTraitCollection:self.traitCollection];
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.layer.borderColor = resolvedColor.CGColor;
    [CATransaction commit];
}

#pragma mark - Trait Changes

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self pp_applyContainerPaletteReapplyingApex:NO];
}

@end

#endif // PP_HERO_APEX_ENABLED
