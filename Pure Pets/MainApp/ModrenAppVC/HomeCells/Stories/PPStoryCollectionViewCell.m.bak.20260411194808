//
//  PPStoryCollectionViewCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 2/22/26.
//

#import "PPStoryCollectionViewCell.h"
#import "Language.h"
#import "PPImageLoaderManager.h"
#import "GM.h"
#import "PPModernAvatarRenderer.h"

static const CGFloat PPStoryRingHostSize   = 78.0;
static const CGFloat PPStoryAvatarSize     = 64.0;
static const CGFloat PPStoryRingLineWidth  = 3.0;
static const CGFloat PPStoryTrackLineWidth = 2.0;
static const CGFloat PPStoryGlowRadius     = 10.0;
static NSString *const kRingRotationKey    = @"pp_ringRotation";

@interface PPStoryCollectionViewCell ()
@property (nonatomic, strong) CAShapeLayer *ringGradientMaskLayer;
@property (nonatomic, strong) UIView *glowView;
@property (nonatomic, strong) CAShapeLayer *dashedRingLayer;
@property (nonatomic, assign) BOOL isConfiguredUnseen;
@end

@implementation PPStoryCollectionViewCell

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.contentView.clipsToBounds = NO;

        // Glow view behind ring for unseen stories
        _glowView = [[UIView alloc] initWithFrame:CGRectZero];
        _glowView.translatesAutoresizingMaskIntoConstraints = NO;
        _glowView.backgroundColor = UIColor.clearColor;
        _glowView.layer.cornerRadius = PPStoryRingHostSize * 0.5;
        _glowView.alpha = 0.0;
        [self.contentView addSubview:_glowView];

        // Ring host container
        _ringHostView = [[UIView alloc] initWithFrame:CGRectZero];
        _ringHostView.translatesAutoresizingMaskIntoConstraints = NO;
        _ringHostView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.03];
        _ringHostView.layer.cornerRadius = PPStoryRingHostSize * 0.5;
        _ringHostView.layer.masksToBounds = NO;
        [self.contentView addSubview:_ringHostView];

        // Avatar
        _imageView = [[UIImageView alloc] init];
        _imageView.translatesAutoresizingMaskIntoConstraints = NO;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        _imageView.layer.cornerRadius = PPStoryAvatarSize * 0.5;
        _imageView.layer.borderWidth = 2.4;
        _imageView.layer.borderColor = UIColor.systemBackgroundColor.CGColor;
        [self.ringHostView addSubview:_imageView];

        // Name label
        _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.font = [GM MidFontWithSize:11.0];
        _nameLabel.textColor = UIColor.labelColor;
        _nameLabel.numberOfLines = 1;
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _nameLabel.textAlignment = NSTextAlignmentCenter;
        _nameLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        [self.contentView addSubview:_nameLabel];

        // Ring track (subtle background ring)
        _ringTrackLayer = [CAShapeLayer layer];
        _ringTrackLayer.fillColor = UIColor.clearColor.CGColor;
        _ringTrackLayer.lineWidth = PPStoryTrackLineWidth;
        _ringTrackLayer.strokeColor = [UIColor colorWithWhite:0.68 alpha:0.24].CGColor;
        _ringTrackLayer.lineCap = kCALineCapRound;
        [self.ringHostView.layer addSublayer:_ringTrackLayer];

        // Ring stroke (solid color fallback)
        _ringLayer = [CAShapeLayer layer];
        _ringLayer.fillColor = UIColor.clearColor.CGColor;
        _ringLayer.lineWidth = PPStoryRingLineWidth;
        _ringLayer.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.15].CGColor;
        _ringLayer.lineCap = kCALineCapRound;
        [self.ringHostView.layer addSublayer:_ringLayer];

        // Gradient ring overlay (masked to ring path)
        _ringGradientLayer = [CAGradientLayer layer];
        _ringGradientLayer.type = kCAGradientLayerConic;
        _ringGradientLayer.startPoint = CGPointMake(0.5, 0.5);
        _ringGradientLayer.endPoint = CGPointMake(0.5, 0.0);
        _ringGradientMaskLayer = [CAShapeLayer layer];
        _ringGradientMaskLayer.fillColor = UIColor.clearColor.CGColor;
        _ringGradientMaskLayer.lineWidth = PPStoryRingLineWidth;
        _ringGradientMaskLayer.lineCap = kCALineCapRound;
        _ringGradientMaskLayer.strokeColor = UIColor.blackColor.CGColor;
        _ringGradientLayer.mask = _ringGradientMaskLayer;
        [self.ringHostView.layer addSublayer:_ringGradientLayer];

        // Dashed ring for empty "Your Story"
        _dashedRingLayer = [CAShapeLayer layer];
        _dashedRingLayer.fillColor = UIColor.clearColor.CGColor;
        _dashedRingLayer.lineWidth = 2.0;
        _dashedRingLayer.lineDashPattern = @[@6, @4];
        _dashedRingLayer.lineCap = kCALineCapRound;
        _dashedRingLayer.hidden = YES;
        [self.ringHostView.layer addSublayer:_dashedRingLayer];

        // Add badge button
        _addBadgeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _addBadgeButton.translatesAutoresizingMaskIntoConstraints = NO;
        _addBadgeButton.hidden = YES;
        _addBadgeButton.backgroundColor = [self pp_appPrimaryColor];
        _addBadgeButton.layer.cornerRadius = 13.0;
        _addBadgeButton.layer.borderWidth = 2.6;
        _addBadgeButton.layer.borderColor = UIColor.systemBackgroundColor.CGColor;
        _addBadgeButton.layer.shadowColor = [self pp_appPrimaryColor].CGColor;
        _addBadgeButton.layer.shadowOpacity = 0.35;
        _addBadgeButton.layer.shadowOffset = CGSizeMake(0, 2.0);
        _addBadgeButton.layer.shadowRadius = 4.0;
        UIImageSymbolConfiguration *plusCfg =
            [UIImageSymbolConfiguration configurationWithPointSize:11.0 weight:UIImageSymbolWeightBold];
        UIImage *addIcon = [UIImage systemImageNamed:@"plus" withConfiguration:plusCfg];
        [_addBadgeButton setImage:addIcon forState:UIControlStateNormal];
        _addBadgeButton.tintColor = UIColor.whiteColor;
        [_addBadgeButton addTarget:self
                            action:@selector(pp_addBadgeTapped)
                  forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_addBadgeButton];

        [NSLayoutConstraint activateConstraints:@[
            [_glowView.centerXAnchor constraintEqualToAnchor:_ringHostView.centerXAnchor],
            [_glowView.centerYAnchor constraintEqualToAnchor:_ringHostView.centerYAnchor],
            [_glowView.widthAnchor constraintEqualToConstant:PPStoryRingHostSize + PPStoryGlowRadius * 2.0],
            [_glowView.heightAnchor constraintEqualToConstant:PPStoryRingHostSize + PPStoryGlowRadius * 2.0],

            [_ringHostView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:PPStoryGlowRadius * 0.5],
            [_ringHostView.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
            [_ringHostView.widthAnchor constraintEqualToConstant:PPStoryRingHostSize],
            [_ringHostView.heightAnchor constraintEqualToConstant:PPStoryRingHostSize],

            [_imageView.centerXAnchor constraintEqualToAnchor:_ringHostView.centerXAnchor],
            [_imageView.centerYAnchor constraintEqualToAnchor:_ringHostView.centerYAnchor],
            [_imageView.widthAnchor constraintEqualToConstant:PPStoryAvatarSize],
            [_imageView.heightAnchor constraintEqualToConstant:PPStoryAvatarSize],

            [_nameLabel.topAnchor constraintEqualToAnchor:_ringHostView.bottomAnchor constant:6.0],
            [_nameLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:2.0],
            [_nameLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-2.0],
            [_nameLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-2.0],

            [_addBadgeButton.widthAnchor constraintEqualToConstant:26.0],
            [_addBadgeButton.heightAnchor constraintEqualToConstant:26.0],
            [_addBadgeButton.trailingAnchor constraintEqualToAnchor:_ringHostView.trailingAnchor constant:2.0],
            [_addBadgeButton.bottomAnchor constraintEqualToAnchor:_ringHostView.bottomAnchor constant:2.0]
        ]];

        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitButton;
    }
    return self;
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    [self pp_updateRingPath];
}

