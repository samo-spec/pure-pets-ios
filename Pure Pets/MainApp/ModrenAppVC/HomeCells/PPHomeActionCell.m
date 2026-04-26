//
//  PPHomeActionCell.m
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

static inline UIColor *PPQuickActionElevatedColor(UIColor *baseColor, CGFloat amount)
{
    return PPQuickActionBlendColors(baseColor, UIColor.whiteColor, amount);
}

static inline UIColor *PPQuickActionDeepenedColor(UIColor *baseColor, CGFloat amount)
{
    return PPQuickActionBlendColors(baseColor, UIColor.blackColor, amount);
}

@interface PPHomeActionCell ()

@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) CAGradientLayer *surfaceGradientLayer;
@property (nonatomic, strong) CAGradientLayer *surfaceSheenLayer;
@property (nonatomic, strong) UIView *accentBarView;
@property (nonatomic, strong) UIView *accentWashView;
@property (nonatomic, strong) CAGradientLayer *accentWashLayer;
@property (nonatomic, strong) UIView *iconOrbView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *chevronOrbView;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, copy) NSString *currentTitle;
@property (nonatomic, copy) NSString *currentIconName;
@property (nonatomic, strong) UIColor *currentAccentColor;

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

- (void)setupUI
{
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds = NO;

   
    
    
    self.actionButton = [UIButton new];
    self.actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionButton.backgroundColor = UIColor.clearColor;
    self.actionButton.adjustsImageWhenHighlighted = NO;
    self.actionButton.showsMenuAsPrimaryAction = NO;
    self.actionButton.tintColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    [self.actionButton addTarget:self action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
    [self.actionButton addTarget:self action:@selector(handleTouchDown) forControlEvents:UIControlEventTouchDown];
    [self.actionButton addTarget:self action:@selector(handleTouchUp) forControlEvents:UIControlEventTouchUpInside];
    [self.actionButton addTarget:self action:@selector(handleTouchUp) forControlEvents:UIControlEventTouchUpOutside];
    [self.actionButton addTarget:self action:@selector(handleTouchUp) forControlEvents:UIControlEventTouchCancel];
    [self.actionButton pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    self.actionButton.layer.shadowOpacity = 0.08f;
    self.actionButton.layer.shadowRadius = 22.0f;
    self.actionButton.layer.shadowOffset = CGSizeMake(0.0, 12.0);
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

    self.surfaceSheenLayer = [CAGradientLayer layer];
    self.surfaceSheenLayer.startPoint = CGPointMake(0.0, 0.5);
    self.surfaceSheenLayer.endPoint = CGPointMake(1.0, 0.5);
    [self.surfaceView.layer addSublayer:self.surfaceSheenLayer];

    self.accentWashView = [[UIView alloc] init];
    self.accentWashView.translatesAutoresizingMaskIntoConstraints = NO;
    self.accentWashView.userInteractionEnabled = NO;
    self.accentWashView.hidden = NO;
    self.accentWashView.layer.cornerRadius = 26.0;
    self.accentWashView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.accentWashView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.surfaceView addSubview:self.accentWashView];

    self.accentWashLayer = [CAGradientLayer layer];
    [self.accentWashView.layer insertSublayer:self.accentWashLayer atIndex:0];

    self.accentBarView = [[UIView alloc] init];
    self.accentBarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.accentBarView.userInteractionEnabled = NO;
    self.accentBarView.hidden = NO;
    self.accentBarView.layer.cornerRadius = 1.5;
    self.accentBarView.layer.masksToBounds = YES;
    [self.surfaceView addSubview:self.accentBarView];

    self.iconOrbView = [[UIView alloc] init];
    self.iconOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconOrbView.userInteractionEnabled = NO;
    self.iconOrbView.hidden = NO;
    self.iconOrbView.layer.cornerRadius = 20.0;
    self.iconOrbView.layer.masksToBounds = YES;
    self.iconOrbView.layer.borderWidth = 1.0;
    if (@available(iOS 13.0, *)) {
        self.iconOrbView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.surfaceView addSubview:self.iconOrbView];

    self.iconView = [[UIImageView alloc] init];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.hidden = NO;
    [self.iconOrbView addSubview:self.iconView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.hidden = NO;
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.titleLabel.font = [GM boldFontWithSize:15.5] ?: [UIFont systemFontOfSize:15.5 weight:UIFontWeightSemibold];
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.84;
    [self.surfaceView addSubview:self.titleLabel];

    UIImage *chevronImage =
        [UIImage pp_symbolNamed:(Language.isRTL ? @"arrow.left" : @"arrow.right")
                      pointSize:15
                         weight:UIImageSymbolWeightSemibold
                          scale:UIImageSymbolScaleMedium
                        palette:@[[AppPrimaryTextClr colorWithAlphaComponent:0.7] ?: UIColor.secondaryLabelColor]
                   makeTemplate:YES];

    self.chevronOrbView = [[UIView alloc] init];
    self.chevronOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    self.chevronOrbView.userInteractionEnabled = NO;
    self.chevronOrbView.hidden = NO;
    self.chevronOrbView.layer.cornerRadius = 16.0;
    self.chevronOrbView.layer.masksToBounds = YES;
    self.chevronOrbView.layer.borderWidth = 1.0;
    if (@available(iOS 13.0, *)) {
        self.chevronOrbView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.surfaceView addSubview:self.chevronOrbView];

    self.chevronView = [[UIImageView alloc] initWithImage:chevronImage];
    self.chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    self.chevronView.contentMode = UIViewContentModeScaleAspectFit;
    self.chevronView.hidden = NO;
    [self.chevronOrbView addSubview:self.chevronView];

    [self.titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                     forAxis:UILayoutConstraintAxisHorizontal];
    [self.iconOrbView setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                      forAxis:UILayoutConstraintAxisHorizontal];
    [self.chevronOrbView setContentCompressionResistancePriority:UILayoutPriorityRequired
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

        [self.accentWashView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:10.0],
        [self.accentWashView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.accentWashView.widthAnchor constraintEqualToConstant:126.0],
        [self.accentWashView.heightAnchor constraintEqualToConstant:52.0],

        [self.accentBarView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:12.0],
        [self.accentBarView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.accentBarView.widthAnchor constraintEqualToConstant:0.0],
        [self.accentBarView.heightAnchor constraintEqualToConstant:28.0],

        [self.iconOrbView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:14.0],
        [self.iconOrbView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.iconOrbView.widthAnchor constraintEqualToConstant:40.0],
        [self.iconOrbView.heightAnchor constraintEqualToConstant:40.0],

        [self.iconView.centerXAnchor constraintEqualToAnchor:self.iconOrbView.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:self.iconOrbView.centerYAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:19.0],
        [self.iconView.heightAnchor constraintEqualToConstant:19.0],

        [self.chevronOrbView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-10.0],
        [self.chevronOrbView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.chevronOrbView.widthAnchor constraintEqualToConstant:32.0],
        [self.chevronOrbView.heightAnchor constraintEqualToConstant:32.0],

        [self.chevronView.centerXAnchor constraintEqualToAnchor:self.chevronOrbView.centerXAnchor],
        [self.chevronView.centerYAnchor constraintEqualToAnchor:self.chevronOrbView.centerYAnchor],
        [self.chevronView.widthAnchor constraintEqualToConstant:12.0],
        [self.chevronView.heightAnchor constraintEqualToConstant:12.0],

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.iconOrbView.trailingAnchor constant:8.0],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.chevronOrbView.leadingAnchor constant:-6.0],
        [self.titleLabel.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor]
    ]];

    //[self pp_hideQuickActionChrome];
}

