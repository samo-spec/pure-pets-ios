//
//  PPHomeActionCell 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 26/12/2025.
//


#import "PPHomeActionCell.h"
#import "PPHomeModels.h"

static inline UIColor *PPQuickActionBlendColors(UIColor *a, UIColor *b, CGFloat t)
{
    if (!a) return b;
    if (!b) return a;

    t = MAX(0.0, MIN(1.0, t));

    CGFloat ar = 0.0, ag = 0.0, ab = 0.0, aa = 0.0;
    CGFloat br = 0.0, bg = 0.0, bb = 0.0, ba = 0.0;
    [a getRed:&ar green:&ag blue:&ab alpha:&aa];
    [b getRed:&br green:&bg blue:&bb alpha:&ba];

    return [UIColor colorWithRed:(ar + (br - ar) * t)
                           green:(ag + (bg - ag) * t)
                            blue:(ab + (bb - ab) * t)
                           alpha:(aa + (ba - aa) * t)];
}

@interface PPHomeActionCell ()

@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) CAGradientLayer *surfaceGradientLayer;
@property (nonatomic, strong) CAGradientLayer *surfaceShineLayer;
@property (nonatomic, strong) UIView *glowView;
@property (nonatomic, strong) CAGradientLayer *glowGradientLayer;
@property (nonatomic, strong) UIView *iconChipView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIImageView *chevronView;
@end

@implementation PPHomeActionCell

+ (NSString *)reuseIdentifier {
    return @"PPHomeActionCell";
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupUI];
    }
    return self;
}

#pragma mark - UI

- (void)setupUI {

    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds = NO;

    self.actionButton = [UIButton new];
    self.actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.actionButton addTarget:self
                          action:@selector(handleTap)
                forControlEvents:UIControlEventTouchUpInside];
    [self.actionButton addTarget:self
                          action:@selector(handleTouchDown)
                forControlEvents:UIControlEventTouchDown];
    [self.actionButton addTarget:self
                          action:@selector(handleTouchUp)
                forControlEvents:UIControlEventTouchUpInside];
    [self.actionButton addTarget:self
                          action:@selector(handleTouchUp)
                forControlEvents:UIControlEventTouchUpOutside];
    [self.actionButton addTarget:self
                          action:@selector(handleTouchUp)
                forControlEvents:UIControlEventTouchCancel];
    self.actionButton.tintColor = AppPrimaryClr;
    self.actionButton.showsMenuAsPrimaryAction = NO;
    self.actionButton.backgroundColor = UIColor.clearColor;
    [self.actionButton pp_setShadowColor:UIColor.blackColor];
    self.actionButton.layer.shadowOpacity = 0.08f;
    self.actionButton.layer.shadowRadius = 18.0f;
    self.actionButton.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    self.actionButton.adjustsImageWhenHighlighted = NO;
    if (@available(iOS 13.0, *)) {
        self.actionButton.layer.cornerCurve = kCACornerCurveContinuous;
    }

    [self.contentView addSubview:self.actionButton];

    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.surfaceView.userInteractionEnabled = NO;
    self.surfaceView.layer.cornerRadius = PPNewCorner;
    self.surfaceView.layer.masksToBounds = YES;
    self.surfaceView.layer.borderWidth = 1.0;
    if (@available(iOS 13.0, *)) {
        self.surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.actionButton addSubview:self.surfaceView];

    self.surfaceGradientLayer = [CAGradientLayer layer];
    self.surfaceGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.surfaceGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    [self.surfaceView.layer insertSublayer:self.surfaceGradientLayer atIndex:0];

    self.surfaceShineLayer = [CAGradientLayer layer];
    self.surfaceShineLayer.startPoint = CGPointMake(0.5, 0.0);
    self.surfaceShineLayer.endPoint = CGPointMake(0.5, 1.0);
    [self.surfaceView.layer addSublayer:self.surfaceShineLayer];

    self.glowView = [[UIView alloc] init];
    self.glowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.glowView.userInteractionEnabled = NO;
    self.glowView.hidden = YES;
    self.glowView.layer.cornerRadius = 22;
    self.glowView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.glowView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.surfaceView addSubview:self.glowView];

    self.glowGradientLayer = [CAGradientLayer layer];
    [self.glowView.layer insertSublayer:self.glowGradientLayer atIndex:0];

    self.iconChipView = [[UIView alloc] init];
    self.iconChipView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconChipView.userInteractionEnabled = NO;
    self.iconChipView.hidden = YES;
    self.iconChipView.layer.cornerRadius = PPCornerMedium;
    self.iconChipView.layer.masksToBounds = YES;
    self.iconChipView.layer.borderWidth = 0.0;
    if (@available(iOS 13.0, *)) {
        self.iconChipView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.surfaceView addSubview:self.iconChipView];

    self.iconView = [[UIImageView alloc] init];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.hidden = YES;
    [self.iconChipView addSubview:self.iconView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.hidden = YES;
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.titleLabel.font = [GM boldFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = AppPrimaryTextClr;
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.88;
    [self.surfaceView addSubview:self.titleLabel];

    UIImage *chevronImage =
        [UIImage pp_symbolNamed:(Language.isRTL ? @"chevron.left" : @"chevron.right")
                      pointSize:14
                         weight:UIImageSymbolWeightBold
                          scale:UIImageSymbolScaleMedium
                        palette:@[[AppPrimaryTextClr colorWithAlphaComponent:0.72] ?: UIColor.secondaryLabelColor]
                   makeTemplate:YES];
    
    self.chevronView = [[UIImageView alloc] initWithImage:chevronImage];
    self.chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    self.chevronView.contentMode = UIViewContentModeScaleAspectFit;
    self.chevronView.hidden = YES;
    [self.surfaceView addSubview:self.chevronView];

    [self.titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                     forAxis:UILayoutConstraintAxisHorizontal];
    [self.chevronView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                      forAxis:UILayoutConstraintAxisHorizontal];
    [self.iconChipView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                       forAxis:UILayoutConstraintAxisHorizontal];

    [NSLayoutConstraint activateConstraints:@[
        [self.actionButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.actionButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.actionButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.actionButton.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        [self.actionButton.heightAnchor constraintGreaterThanOrEqualToConstant:64.0],

        [self.surfaceView.topAnchor constraintEqualToAnchor:self.actionButton.topAnchor],
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.actionButton.leadingAnchor],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.actionButton.trailingAnchor],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.actionButton.bottomAnchor],

        [self.glowView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:10.0],
        [self.glowView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.glowView.widthAnchor constraintEqualToConstant:102.0],
        [self.glowView.heightAnchor constraintEqualToConstant:44.0],

        [self.iconChipView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:12.0],
        [self.iconChipView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.iconChipView.widthAnchor constraintEqualToConstant:36.0],
        [self.iconChipView.heightAnchor constraintEqualToConstant:36.0],

        [self.iconView.centerXAnchor constraintEqualToAnchor:self.iconChipView.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:self.iconChipView.centerYAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:18.0],
        [self.iconView.heightAnchor constraintEqualToConstant:18.0],

        [self.chevronView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-13.0],
        [self.chevronView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.chevronView.widthAnchor constraintEqualToConstant:12.0],
        [self.chevronView.heightAnchor constraintEqualToConstant:12.0],

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.iconChipView.trailingAnchor constant:12.0],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.chevronView.leadingAnchor constant:-8.0],
        [self.titleLabel.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor]
    ]];

    [self pp_hideQuickActionChrome];
}