#pragma mark - Reuse

- (void)prepareForReuse {
    [super prepareForReuse];
    self.imageView.image = [UIImage systemImageNamed:@"person.crop.circle.fill"];
    self.nameLabel.text = @"";
    self.accessibilityLabel = @"";
    self.onAddBadgeTapped = nil;
    self.addBadgeButton.hidden = YES;
    self.glowView.alpha = 0.0;
    self.dashedRingLayer.hidden = YES;
    self.isConfiguredUnseen = NO;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.ringLayer.strokeEnd = 1.0;
    self.ringTrackLayer.opacity = 1.0;
    self.ringGradientLayer.hidden = YES;
    [self.ringGradientLayer removeAnimationForKey:kRingRotationKey];
    [self.ringTrackLayer removeAllAnimations];
    [self.ringLayer removeAllAnimations];
    [self.ringGradientLayer removeAllAnimations];
    [CATransaction commit];

    self.contentView.transform = CGAffineTransformIdentity;
    self.contentView.alpha = 1.0;
}

#pragma mark - Configure

- (void)configureWithStory:(PPStory *)story {
    [self configureWithStory:story currentUserEntry:NO showAddBadge:NO];
}

- (void)configureWithStory:(PPStory *)story
          currentUserEntry:(BOOL)isCurrentUserEntry
              showAddBadge:(BOOL)showAddBadge
{
    NSString *name =
        [story.userName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (name.length == 0) {
        name = kLang(@"Unknown");
    }
    self.nameLabel.text = name;
    self.nameLabel.textAlignment = NSTextAlignmentCenter;
    self.nameLabel.font = isCurrentUserEntry ? [GM MidFontWithSize:11.5] : [GM MidFontWithSize:11.0];
    self.addBadgeButton.hidden = !showAddBadge;

    UIColor *primaryColor = [self pp_appPrimaryColor];
    UIColor *warmOrange   = [UIColor colorWithRed:0.99 green:0.55 blue:0.12 alpha:1.0];
    UIColor *hotPink      = [UIColor colorWithRed:0.93 green:0.12 blue:0.45 alpha:1.0];
    UIColor *deepMagenta  = [UIColor colorWithRed:0.72 green:0.08 blue:0.52 alpha:1.0];
    UIColor *lightPrimary = [self pp_adjustedColor:primaryColor saturation:0.85 brightness:1.12];

    BOOL isEmpty = (story.items.count == 0);
    BOOL showDashed = isCurrentUserEntry && isEmpty;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.dashedRingLayer.hidden = !showDashed;

    if (showDashed) {
        // Empty "Your Story" — dashed ring
        self.ringTrackLayer.opacity = 0.0;
        self.ringLayer.strokeColor = UIColor.clearColor.CGColor;
        self.ringGradientLayer.hidden = YES;
        self.dashedRingLayer.strokeColor = [UIColor colorWithWhite:0.55 alpha:0.40].CGColor;
        self.glowView.alpha = 0.0;
        self.isConfiguredUnseen = NO;
    } else if (story.isSeen) {
        // Seen — subtle muted ring
        self.ringTrackLayer.opacity = 1.0;
        self.ringTrackLayer.strokeColor = [UIColor colorWithWhite:0.62 alpha:0.24].CGColor;
        self.ringLayer.strokeColor = [UIColor colorWithWhite:0.58 alpha:0.60].CGColor;
        self.ringLayer.lineWidth = 2.4;
        self.ringGradientMaskLayer.lineWidth = 2.4;
        self.ringGradientLayer.hidden = YES;
        self.glowView.alpha = 0.0;
        self.isConfiguredUnseen = NO;
    } else {
        // Unseen — vivid conic gradient ring + glow
        self.ringTrackLayer.opacity = 1.0;
        self.ringTrackLayer.strokeColor = [UIColor colorWithWhite:0.65 alpha:0.18].CGColor;
        self.ringLayer.lineWidth = PPStoryRingLineWidth;
        self.ringGradientMaskLayer.lineWidth = PPStoryRingLineWidth;
        self.ringLayer.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;

        self.ringGradientLayer.colors = @[
            (__bridge id)warmOrange.CGColor,
            (__bridge id)hotPink.CGColor,
            (__bridge id)deepMagenta.CGColor,
            (__bridge id)lightPrimary.CGColor,
            (__bridge id)warmOrange.CGColor
        ];
        self.ringGradientLayer.hidden = NO;

        // Soft colored glow
        self.glowView.layer.shadowColor = hotPink.CGColor;
        self.glowView.layer.shadowOpacity = 0.35;
        self.glowView.layer.shadowRadius = PPStoryGlowRadius;
        self.glowView.layer.shadowOffset = CGSizeZero;
        self.glowView.alpha = 1.0;
        self.isConfiguredUnseen = YES;
    }
    [CATransaction commit];

    // Load avatar
    if (story.userImageURL) {
        [PPImageLoaderManager.shared setImageOnImageView:self.imageView
                                                     url:story.userImageURL.absoluteString
                                              placeholder:[PPModernAvatarRenderer avatarImageForName:story.userName size:PPStoryAvatarSize]
                                               complation:^(UIImage * _Nullable image, NSString * _Nullable urlString) {
        }];
    } else {
        self.imageView.image = [PPModernAvatarRenderer avatarImageForName:story.userName size:PPStoryAvatarSize];
    }

    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@",
                               name,
                               story.isSeen ? kLang(@"Read") : kLang(@"NewMessage")];
    [self pp_updateRingPath];

    // Start ring rotation for unseen stories
    if (self.isConfiguredUnseen) {
        [self pp_startRingRotation];
    }
}