#pragma mark - Configure

- (void)configureWithTitle:(NSString *)title
                systemIcon:(NSString *)systemIconName
{
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

- (void)handleTap
{
    if (self.onTap) {
        self.onTap();
    }
}

- (void)handleTouchDown
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    [UIView animateWithDuration:0.14
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.actionButton.transform = CGAffineTransformMakeScale(0.988, 0.988);
        self.actionButton.alpha = 0.985;
        self.iconOrbView.transform = CGAffineTransformMakeScale(0.94, 0.94);
        self.chevronOrbView.transform = CGAffineTransformMakeScale(0.94, 0.94);
        self.surfaceView.transform = CGAffineTransformMakeTranslation(0.0, 1.0);
    } completion:nil];
}

- (void)handleTouchUp
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.actionButton.transform = CGAffineTransformIdentity;
        self.actionButton.alpha = 1.0;
        self.iconOrbView.transform = CGAffineTransformIdentity;
        self.chevronOrbView.transform = CGAffineTransformIdentity;
        self.surfaceView.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.2
                          delay:0.0
         usingSpringWithDamping:0.9
          initialSpringVelocity:0.16
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.actionButton.transform = CGAffineTransformIdentity;
        self.actionButton.alpha = 1.0;
        self.iconOrbView.transform = CGAffineTransformIdentity;
        self.chevronOrbView.transform = CGAffineTransformIdentity;
        self.surfaceView.transform = CGAffineTransformIdentity;
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
    if (self.currentTitle.length == 0) {
        return;
    }

    [self pp_applyQuickActionTitle:self.currentTitle
                          iconName:self.currentIconName
                            accent:self.currentAccentColor ?: [self pp_quickActionAccentColor]];
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
        [self.contentView layoutIfNeeded];
        surfaceBounds = self.surfaceView.bounds;
        if (CGRectIsEmpty(surfaceBounds)) {
            return;
        }
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.actionButton.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.actionButton.bounds cornerRadius:PPNewCorner].CGPath;
    self.surfaceGradientLayer.frame = surfaceBounds;
    self.surfaceSheenLayer.frame = surfaceBounds;
    self.accentWashLayer.frame = self.accentWashView.bounds;
    [CATransaction commit];
}

- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    [self setNeedsLayout];
    [self layoutIfNeeded];
    return layoutAttributes;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.onTap = nil;
    [self handleTouchUp];
    //[self pp_hideQuickActionChrome];
    self.actionButton.accessibilityLabel = nil;
}

- (void)setOnTap:(void (^)(void))onTap
{
    _onTap = [onTap copy];
}

- (void)pp_hideQuickActionChrome
{
    self.currentTitle = nil;
    self.currentIconName = nil;
    self.currentAccentColor = nil;

    self.accentWashView.hidden = YES;
    self.accentBarView.hidden = YES;
    self.iconOrbView.hidden = YES;
    self.iconView.hidden = YES;
    self.titleLabel.hidden = YES;
    self.chevronOrbView.hidden = YES;
    self.chevronView.hidden = YES;

    self.titleLabel.text = nil;
    self.titleLabel.attributedText = nil;
    self.iconView.image = nil;
    self.actionButton.alpha = 1.0;
    self.actionButton.transform = CGAffineTransformIdentity;
    self.iconOrbView.transform = CGAffineTransformIdentity;
    self.chevronOrbView.transform = CGAffineTransformIdentity;
    self.surfaceView.transform = CGAffineTransformIdentity;
}

- (UIColor *)pp_quickActionAccentColor
{
    return AppPrimaryClr ?: [UIColor colorWithRed:0.93 green:0.39 blue:0.55 alpha:1.0];
}

