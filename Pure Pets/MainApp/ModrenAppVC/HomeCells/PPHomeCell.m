#import "PPHomeCell.h"
#import "MainKindsModel.h"
#import "PPColorUtils.h"

@interface PPHomeCell ()

@property (nonatomic, strong) NSLayoutConstraint *iconSizeConstraint;
@property (nonatomic, strong) NSLayoutConstraint *iconCenterYConstraint;
@property (nonatomic, strong) UIView *titleShadowContainer;
@property (nonatomic, strong) UIView *titleBackground;
@property (nonatomic, strong) UIView *iconBackdropView;
@property (nonatomic, strong) UIView *topGlowView;
@property (nonatomic, strong) UIView *bottomGlowView;
@property (nonatomic, copy) NSArray<UIColor *> *activeGradientColors;
@property (nonatomic, strong) UIColor *activeAccentColor;

@end

@implementation PPHomeCell

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self buildUI];
    }
    return self;
}

#pragma mark - UI

- (void)buildUI
{
    self.contentView.backgroundColor = AppClearClr;
    self.layer.masksToBounds = NO;

    self.glassButton = [self setButtonAsBackroundButton];
    self.glassButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.glassButton.layer.cornerRadius = PPNewCorner;
    self.glassButton.clipsToBounds = YES;
    self.glassButton.layer.borderWidth = 0.8;
    [self.glassButton addTarget:self
                         action:@selector(handleTap)
               forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.glassButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.glassButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.glassButton.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        [self.glassButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.glassButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
    ]];

    self.topGlowView = [[UIView alloc] init];
    self.topGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.topGlowView.userInteractionEnabled = NO;
    self.topGlowView.alpha =1.0;
    [self.glassButton addSubview:self.topGlowView];

    self.bottomGlowView = [[UIView alloc] init];
    self.bottomGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomGlowView.userInteractionEnabled = NO;
    self.bottomGlowView.alpha = 1.0;
    [self.glassButton addSubview:self.bottomGlowView];

    self.iconBackdropView = [[UIView alloc] init];
    self.iconBackdropView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconBackdropView.userInteractionEnabled = NO;
    self.iconBackdropView.layer.borderWidth = 1.0;
    [self.glassButton addSubview:self.iconBackdropView];

    self.iconView = [[UIImageView alloc] init];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.tintColor = UIColor.labelColor;
    [self.iconBackdropView addSubview:self.iconView];

    self.iconSizeConstraint =
        [self.iconView.heightAnchor constraintEqualToConstant:44];
    self.iconCenterYConstraint =
        [self.iconBackdropView.centerYAnchor constraintEqualToAnchor:self.glassButton.centerYAnchor
                                                            constant:-18];

    [NSLayoutConstraint activateConstraints:@[
        [self.topGlowView.widthAnchor constraintEqualToConstant:76],
        [self.topGlowView.heightAnchor constraintEqualToConstant:76],
        [self.topGlowView.topAnchor constraintEqualToAnchor:self.glassButton.topAnchor constant:-18],
        [self.topGlowView.trailingAnchor constraintEqualToAnchor:self.glassButton.trailingAnchor constant:18],

        [self.bottomGlowView.widthAnchor constraintEqualToConstant:70],
        [self.bottomGlowView.heightAnchor constraintEqualToConstant:70],
        [self.bottomGlowView.bottomAnchor constraintEqualToAnchor:self.glassButton.bottomAnchor constant:46],
        [self.bottomGlowView.leadingAnchor constraintEqualToAnchor:self.glassButton.leadingAnchor constant:-46],

        [self.iconBackdropView.centerXAnchor constraintEqualToAnchor:self.glassButton.centerXAnchor],
        self.iconCenterYConstraint,
        [self.iconBackdropView.widthAnchor constraintEqualToConstant:56],
        [self.iconBackdropView.heightAnchor constraintEqualToConstant:56],

        [self.iconView.centerXAnchor constraintEqualToAnchor:self.iconBackdropView.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:self.iconBackdropView.centerYAnchor],
        self.iconSizeConstraint,
        [self.iconView.widthAnchor constraintEqualToAnchor:self.iconView.heightAnchor],
    ]];

    self.titleShadowContainer = [[UIView alloc] init];
    self.titleShadowContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleShadowContainer.userInteractionEnabled = NO;
    self.titleShadowContainer.layer.cornerRadius = PPCornerSmall;
    [self.titleShadowContainer pp_setShadowColor:UIColor.blackColor];
    self.titleShadowContainer.layer.shadowOpacity = 0.08;
    self.titleShadowContainer.layer.shadowRadius = 8.0;
    self.titleShadowContainer.layer.shadowOffset = CGSizeMake(0, 4.0);
    [self.glassButton addSubview:self.titleShadowContainer];

    self.titleBackground = [[UIView alloc] init];
    self.titleBackground.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleBackground.userInteractionEnabled = NO;
    self.titleBackground.layer.cornerRadius = PPCornerSmall;
    [self.titleShadowContainer addSubview:self.titleBackground];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.userInteractionEnabled = NO;
    self.titleLabel.font = [GM boldFontWithSize:PPFontCallout];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.textColor = UIColor.labelColor;
    self.titleLabel.numberOfLines = 1;
    [self.titleBackground addSubview:self.titleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.titleShadowContainer.leadingAnchor constraintEqualToAnchor:self.glassButton.leadingAnchor constant:8],
        [self.titleShadowContainer.trailingAnchor constraintEqualToAnchor:self.glassButton.trailingAnchor constant:-8],
        [self.titleShadowContainer.bottomAnchor constraintEqualToAnchor:self.glassButton.bottomAnchor constant:-8],
        [self.titleShadowContainer.heightAnchor constraintEqualToConstant:32],

        [self.titleBackground.topAnchor constraintEqualToAnchor:self.titleShadowContainer.topAnchor],
        [self.titleBackground.bottomAnchor constraintEqualToAnchor:self.titleShadowContainer.bottomAnchor],
        [self.titleBackground.leadingAnchor constraintEqualToAnchor:self.titleShadowContainer.leadingAnchor],
        [self.titleBackground.trailingAnchor constraintEqualToAnchor:self.titleShadowContainer.trailingAnchor],

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.titleBackground.leadingAnchor constant:10],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.titleBackground.trailingAnchor constant:-10],
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.titleBackground.topAnchor],
        [self.titleLabel.bottomAnchor constraintEqualToAnchor:self.titleBackground.bottomAnchor],
    ]];

    [self pp_setShadowColor:UIColor.blackColor];
    self.layer.shadowOpacity = 0.07;
    self.layer.shadowRadius = 12.0;
    self.layer.shadowOffset = CGSizeMake(0, 7.0);
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    // Disable implicit CALayer animations so frame updates are instant
    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    self.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                   cornerRadius:PPNewCorner].CGPath;
    self.topGlowView.layer.cornerRadius = CGRectGetHeight(self.topGlowView.bounds) * 0.5;
    self.bottomGlowView.layer.cornerRadius = CGRectGetHeight(self.bottomGlowView.bounds) * 0.5;
    self.iconBackdropView.layer.cornerRadius = 28;

    // Explicitly resize gradient layer to match glassButton bounds
    for (CALayer *l in self.glassButton.layer.sublayers) {
        if ([l.name isEqualToString:@"PPGradientLayer"]) {
            l.frame = self.glassButton.bounds;
            break;
        }
    }
   
    [self setBackgroundGradientFrom:self.activeGradientColors[0]
                                    middleColor:self.activeGradientColors[1]
                                              to:self.activeGradientColors[2]
                                           angle:self.isAll ? 140.0 : 132.0
                                     cornerRadius:PPNewCorner];
    [self pp_applyGradientIfNeeded];

    [CATransaction commit];
}