#pragma mark - Configure

- (void)configureWithTitle:(NSString *)title
                systemIcon:(NSString *)systemIconName {
    [self pp_applyQuickActionTitle:title
                          iconName:systemIconName
                            accent:[self pp_quickActionAccentColor]];
    self.actionButton.accessibilityLabel = PPSafeString(title);
}

- (void)configureWithQuickAction:(PPHomeQuickActionModel *)quickAction
{
    [self pp_applyQuickActionTitle:PPSafeString(quickAction.title)
                          iconName:PPSafeString(quickAction.iconName)
                            accent:[self pp_quickActionAccentColor]];
    self.actionButton.accessibilityLabel = PPSafeString(quickAction.title);
}

- (void)handleTap {
    if (self.onTap) {
        self.onTap();
    }
}

- (void)handleTouchDown
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    [UIView animateWithDuration:0.12
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.actionButton.transform = CGAffineTransformMakeScale(0.985, 0.985);
        self.actionButton.alpha = 0.98;
        self.iconChipView.transform = CGAffineTransformMakeScale(0.96, 0.96);
        CGFloat x = Language.isRTL ? -2.0 : 2.0;
        self.chevronView.transform = CGAffineTransformMakeTranslation(x, 0.0);
    } completion:nil];
}

- (void)handleTouchUp
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.actionButton.transform = CGAffineTransformIdentity;
        self.actionButton.alpha = 1.0;
        self.iconChipView.transform = CGAffineTransformIdentity;
        self.chevronView.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.18
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.actionButton.transform = CGAffineTransformIdentity;
        self.actionButton.alpha = 1.0;
        self.iconChipView.transform = CGAffineTransformIdentity;
        self.chevronView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_refreshThemeColors];
        }
    }
}

- (void)pp_refreshThemeColors
{
    // Re-apply the current configuration to refresh CALayer colors
    if (self.titleLabel.text.length > 0) {
        [self pp_applyQuickActionTitle:self.titleLabel.text
                              iconName:self.iconView.image.accessibilityIdentifier ?: @""
                                accent:[self pp_quickActionAccentColor]];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self pp_updateLayerFrames];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
        // Orthogonal scrolling sections may skip the initial layout pass for
        // CALayer frames.  Schedule a deferred update so gradient layers render
        // correctly the first time the cell appears on-screen.
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_updateLayerFrames];
        });
    }
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    [super applyLayoutAttributes:layoutAttributes];
    [self setNeedsLayout];
    [self.contentView setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    [self pp_updateLayerFrames];
}

