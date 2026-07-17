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

@interface PPBackgroundView ()
@property (nonatomic, strong) PPHeroApexView *apexView;
@end

@implementation PPBackgroundView

@synthesize accentColorOverride = _accentColorOverride;
@synthesize overrideCenterGlowColor = _overrideCenterGlowColor;
@synthesize accentStyle = _accentStyle;
@synthesize cornerGlowOpacityMultiplier = _cornerGlowOpacityMultiplier;
@synthesize glowDirection = _glowDirection;
@synthesize PPHeroApexUseShimmer = _PPHeroApexUseShimmer;
@synthesize PPHeroApexUseUnderFingerMotion = _PPHeroApexUseUnderFingerMotion;

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
    _cornerGlowOpacityMultiplier = 1.0;
    _glowDirection = 0; // Default: systemDirection
    _PPHeroApexUseShimmer = NO;
    _PPHeroApexUseUnderFingerMotion = NO;

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

    CGFloat resolvedCornerRadius = self.layer.cornerRadius;
    if (resolvedCornerRadius <= 0.5) {
        resolvedCornerRadius = self.superview.layer.cornerRadius;
    }
    self.apexView.heroCornerRadius = resolvedCornerRadius > 0.5 ? resolvedCornerRadius : 30.0;
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

- (void)setAccentStyle:(PPHeroGlassAccentStyle)accentStyle
{
    if (_accentStyle == accentStyle) {
        return;
    }

    _accentStyle = accentStyle;
    self.apexView.accentStyle = accentStyle;
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
    [self.apexView reapplyPalette];
}

@end