#pragma mark - Window attachment fallback

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window && self.activeGradientColors.count >= 3) {
        // Cell is now in a window — force final layout + gradient refresh
        // in case configureWithMainKind: ran before the cell had a window.
        [self layoutIfNeeded];
        [self pp_applyGradientIfNeeded];
    }
}

#pragma mark - Reuse

- (void)prepareForReuse
{
    [super prepareForReuse];

    self.model = nil;
    self.isAll = NO;
    self.isKindSelected = NO;
    self.activeGradientColors = nil;
    self.activeAccentColor = nil;

    self.iconView.image = nil;
    self.titleLabel.text = nil;
    self.titleShadowContainer.hidden = NO;

    self.iconSizeConstraint.constant = 40;
    self.iconCenterYConstraint.constant = -18;

    self.iconView.tintColor = UIColor.labelColor;
    self.titleLabel.textColor = UIColor.labelColor;
    self.iconBackdropView.backgroundColor = UIColor.clearColor;
    [self.iconBackdropView pp_setBorderColor:UIColor.clearColor];
    self.titleBackground.backgroundColor = UIColor.clearColor;
    self.topGlowView.alpha = 0.0;
    self.bottomGlowView.alpha = 0.0;

    UIButtonConfiguration *config = self.glassButton.configuration;
    config.background.strokeWidth = 0.0;
    config.background.strokeColor = UIColor.clearColor;
    config.background.backgroundColor = UIColor.clearColor;
    config.baseBackgroundColor = UIColor.clearColor;
    self.glassButton.configuration = config;
    self.glassButton.backgroundColor = UIColor.clearColor;
    self.glassButton.layer.borderWidth = 0.8;
    [self.glassButton pp_setBorderColor:UIColor.clearColor];

    self.transform = CGAffineTransformIdentity;
    self.iconBackdropView.transform = CGAffineTransformIdentity;
    self.titleBackground.alpha = 1.0;
    self.layer.shadowOpacity = PPShadowElevatedOpacity;
    self.layer.shadowRadius = PPShadowElevatedRadius;
    self.layer.shadowOffset = CGSizeMake(0, PPShadowElevatedOffsetY);
}

