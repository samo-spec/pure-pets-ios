//
//  PPBackgroundViewApexBridge.m
//  Pure Pets
//
//  Objective-C compatibility adapter for the Swift PPHeroApexView. The
//  PPBackgroundView.h contract remains unchanged so existing
//  hero call sites keep their current ownership and layout behavior.
//

#import "PPBackgroundView.h"
#import <Pure_Pets-Swift.h>

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

@interface PPBackgroundView ()
@property (nonatomic, strong) PPHeroApexView *apexView;
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
    self.apexView.overrideCenterGlowColor = nil;
    self.apexView.overrideBottomGlowColor = nil;
    self.apexView.overrideTopGlowColor = nil;
    self.apexView.overrideSurfureColor = nil;
    self.apexView.overrideSurfaceColor = nil;
    _cornerGlowOpacityMultiplier = 1.0;
    _glowDirection = 0; // Default: systemDirection
    _PPHeroApexUseShimmer = NO;
    _PPHeroApexUseUnderFingerMotion = NO;

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
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.apexView.frame = self.bounds;

    CGFloat resolvedCornerRadius = self.overrideCornerRadius;
    if (resolvedCornerRadius <= 0.0) {
        resolvedCornerRadius = self.layer.cornerRadius;
    }
    if (resolvedCornerRadius <= 0.5) {
        resolvedCornerRadius = self.superview.layer.cornerRadius;
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
    if (_overrideSurfureColor == overrideSurfureColor ||
        [_overrideSurfureColor isEqual:overrideSurfureColor]) {
        return;
    }

    _overrideSurfureColor = overrideSurfureColor;
    self.apexView.overrideSurfureColor = overrideSurfureColor;
}

- (void)setOverrideSurfaceColor:(UIColor *)overrideSurfaceColor
{
    if (_overrideSurfaceColor == overrideSurfaceColor ||
        [_overrideSurfaceColor isEqual:overrideSurfaceColor]) {
        return;
    }

    _overrideSurfaceColor = overrideSurfaceColor;
    self.apexView.overrideSurfaceColor = overrideSurfaceColor;
}

- (void)setAccentStyle:(PPHeroGlassAccentStyle)accentStyle
{
    if (_accentStyle == accentStyle) {
        return;
    }

    _accentStyle = accentStyle;
    self.apexView.accentStyle = accentStyle;
    [self reapplyPalette];
    [self setNeedsLayout];
}

- (void)setCornerGlowOpacityMultiplier:(CGFloat)cornerGlowOpacityMultiplier
{
    CGFloat clamped = MIN(MAX(cornerGlowOpacityMultiplier, 0.0), 1.0);
    if (fabs(_cornerGlowOpacityMultiplier - clamped) < 0.001) {
        return;
    }

    _cornerGlowOpacityMultiplier = clamped;
    self.apexView.cornerGlowOpacityMultiplier = clamped;
}

- (void)setGlowDirection:(NSInteger)glowDirection
{
    if (_glowDirection == glowDirection) {
        return;
    }

    _glowDirection = glowDirection;
    self.apexView.glowDirection = (PPHeroGlowDirection)glowDirection;
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
    if (_overrideCornerRadius == overrideCornerRadius) {
        return;
    }
    _overrideCornerRadius = overrideCornerRadius;
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
    [self reapplyPalette];
}

- (void)setOverrideBorders:(BOOL)overrideBorders
{
    if (_overrideBorders == overrideBorders) {
        return;
    }
    _overrideBorders = overrideBorders;
    [self reapplyPalette];
}

- (void)setOverrideBorderColor:(UIColor *)overrideBorderColor
{
    if (_overrideBorderColor == overrideBorderColor || [_overrideBorderColor isEqual:overrideBorderColor]) {
        return;
    }
    _overrideBorderColor = overrideBorderColor;
    [self reapplyPalette];
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
                [self pp_setBorderColor:self.overrideBorderColor];
            } else {
                self.layer.borderWidth = 0.0;
                [self pp_setBorderColor:UIColor.clearColor];
            }
        } else {
            self.layer.borderWidth = 1.0;
            [self pp_setBorderColor:PPHeroGlassStrokeColor(darkMode)];
        }
        
        self.layer.shadowOpacity = 0.0f;
    } else {
        self.backgroundColor = UIColor.clearColor;
        self.layer.borderWidth = 0.0;
        [self pp_setBorderColor:UIColor.clearColor];
        
        [self.apexView reapplyPalette];
    }
}

#pragma mark - Trait Changes

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self reapplyPalette];
}

@end