#pragma mark - Ring Path

- (void)pp_updateRingPath {
    CGRect hostBounds = CGRectIntegral(self.ringHostView.bounds);
    if (CGRectEqualToRect(hostBounds, CGRectZero)) {
        return;
    }

    CGFloat inset = 2.4;
    CGRect ringRect = CGRectInset(hostBounds, inset, inset);
    UIBezierPath *ringPath = [UIBezierPath bezierPathWithOvalInRect:ringRect];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.ringTrackLayer.frame = hostBounds;
    self.ringTrackLayer.path = ringPath.CGPath;
    self.ringGradientLayer.frame = hostBounds;
    self.ringGradientMaskLayer.frame = hostBounds;
    self.ringGradientMaskLayer.path = ringPath.CGPath;
    self.ringLayer.frame = hostBounds;
    self.ringLayer.path = ringPath.CGPath;
    self.dashedRingLayer.frame = hostBounds;
    self.dashedRingLayer.path = ringPath.CGPath;
    [CATransaction commit];
}

#pragma mark - Ring Rotation (Unseen)

- (void)pp_startRingRotation {
    if ([self.ringGradientLayer animationForKey:kRingRotationKey]) {
        return;
    }
    CABasicAnimation *rot = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rot.fromValue = @0.0;
    rot.toValue = @(M_PI * 2.0);
    rot.duration = 4.0;
    rot.repeatCount = HUGE_VALF;
    rot.removedOnCompletion = NO;
    [self.ringGradientLayer addAnimation:rot forKey:kRingRotationKey];
}

