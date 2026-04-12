//
//  PPHomeCartNavButton.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/5/26.
//

#import "PPHomeCartNavButton.h"
@implementation PPHomeCartNavButton {
    UIView *_surfaceView;
    UIImageView *_iconView;
    PPInsetLabel *_badgeLabel;
    NSLayoutConstraint *_badgeMinWidthConstraint;
    CAGradientLayer *_highlightLayer;
    NSInteger _renderedCount;
}

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(36.0, 36.0);
}

- (instancetype)initWithFrame:(CGRect)frame
{
    CGRect initialFrame = CGRectEqualToRect(frame, CGRectZero)
        ? CGRectMake(0.0, 0.0, 36.0, 36.0)
        : frame;
    self = [super initWithFrame:initialFrame];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    self.accessibilityLabel = kLang(@"Cart") ?: @"Cart";

    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = 0.08f;
    self.layer.shadowRadius = 10.0f;
    self.layer.shadowOffset = CGSizeMake(0.0, 4.0);

    UIView *surfaceView = [[UIView alloc] initWithFrame:self.bounds];
    surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    surfaceView.userInteractionEnabled = NO;
    surfaceView.layer.cornerRadius = 18.0;
    surfaceView.layer.borderWidth = 0.8;
    surfaceView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self addSubview:surfaceView];
    _surfaceView = surfaceView;

    [NSLayoutConstraint activateConstraints:@[
        [surfaceView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [surfaceView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [surfaceView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [surfaceView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];

    _highlightLayer = [CAGradientLayer layer];
    _highlightLayer.startPoint = CGPointMake(0.5, 0.0);
    _highlightLayer.endPoint = CGPointMake(0.5, 1.0);
    [surfaceView.layer insertSublayer:_highlightLayer atIndex:0];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:
        [UIImage pp_symbolNamed:@"cart.fill"
                      pointSize:18
                         weight:UIImageSymbolWeightSemibold
                          scale:UIImageSymbolScaleMedium
                        palette:@[AppPrimaryTextClr ?: UIColor.labelColor]
                   makeTemplate:YES]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [surfaceView addSubview:iconView];
    _iconView = iconView;

    [NSLayoutConstraint activateConstraints:@[
        [iconView.centerXAnchor constraintEqualToAnchor:surfaceView.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:surfaceView.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:18.0],
        [iconView.heightAnchor constraintEqualToConstant:18.0]
    ]];

    PPInsetLabel *badgeLabel = [[PPInsetLabel alloc] init];
    badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    badgeLabel.textInsets = UIEdgeInsetsMake(1.5, 5.0, 1.5, 5.0);
    badgeLabel.textAlignment = NSTextAlignmentCenter;
    badgeLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
    badgeLabel.textColor = UIColor.whiteColor;
    badgeLabel.backgroundColor = UIColor.systemRedColor;
    badgeLabel.adjustsFontSizeToFitWidth = YES;
    badgeLabel.minimumScaleFactor = 0.82;
    badgeLabel.layer.cornerRadius = 8.5;
    badgeLabel.layer.borderWidth = 1.0;
    badgeLabel.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.92].CGColor;
    badgeLabel.layer.masksToBounds = YES;
    badgeLabel.hidden = YES;
    badgeLabel.alpha = 0.0;
    badgeLabel.userInteractionEnabled = NO;
    if (@available(iOS 13.0, *)) {
        badgeLabel.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [surfaceView addSubview:badgeLabel];
    _badgeLabel = badgeLabel;

    _badgeMinWidthConstraint = [badgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:17.0];
    _badgeMinWidthConstraint.active = YES;
    [NSLayoutConstraint activateConstraints:@[
        [badgeLabel.heightAnchor constraintEqualToConstant:17.0],
        [badgeLabel.bottomAnchor constraintEqualToAnchor:surfaceView.bottomAnchor constant:3.0], // Positioned "bellow"
        [badgeLabel.centerXAnchor constraintEqualToAnchor:surfaceView.centerXAnchor] // Centered below icon
    ]];

    [self pp_applyPalette];
    return self;
}

- (void)setIconName:(NSString *)iconName {
    _iconView.image = [UIImage pp_symbolNamed:iconName
                                    pointSize:18
                                       weight:UIImageSymbolWeightSemibold
                                        scale:UIImageSymbolScaleMedium
                                      palette:@[AppPrimaryTextClr ?: UIColor.labelColor]
                                 makeTemplate:YES];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _highlightLayer.frame = _surfaceView.bounds;
    self.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:CGRectGetWidth(self.bounds) * 0.5].CGPath;
}

- (void)tintColorDidChange
{
    [super tintColorDidChange];
    [self pp_applyPalette];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applyPalette];
        }
    } else {
        [self pp_applyPalette];
    }
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:highlighted ? 0.12 : 0.18
                          delay:0.0
         usingSpringWithDamping:highlighted ? 1.0 : 0.72
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.transform = highlighted ? CGAffineTransformMakeScale(0.94, 0.94) : CGAffineTransformIdentity;
        self.alpha = highlighted ? 0.92 : 1.0;
    } completion:nil];
}

- (void)updateCount:(NSInteger)count animated:(BOOL)animated
{
    NSInteger safeCount = MAX(count, 0);
    BOOL shouldShowBadge = safeCount > 0;
    NSString *text = (safeCount > 99) ? @"99+" : [NSString stringWithFormat:@"%ld", (long)safeCount];
    BOOL valueChanged = ![_badgeLabel.text isEqualToString:text];
    BOOL wasHidden = _badgeLabel.hidden;

    _renderedCount = safeCount;
    _badgeLabel.text = text;
    CGFloat textWidth = ceil([text sizeWithAttributes:@{NSFontAttributeName : _badgeLabel.font}].width) + 8.0;
    _badgeMinWidthConstraint.constant = MAX(17.0, textWidth);
    _badgeLabel.hidden = !shouldShowBadge;
    _badgeLabel.alpha = shouldShowBadge ? 1.0 : 0.0;
    self.accessibilityValue = shouldShowBadge ? text : nil;

    [self setNeedsLayout];
    [self layoutIfNeeded];

    if (shouldShowBadge && animated && (wasHidden || valueChanged)) {
        _badgeLabel.transform = CGAffineTransformMakeScale(0.82, 0.82);
        [UIView animateWithDuration:0.22
                              delay:0.0
             usingSpringWithDamping:0.72
              initialSpringVelocity:0.18
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self->_badgeLabel.transform = CGAffineTransformIdentity;
        } completion:nil];
    } else if (!shouldShowBadge) {
        _badgeLabel.transform = CGAffineTransformIdentity;
    }
}

- (void)pp_applyPalette
{
    UIColor *surfaceColor = [AppForgroundColr colorWithAlphaComponent:0.66] ?: [UIColor colorWithWhite:0.95 alpha:1.0];
    UIColor *iconColor = AppPrimaryTextClr ?: UIColor.labelColor;
    _surfaceView.backgroundColor = surfaceColor;
    _surfaceView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.14].CGColor;
    _iconView.tintColor = iconColor;
    _highlightLayer.colors = @[
        (__bridge id)[[UIColor whiteColor] colorWithAlphaComponent:0.34].CGColor,
        (__bridge id)[[UIColor whiteColor] colorWithAlphaComponent:0.08].CGColor,
        (__bridge id)[UIColor.clearColor CGColor]
    ];
}

@end