- (void)pp_applyQuickActionTitle:(NSString *)title
                        iconName:(NSString *)iconName
                          accent:(UIColor *)accent
{
    self.currentTitle = PPSafeString(title);
    self.currentIconName = PPSafeString(iconName);
    self.currentAccentColor = accent;

     self.accentWashView.hidden = NO;
    self.accentBarView.hidden = NO;
    self.iconOrbView.hidden = NO;
    self.iconView.hidden = NO;
    self.titleLabel.hidden = NO;
    self.chevronOrbView.hidden = NO;
    self.chevronView.hidden = NO;

    UIColor *resolvedAccent = accent ?: [self pp_quickActionAccentColor];
    UIColor *surfaceBase = [AppBageColor() colorWithAlphaComponent:0.98] ?: UIColor.secondarySystemBackgroundColor;
    UIColor *primaryText = AppPrimaryTextClr ?: UIColor.labelColor;
    UIColor *secondaryText = [primaryText colorWithAlphaComponent:0.54];
    UIColor *upperSurface = PPQuickActionElevatedColor(surfaceBase, 0.06);
    UIColor *lowerSurface = PPQuickActionBlendColors(surfaceBase, resolvedAccent, 0.05);
    UIColor *borderColor = [PPQuickActionElevatedColor(AppForgroundColr, 0.18) colorWithAlphaComponent:0.58];
    UIColor *orbSurface = PPQuickActionBlendColors(surfaceBase, resolvedAccent, 0.10);
    UIColor *orbBorder = [resolvedAccent colorWithAlphaComponent:0.18];
    UIColor *chevronSurface = [primaryText colorWithAlphaComponent:0.05];
    UIColor *chevronBorder = [primaryText colorWithAlphaComponent:0.08];

    [self.surfaceView pp_setBorderColor:borderColor];
    self.surfaceGradientLayer.colors = @[
        (__bridge id)[upperSurface colorWithAlphaComponent:1.0].CGColor,
        (__bridge id)[surfaceBase colorWithAlphaComponent:1.0].CGColor,
        (__bridge id)[lowerSurface colorWithAlphaComponent:1.0].CGColor
    ];
    self.surfaceGradientLayer.locations = @[@0.0, @0.46, @1.0];

    self.surfaceSheenLayer.colors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.18].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.04].CGColor,
        (__bridge id)[UIColor.clearColor CGColor]
    ];
    self.surfaceSheenLayer.locations = @[@0.0, @0.12, @0.38];

    self.accentWashLayer.startPoint = Language.isRTL ? CGPointMake(1.0, 0.5) : CGPointMake(0.0, 0.5);
    self.accentWashLayer.endPoint = Language.isRTL ? CGPointMake(0.0, 0.5) : CGPointMake(1.0, 0.5);
    self.accentWashLayer.colors = @[
        (__bridge id)[resolvedAccent colorWithAlphaComponent:0.14].CGColor,
        (__bridge id)[resolvedAccent colorWithAlphaComponent:0.05].CGColor,
        (__bridge id)[UIColor.clearColor CGColor]
    ];
    self.accentWashLayer.locations = @[@0.0, @0.55, @1.0];

    self.accentBarView.backgroundColor = resolvedAccent;
    self.iconOrbView.backgroundColor = orbSurface;
    [self.iconOrbView pp_setBorderColor:[orbBorder colorWithAlphaComponent:0.07]];
    self.chevronOrbView.backgroundColor = [orbSurface colorWithAlphaComponent:0.3];
    [self.chevronOrbView pp_setBorderColor:AppClearClr];

    NSDictionary *attributes = @{
        NSFontAttributeName: self.titleLabel.font,
        NSKernAttributeName: @0.18,
        NSForegroundColorAttributeName: primaryText
    };
    self.titleLabel.attributedText = [[NSAttributedString alloc] initWithString:self.currentTitle attributes:attributes];
    self.titleLabel.textColor = primaryText;

    self.chevronView.tintColor = secondaryText;
    self.iconView.tintColor = resolvedAccent;
    self.iconView.image =
        [UIImage pp_symbolNamed:(self.currentIconName.length > 0 ? self.currentIconName : @"sparkles")
                      pointSize:19
                         weight:UIImageSymbolWeightSemibold
                          scale:UIImageSymbolScaleMedium
                        palette:@[resolvedAccent, PPQuickActionDeepenedColor(resolvedAccent, 0.12)]
                   makeTemplate:YES];

    [self setNeedsUpdateConstraints];
    [self setNeedsLayout];
    [self.contentView setNeedsLayout];
    [self layoutIfNeeded];
}

@end