#pragma mark - Entrance Animation

- (void)playEntranceAnimationWithDelay:(NSTimeInterval)delay {
    self.contentView.transform = CGAffineTransformMakeScale(0.0, 0.0);
    self.contentView.alpha = 0.0;

    [UIView animateWithDuration:0.5
                          delay:delay
         usingSpringWithDamping:0.72
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.contentView.transform = CGAffineTransformIdentity;
        self.contentView.alpha = 1.0;
    } completion:nil];
}

#pragma mark - Touch Feedback

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    [UIView animateWithDuration:0.15 delay:0.0
         usingSpringWithDamping:0.9 initialSpringVelocity:0.0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.contentView.transform = CGAffineTransformMakeScale(0.92, 0.92);
    } completion:nil];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    [UIView animateWithDuration:0.35 delay:0.0
         usingSpringWithDamping:0.6 initialSpringVelocity:0.0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.contentView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    [UIView animateWithDuration:0.3 delay:0.0
         usingSpringWithDamping:0.7 initialSpringVelocity:0.0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.contentView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - Add Badge

- (void)pp_addBadgeTapped {
    if (self.onAddBadgeTapped) {
        self.onAddBadgeTapped();
    }
}

#pragma mark - Color Helpers

- (UIColor *)pp_appPrimaryColor {
    UIColor *primary = [UIColor colorNamed:@"AppPrimaryClr"];
    if (!primary) {
        primary = [UIColor colorWithRed:0.93 green:0.08 blue:0.38 alpha:1.0];
    }
    return primary;
}

- (UIColor *)pp_adjustedColor:(UIColor *)baseColor
                   saturation:(CGFloat)saturationMultiplier
                   brightness:(CGFloat)brightnessMultiplier
{
    CGFloat h = 0.0, s = 0.0, b = 0.0, a = 0.0;
    if (![baseColor getHue:&h saturation:&s brightness:&b alpha:&a]) {
        return baseColor;
    }
    s = MIN(MAX(s * saturationMultiplier, 0.0), 1.0);
    b = MIN(MAX(b * brightnessMultiplier, 0.0), 1.0);
    return [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
}

@end