#pragma mark - Configure

- (void)configureWithMainKind:(MainKindsModel *)kind
                        isAll:(BOOL)isAll
                     selected:(BOOL)selected
{
    self.model = kind;
    self.isAll = isAll;
    self.isKindSelected = selected;

    UIButtonConfiguration *config = self.glassButton.configuration;
    config.background.strokeWidth = 0.0;
    config.background.strokeColor = UIColor.clearColor;
    config.background.backgroundColor = UIColor.whiteColor;
    config.baseBackgroundColor = UIColor.whiteColor;
    self.glassButton.configuration = config;

    if (isAll) {
        UIColor *contentColor = [UIColor hx_colorWithHexStr:@"#243145"];
        self.iconView.image = [[UIImage systemImageNamed:@"rectangle.grid.2x2.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.titleLabel.text = kLang(@"all");
        self.titleShadowContainer.hidden = YES;
        self.iconSizeConstraint.constant = 24;
        self.iconCenterYConstraint.constant = 0;

        self.activeAccentColor = [UIColor hx_colorWithHexStr:@"#6F819B"];
        self.activeGradientColors = @[
            [UIColor hx_colorWithHexStr:@"#F8FAFD"],
            [UIColor hx_colorWithHexStr:@"#E8EEF6"],
            [UIColor hx_colorWithHexStr:@"#CBD6E5"]
        ];

        [self pp_applyVisualPalette:self.activeGradientColors
                             accent:self.activeAccentColor
                       contentColor:contentColor
                              isAll:YES];
    } else {
        UIColor *contentColor = UIColor.whiteColor;
        self.iconView.image = kind.KindImageFile;
        self.titleLabel.text = kind.KindName;
        self.titleShadowContainer.hidden = NO;
        self.iconSizeConstraint.constant = 48;
        self.iconCenterYConstraint.constant = -18;

        self.activeGradientColors = [self pp_paletteForKind:kind];
        self.activeAccentColor = self.activeGradientColors.count > 1
            ? self.activeGradientColors[1]
            : (kind.kindColor ?: AppPrimaryClr);

        [self pp_applyVisualPalette:self.activeGradientColors
                             accent:self.activeAccentColor
                       contentColor:contentColor
                              isAll:NO];
        
        config.background.backgroundColor = [self.activeAccentColor colorWithAlphaComponent:0.82];
        config.baseBackgroundColor =  [self.activeAccentColor colorWithAlphaComponent:0.82];
        self.glassButton.configuration = config;
    }

    // Force layout resolution FIRST so glassButton has correct bounds,
    // then apply gradient and selection state with valid geometry.
    [self setNeedsLayout];
    [self.contentView setNeedsLayout];
    [self layoutIfNeeded];

    [self pp_applyGradientIfNeeded];
    [self applySelection:selected animated:NO];
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    [super applyLayoutAttributes:layoutAttributes];
    [self setNeedsLayout];
    [self.contentView setNeedsLayout];
    [self layoutIfNeeded];
}

#pragma mark - Palette

- (NSArray<UIColor *> *)pp_paletteForKind:(MainKindsModel *)kind
{
    switch (kind.ID) {
        case 1:
            return @[
                [UIColor hx_colorWithHexStr:@"#86F0C5"],
                [UIColor hx_colorWithHexStr:@"#29B783"],
                [UIColor hx_colorWithHexStr:@"#0F6354"]
            ];
        case 2:
            return @[
                [UIColor hx_colorWithHexStr:@"#FFC58E"],
                [UIColor hx_colorWithHexStr:@"#F28B54"],
                [UIColor hx_colorWithHexStr:@"#8D4727"]
            ];
        case 3:
            return @[
                [UIColor hx_colorWithHexStr:@"#D7C2FF"],
                [UIColor hx_colorWithHexStr:@"#9A72F8"],
                [UIColor hx_colorWithHexStr:@"#5030A7"]
            ];
        case 4:
            return @[
                [UIColor hx_colorWithHexStr:@"#8CE6FF"],
                [UIColor hx_colorWithHexStr:@"#42A8FF"],
                [UIColor hx_colorWithHexStr:@"#1C549E"]
            ];
        case 5:
            return @[
                [UIColor hx_colorWithHexStr:@"#FFB8CF"],
                [UIColor hx_colorWithHexStr:@"#F46B9C"],
                [UIColor hx_colorWithHexStr:@"#8E2E59"]
            ];
        case 6:
            return @[
                [UIColor hx_colorWithHexStr:@"#F7D49F"],
                [UIColor hx_colorWithHexStr:@"#D89A5B"],
                [UIColor hx_colorWithHexStr:@"#88542F"]
            ];
        case 7:
            return @[
                [UIColor hx_colorWithHexStr:@"#7EF3E8"],
                [UIColor hx_colorWithHexStr:@"#1CBFB0"],
                [UIColor hx_colorWithHexStr:@"#0E6466"]
            ];
        case 8:
            return @[
                [UIColor hx_colorWithHexStr:@"#F2C4B4"],
                [UIColor hx_colorWithHexStr:@"#D97D6B"],
                [UIColor hx_colorWithHexStr:@"#7A3E37"]
            ];
        case 9:
            return @[
                [UIColor hx_colorWithHexStr:@"#D7F17A"],
                [UIColor hx_colorWithHexStr:@"#8DBD42"],
                [UIColor hx_colorWithHexStr:@"#476D25"]
            ];
        case 10:
            return @[
                [UIColor hx_colorWithHexStr:@"#B8C9FF"],
                [UIColor hx_colorWithHexStr:@"#6D7BEB"],
                [UIColor hx_colorWithHexStr:@"#333D84"]
            ];
        case 11:
            return @[
                [UIColor hx_colorWithHexStr:@"#EADFC9"],
                [UIColor hx_colorWithHexStr:@"#B79C79"],
                [UIColor hx_colorWithHexStr:@"#615243"]
            ];
        default:
            return @[
                [UIColor hx_colorWithHexStr:@"#B9C2FF"],
                [UIColor hx_colorWithHexStr:@"#707AF7"],
                [UIColor hx_colorWithHexStr:@"#363B86"]
            ];
    }
}

- (void)pp_applyVisualPalette:(NSArray<UIColor *> *)palette
                       accent:(UIColor *)accent
                 contentColor:(UIColor *)contentColor
                        isAll:(BOOL)isAll
{
    UIColor *pillBase = isAll
        ? [UIColor colorWithWhite:1.0 alpha:0.68]
        : [PPColorUtils blendColor:[UIColor whiteColor] withColor:accent factor:0.10];
    UIColor *iconBase = isAll
        ? [UIColor colorWithWhite:1.0 alpha:0.78]
        : [PPColorUtils blendColor:[UIColor whiteColor] withColor:accent factor:0.15];

    [self.glassButton pp_setBorderColor:(isAll
        ? [contentColor colorWithAlphaComponent:0.10]
        : [[UIColor whiteColor] colorWithAlphaComponent:0.18])];

    self.titleBackground.backgroundColor =
        [pillBase colorWithAlphaComponent:isAll ? 0.82 : 0.18];
    self.titleLabel.textColor = contentColor;

    self.iconBackdropView.backgroundColor =
        [iconBase colorWithAlphaComponent:isAll ? 0.90 : 0.14];
    [self.iconBackdropView pp_setBorderColor:(isAll
        ? [contentColor colorWithAlphaComponent:0.08]
        : [[UIColor whiteColor] colorWithAlphaComponent:0.22])];

    self.iconView.tintColor = contentColor;
    self.topGlowView.backgroundColor =
        [[UIColor whiteColor] colorWithAlphaComponent:isAll ? 0.18 : 0.12];
    self.bottomGlowView.backgroundColor =
        [accent colorWithAlphaComponent:isAll ? 0.14 : 0.18];
    [self.titleShadowContainer pp_setShadowColor:accent];
}

- (void)pp_applyGradientIfNeeded
{
    if (self.activeGradientColors.count < 3) {
        return;
    }

    [self.glassButton setBackgroundGradientFrom:self.activeGradientColors[0]
                                    middleColor:self.activeGradientColors[1]
                                              to:self.activeGradientColors[2]
                                           angle:self.isAll ? 140.0 : 132.0
                                     cornerRadius:PPNewCorner];
}


- (void)setBackgroundGradientFrom:(UIColor *)start
                     middleColor:(UIColor *)middle
                               to:(UIColor *)end
                            angle:(CGFloat)degrees
                      cornerRadius:(CGFloat)radius
{
    CAGradientLayer *layer = nil;

    for (CALayer *l in self.layer.sublayers) {
        if ([l.name isEqualToString:@"PPGradientLayer"]) {
            layer = (CAGradientLayer *)l;
            break;
        }
    }

    if (!layer) {
        layer = [CAGradientLayer layer];
        layer.name = @"PPGradientLayer";
        [self.layer insertSublayer:layer atIndex:0];
    }

    layer.frame = self.bounds;
    layer.cornerRadius = radius;
    layer.colors = @[
        (__bridge id)start.CGColor,
        (__bridge id)middle.CGColor,
        (__bridge id)end.CGColor
    ];
    layer.locations = @[@0.0, @0.5, @1.0];

    CGFloat rad = degrees * M_PI / 180.0;
    layer.startPoint = CGPointMake(0.5 - cos(rad)/2, 0.5 - sin(rad)/2);
    layer.endPoint   = CGPointMake(0.5 + cos(rad)/2, 0.5 + sin(rad)/2);
    
    CGRect fram = CGRectMake(0, 0, self.contentView.hx_w, self.contentView.hx_h);
    layer.frame = fram;
}


#pragma mark - Action

- (void)handleTap
{
    if (self.onSelect) {
        self.onSelect(self.model, self.isAll);
    }
}

- (UIButton *)setButtonAsBackroundButton
{
    UIButton *bgButton;
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
        cfg.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(12, 12, 12, 12);
        cfg.background.cornerRadius = PPNewCornerMin;
        cfg.background.backgroundColor = UIColor.whiteColor;
        cfg.baseBackgroundColor = UIColor.whiteColor;

        bgButton = [UIButton buttonWithType:UIButtonTypeSystem];
        bgButton.configuration = cfg;
        bgButton.clipsToBounds = YES;
        bgButton.layer.masksToBounds = YES;
    } else {
        UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
        cfg.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(12, 12, 12, 12);
        cfg.background.cornerRadius = PPNewCornerMin;

        bgButton = [UIButton buttonWithType:UIButtonTypeSystem];
        bgButton.configuration = cfg;
        bgButton.backgroundColor = UIColor.clearColor;
        bgButton.layer.cornerRadius = PPNewCornerMin;
        bgButton.layer.masksToBounds = YES;
    }

    bgButton.translatesAutoresizingMaskIntoConstraints = NO;
    return bgButton;
}

- (void)applySelection:(BOOL)selected animated:(BOOL)animated
{
    UIColor *accent = self.activeAccentColor ?: (self.isAll
        ? [UIColor hx_colorWithHexStr:@"#6F819B"]
        : (self.model.kindColor ?: AppPrimaryClr));

    CGFloat scale = selected ? 1.02 : 1.0;
    CGFloat shadowOpacity = selected ? 0.12 : 0.07;
    CGFloat shadowRadius = selected ? 18.0 : 12.0;
    CGSize shadowOffset = selected ? CGSizeMake(0, 10) : CGSizeMake(0, 7.0);
    UIColor *borderColor = self.isAll
        ? [accent colorWithAlphaComponent:selected ? 0.24 : 0.12]
        : [[UIColor whiteColor] colorWithAlphaComponent:selected ? 0.30 : 0.14];

    void (^changes)(void) = ^{
        self.transform = CGAffineTransformMakeScale(scale, scale);
        self.alpha = 1.0;
        self.layer.shadowOpacity = shadowOpacity;
        self.layer.shadowRadius = shadowRadius;
        self.layer.shadowOffset = shadowOffset;
        [self.glassButton pp_setBorderColor:borderColor];
        self.glassButton.layer.borderWidth = selected ? 1.2 : 0.8;
        self.topGlowView.alpha = selected ? (self.isAll ? 0.28 : 0.36) : (self.isAll ? 0.12 : 0.18);
        self.bottomGlowView.alpha = selected ? (self.isAll ? 0.20 : 0.30) : (self.isAll ? 0.10 : 0.16);
        self.iconBackdropView.transform = selected ? CGAffineTransformMakeScale(1.02, 1.02) : CGAffineTransformIdentity;
        self.titleBackground.alpha = selected ? 1.0 : 0.94;
        self.titleShadowContainer.layer.shadowOpacity = self.titleShadowContainer.hidden ? 0.0 : (selected ? 0.12 : 0.06);
        self.titleShadowContainer.layer.shadowRadius = selected ? 10.0 : 8.0;
    };

    if (animated) {
        [UIView animateWithDuration:0.22
                              delay:0.0
             usingSpringWithDamping:0.90
              initialSpringVelocity:0.60
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    [self applySelection:selected animated:YES];
}

@end