- (void)pp_updateLayerFrames
{
    CGRect surfaceBounds = self.surfaceView.bounds;
    if (CGRectIsEmpty(surfaceBounds)) {
        // Force Auto Layout to resolve now so we get valid bounds.
        [self.contentView layoutIfNeeded];
        surfaceBounds = self.surfaceView.bounds;
        if (CGRectIsEmpty(surfaceBounds)) return;
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.actionButton.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.actionButton.bounds cornerRadius:PPNewCorner].CGPath;
    self.surfaceGradientLayer.frame = surfaceBounds;
    self.surfaceShineLayer.frame = surfaceBounds;
    self.glowGradientLayer.frame = self.glowView.bounds;
    [CATransaction commit];
}

- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    [self setNeedsLayout];
    [self layoutIfNeeded];
    return layoutAttributes;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.onTap = nil;
    [self handleTouchUp];
    [self pp_hideQuickActionChrome];
    self.actionButton.accessibilityLabel = nil;
}

- (void)setOnTap:(void (^)(void))onTap {
    _onTap = [onTap copy];
}

- (void)pp_hideQuickActionChrome
{
    self.glowView.hidden = YES;
    self.iconChipView.hidden = YES;
    self.iconView.hidden = YES;
    self.titleLabel.hidden = YES;
    self.chevronView.hidden = YES;
    self.titleLabel.text = nil;
    self.iconView.image = nil;
    self.actionButton.alpha = 1.0;
    self.actionButton.transform = CGAffineTransformIdentity;
    self.iconChipView.transform = CGAffineTransformIdentity;
    self.chevronView.transform = CGAffineTransformIdentity;
}

- (UIColor *)pp_quickActionAccentColor
{
    return AppPrimaryClr ?: [UIColor colorWithRed:0.93 green:0.39 blue:0.55 alpha:1.0];
}

- (void)pp_applyQuickActionTitle:(NSString *)title
                        iconName:(NSString *)iconName
                          accent:(UIColor *)accent
{
    self.actionButton.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.glowView.hidden = NO;
    self.iconChipView.hidden = NO;
    self.iconView.hidden = NO;
    self.titleLabel.hidden = NO;
    self.chevronView.hidden = NO;

    UIColor *resolvedAccent = accent ?: [self pp_quickActionAccentColor];
    UIColor *surfaceColor = [AppForgroundColr colorWithAlphaComponent:0.96] ?: [UIColor secondarySystemBackgroundColor];
    UIColor *textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    UIColor *secondaryColor = [textColor colorWithAlphaComponent:0.72];
    UIColor *warmHighlight = [AppForgroundColr colorWithAlphaComponent:0.82];
    UIColor *tintedSurfaceColor = PPQuickActionBlendColors(surfaceColor, resolvedAccent, 0.08);

    [self.surfaceView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.14]];
    self.surfaceGradientLayer.colors = @[
        (__bridge id)[warmHighlight colorWithAlphaComponent:0.34].CGColor,
        (__bridge id)[surfaceColor colorWithAlphaComponent:0.98].CGColor,
        (__bridge id)tintedSurfaceColor.CGColor
    ];
    self.surfaceGradientLayer.locations = @[@0.0, @0.42, @1.0];

    self.surfaceShineLayer.colors = @[
        (__bridge id)[warmHighlight colorWithAlphaComponent:0.22].CGColor,
        (__bridge id)[warmHighlight colorWithAlphaComponent:0.05].CGColor,
        (__bridge id)[UIColor.clearColor CGColor]
    ];
    self.surfaceShineLayer.locations = @[@0.0, @0.28, @0.82];

    self.glowGradientLayer.startPoint = Language.isRTL ? CGPointMake(1.0, 0.5) : CGPointMake(0.0, 0.5);
    self.glowGradientLayer.endPoint = Language.isRTL ? CGPointMake(0.0, 0.5) : CGPointMake(1.0, 0.5);
    self.glowGradientLayer.colors = @[
        (__bridge id)[resolvedAccent colorWithAlphaComponent:0.14].CGColor,
        (__bridge id)[resolvedAccent colorWithAlphaComponent:0.05].CGColor,
        (__bridge id)[UIColor.clearColor CGColor]
    ];
    self.glowGradientLayer.locations = @[@0.0, @0.55, @1.0];

    self.iconChipView.backgroundColor = [resolvedAccent colorWithAlphaComponent:0.13];
    [self.iconChipView pp_setBorderColor:[resolvedAccent colorWithAlphaComponent:0.18]];
    self.titleLabel.text = PPSafeString(title);
    self.titleLabel.textColor = textColor;
    self.chevronView.tintColor = secondaryColor;
    self.iconView.tintColor = resolvedAccent;
    self.iconView.image =
        [UIImage pp_symbolNamed:PPSafeString(iconName)
                      pointSize:19
                         weight:UIImageSymbolWeightSemibold
                          scale:UIImageSymbolScaleMedium
                        palette:@[resolvedAccent]
                   makeTemplate:YES];

    [self setNeedsUpdateConstraints];
    [self setNeedsLayout];
    [self.contentView setNeedsLayout];
    [self layoutIfNeeded];
}

@end
