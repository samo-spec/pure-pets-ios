#import "PPSectionHeaderView.h"
#import <QuartzCore/QuartzCore.h>

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - PPCollectionSectionHeader
// ──────────────────────────────────────────────────────────────────────────────

@interface PPCollectionSectionHeader ()
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) CAGradientLayer *accentLine;
@property (nonatomic, strong) UILabel *ppTitleLabel;
@property (nonatomic, strong) UILabel *ppSubtitleLabel;
@property (nonatomic, strong) UIButton *ppActionButton;
@property (nonatomic, copy)   void (^ppActionBlock)(void);
@end

@implementation PPCollectionSectionHeader

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) { [self pp_buildCollectionHeaderUI]; }
    return self;
}

- (void)pp_buildCollectionHeaderUI {
    self.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = GM.setSemantic;

    // ── Glassmorphism surface ──
    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
   // self.surfaceView.layer.cornerRadius  = PPCornerCard;
    self.surfaceView.layer.cornerCurve   = kCACornerCurveContinuous;
    self.surfaceView.layer.borderWidth = 0.75;
    self.surfaceView.layer.borderColor = [[UIColor labelColor] colorWithAlphaComponent:0.04].CGColor;
   // self.surfaceView.clipsToBounds = YES;
    [self addSubview:self.surfaceView];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:
        (PPIOS26() ? UIBlurEffectStyleSystemChromeMaterial : UIBlurEffectStyleSystemThinMaterial)];
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.blurView.translatesAutoresizingMaskIntoConstraints = NO;
    self.blurView.alpha = 0.34;
    [self.surfaceView addSubview:self.blurView];
    [NSLayoutConstraint activateConstraints:@[
        [self.blurView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor],
        [self.blurView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor],
        [self.blurView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor],
        [self.blurView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor],
    ]];

    // Accent line at leading edge
    self.accentLine = [CAGradientLayer layer];
    self.accentLine.startPoint = CGPointMake(0.5, 0.0);
    self.accentLine.endPoint   = CGPointMake(0.5, 1.0);
    self.accentLine.cornerRadius = 2.0;
    self.accentLine.colors = @[
        (id)[(AppPrimaryClr ?: UIColor.systemTealColor) colorWithAlphaComponent:0.90].CGColor,
        (id)[(AppPrimaryClr ?: UIColor.systemTealColor) colorWithAlphaComponent:0.18].CGColor,
    ];
    [self.surfaceView.layer addSublayer:self.accentLine];

    // Title
    self.ppTitleLabel = [[UILabel alloc] init];
    self.ppTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.ppTitleLabel.font      = [GM boldFontWithSize:PPFontHeadline];
    self.ppTitleLabel.textColor = AppPrimaryTextClr;
    [self.surfaceView addSubview:self.ppTitleLabel];

    // Subtitle
    self.ppSubtitleLabel = [[UILabel alloc] init];
    self.ppSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.ppSubtitleLabel.font         = [GM MidFontWithSize:PPFontFootnote];
    self.ppSubtitleLabel.textColor    = UIColor.secondaryLabelColor;
    self.ppSubtitleLabel.numberOfLines = 1;
    self.ppSubtitleLabel.hidden       = YES;
    [self.surfaceView addSubview:self.ppSubtitleLabel];

    // Action button
    UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
    cfg.baseForegroundColor = AppPrimaryClr;
    cfg.contentInsets = NSDirectionalEdgeInsetsMake(PPSpaceXS, PPSpaceSM, PPSpaceXS, PPSpaceSM);
    cfg.titleTextAttributesTransformer =
    ^NSDictionary<NSAttributedStringKey,id> *(NSDictionary<NSAttributedStringKey,id> *attrs) {
        NSMutableDictionary *m = attrs.mutableCopy;
        m[NSFontAttributeName]            = [GM MidFontWithSize:PPFontSubheadline];
        m[NSForegroundColorAttributeName] = AppPrimaryClr;
        return m;
    };
    self.ppActionButton = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    self.ppActionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.ppActionButton.hidden = YES;
    [self.ppActionButton addTarget:self
                            action:@selector(pp_collectionHeaderActionTapped)
                  forControlEvents:UIControlEventTouchUpInside];
    [self.surfaceView addSubview:self.ppActionButton];

    CGFloat leadingInset = PPSpaceBase + 5.0;
    [NSLayoutConstraint activateConstraints:@[
        [self.surfaceView.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor  constant:PPSpaceSM],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-PPSpaceSM],
        [self.surfaceView.topAnchor      constraintEqualToAnchor:self.topAnchor      constant:PPSpaceXS],
        [self.surfaceView.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor   constant:-PPSpaceXS],

        [self.ppTitleLabel.leadingAnchor  constraintEqualToAnchor:self.surfaceView.leadingAnchor  constant:leadingInset],
        [self.ppTitleLabel.centerYAnchor  constraintEqualToAnchor:self.surfaceView.centerYAnchor  constant:-PPSpaceXXS],
        [self.ppTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.ppActionButton.leadingAnchor constant:-PPSpaceSM],

        [self.ppSubtitleLabel.leadingAnchor  constraintEqualToAnchor:self.ppTitleLabel.leadingAnchor],
        [self.ppSubtitleLabel.topAnchor      constraintEqualToAnchor:self.ppTitleLabel.bottomAnchor constant:PPSpaceXXS],
        [self.ppSubtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.ppActionButton.leadingAnchor constant:-PPSpaceSM],

        [self.ppActionButton.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-PPSpaceSM],
        [self.ppActionButton.centerYAnchor  constraintEqualToAnchor:self.surfaceView.centerYAnchor],
    ]];
}

- (void)configureWithTitle:(NSString *)title
                  subtitle:(nullable NSString *)subtitle
               actionTitle:(nullable NSString *)actionTitle
                    action:(nullable void (^)(void))action
{
    self.ppTitleLabel.text = title;

    if (subtitle.length > 0) {
        self.ppSubtitleLabel.text   = subtitle;
        self.ppSubtitleLabel.hidden = NO;
    } else {
        self.ppSubtitleLabel.text   = nil;
        self.ppSubtitleLabel.hidden = YES;
    }

    if (actionTitle.length > 0) {
        [self.ppActionButton setTitle:actionTitle forState:UIControlStateNormal];
        self.ppActionButton.hidden = NO;
        self.ppActionBlock = action;
    } else {
        self.ppActionButton.hidden = YES;
        self.ppActionBlock = nil;
    }
}

- (void)pp_collectionHeaderActionTapped {
    if (self.ppActionBlock) { self.ppActionBlock(); }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = self.surfaceView.bounds;
    BOOL isRTL = (self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);
    CGFloat lineX = isRTL ? (CGRectGetWidth(bounds) - 2.5 - PPSpaceXS) : PPSpaceXS;
    self.accentLine.frame = CGRectMake(lineX, 10.0, 2.5, CGRectGetHeight(bounds) - 20.0);

    CGFloat leadR = 16.0, trailR = 16.0;
    CGFloat topL = isRTL ? trailR : leadR;
    CGFloat topR = isRTL ? leadR  : trailR;
    CGFloat botL = isRTL ? trailR : leadR;
    CGFloat botR = isRTL ? leadR  : trailR;
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:bounds
                                              byRoundingCorners:UIRectCornerAllCorners
                                                    cornerRadii:CGSizeZero];
    path = [self pp_pathForRect:bounds topLeft:topL topRight:topR bottomLeft:botL bottomRight:botR];
    CAShapeLayer *mask = [CAShapeLayer layer];
    mask.path = path.CGPath;
    self.surfaceView.layer.mask = mask;
}

- (UIBezierPath *)pp_pathForRect:(CGRect)rect
                         topLeft:(CGFloat)tl topRight:(CGFloat)tr
                      bottomLeft:(CGFloat)bl bottomRight:(CGFloat)br
{
    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(tl, 0)];
    [p addLineToPoint:CGPointMake(CGRectGetWidth(rect) - tr, 0)];
    [p addArcWithCenter:CGPointMake(CGRectGetWidth(rect) - tr, tr)
                 radius:tr startAngle:-M_PI_2 endAngle:0 clockwise:YES];
    [p addLineToPoint:CGPointMake(CGRectGetWidth(rect), CGRectGetHeight(rect) - br)];
    [p addArcWithCenter:CGPointMake(CGRectGetWidth(rect) - br, CGRectGetHeight(rect) - br)
                 radius:br startAngle:0 endAngle:M_PI_2 clockwise:YES];
    [p addLineToPoint:CGPointMake(bl, CGRectGetHeight(rect))];
    [p addArcWithCenter:CGPointMake(bl, CGRectGetHeight(rect) - bl)
                 radius:bl startAngle:M_PI_2 endAngle:M_PI clockwise:YES];
    [p addLineToPoint:CGPointMake(0, tl)];
    [p addArcWithCenter:CGPointMake(tl, tl)
                 radius:tl startAngle:M_PI endAngle:-M_PI_2 clockwise:YES];
    [p closePath];
    return p;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previous]) {
        self.accentLine.colors = @[
            (id)(AppPrimaryClr ?: UIColor.systemTealColor).CGColor,
            (id)[(AppPrimaryClr ?: UIColor.systemTealColor) colorWithAlphaComponent:0.3].CGColor,
        ];
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.ppTitleLabel.text      = nil;
    self.ppSubtitleLabel.text   = nil;
    self.ppSubtitleLabel.hidden = YES;
    self.ppActionButton.hidden  = YES;
    self.ppActionBlock          = nil;
}

@end

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - PPSectionHeaderView
// ──────────────────────────────────────────────────────────────────────────────

@interface PPSectionHeaderView () <UIGestureRecognizerDelegate>
@property (nonatomic, strong, readwrite) UILabel *titleLabel;
@property (nonatomic, strong, readwrite) UILabel *subtitleLabel;
@property (nonatomic, strong, readwrite) UIButton *actionButton;
@property (nonatomic, strong) NSLayoutConstraint *titleTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *titleCenterConstraint;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) CAGradientLayer *accentLine;
@property (nonatomic, assign) BOOL isExpanded;
@property (nonatomic, assign) PPHomeSection currentSection;
@property (nonatomic, assign) CFTimeInterval lastActionTimestamp;
@end

@implementation PPSectionHeaderView

- (UIColor *)pp_overlayColor
{
    BOOL isDark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    return isDark
        ? [UIColor colorWithWhite:1.0 alpha:0.04]
        : [AppForgroundColr colorWithAlphaComponent:0.56];
}

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) { [self pp_buildUI]; }
    return self;
}

#pragma mark - Build UI

- (UIButtonConfiguration *)pp_baseActionButtonConfiguration
{
    UIButtonConfiguration *cfg = [UIButtonConfiguration tintedButtonConfiguration];
    cfg.contentInsets = NSDirectionalEdgeInsetsMake(8.0, 12.0, 8.0, 12.0);
    cfg.imagePadding  = 6;
    cfg.imagePlacement = NSDirectionalRectEdgeTrailing;
    cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;

    UIImageSymbolConfiguration *symbolCfg =
        [UIImageSymbolConfiguration configurationWithPointSize:13
                                                        weight:UIImageSymbolWeightBold
                                                         scale:UIImageSymbolScaleMedium];
    UIImage *chevron = [UIImage systemImageNamed:@"chevron.down" withConfiguration:symbolCfg];
    if (@available(iOS 15.0, *)) {
        chevron = [chevron imageByApplyingSymbolConfiguration:
            [UIImageSymbolConfiguration configurationWithPaletteColors:@[
                AppSecondaryTextClr
            ]]];
    }
    cfg.image = chevron;
    cfg.baseForegroundColor = AppPrimaryClr ?: UIColor.systemTealColor;
    cfg.baseBackgroundColor = [(AppPrimaryClr ?: UIColor.systemTealColor) colorWithAlphaComponent:0.10];

    cfg.titleTextAttributesTransformer =
    ^NSDictionary<NSAttributedStringKey,id> *(NSDictionary<NSAttributedStringKey,id> *attrs) {
        NSMutableDictionary *m = attrs.mutableCopy;
        m[NSFontAttributeName]            = [GM MidFontWithSize:12.5] ?: [UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold];
        m[NSForegroundColorAttributeName] = AppPrimaryClr ?: UIColor.systemTealColor;
        return m;
    };

    return cfg;
}

- (void)pp_buildUI {
    self.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = GM.setSemantic;

    // ── Glassmorphism surface ──
    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    //self.surfaceView.layer.cornerRadius = 0;
    self.surfaceView.layer.cornerCurve  = kCACornerCurveContinuous;
    self.surfaceView.layer.borderWidth = 0.75;
    self.surfaceView.layer.borderColor = [[UIColor labelColor] colorWithAlphaComponent:0.04].CGColor;
    //self.surfaceView.clipsToBounds = YES;
    [self addSubview:self.surfaceView];
    [self sendSubviewToBack:self.surfaceView];

    // Blur material
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:
        (PPIOS26() ? UIBlurEffectStyleSystemChromeMaterial : UIBlurEffectStyleSystemUltraThinMaterial)];
    
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.blurView.alpha = 0.36;
    self.blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.surfaceView addSubview:self.blurView];
    [NSLayoutConstraint activateConstraints:@[
        [self.blurView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor],
        [self.blurView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor],
        [self.blurView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor],
        [self.blurView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor],
    ]];

    // Tinted overlay for warmth
    UIView *overlay = [[UIView alloc] init];
    overlay.translatesAutoresizingMaskIntoConstraints = NO;
    overlay.backgroundColor = [self pp_overlayColor];
    overlay.userInteractionEnabled = NO;
    overlay.tag = 999;
    [self.surfaceView addSubview:overlay];
    [NSLayoutConstraint activateConstraints:@[
        [overlay.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor],
        [overlay.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor],
        [overlay.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor],
        [overlay.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor],
    ]];

    // Accent gradient line at leading edge
    self.accentLine = [CAGradientLayer layer];
    self.accentLine.startPoint = CGPointMake(0.5, 0.0);
    self.accentLine.endPoint   = CGPointMake(0.5, 1.0);
    self.accentLine.cornerRadius = 1.5;
    self.accentLine.colors = @[
        (id)[(AppPrimaryClr ?: UIColor.systemTealColor) colorWithAlphaComponent:0.92].CGColor,
        (id)[(AppPrimaryClr ?: UIColor.systemTealColor) colorWithAlphaComponent:0.16].CGColor,
    ];
    [self.surfaceView.layer addSublayer:self.accentLine];

    // ── Tap gesture ──
    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_actionTapped)];
    tap.delegate = self;
    tap.cancelsTouchesInView = NO;
    [self addGestureRecognizer:tap];

    // ── Title ──
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font      = [GM boldFontWithSize:19.0] ?: [UIFont systemFontOfSize:19.0 weight:UIFontWeightBold];
    _titleLabel.textColor = AppPrimaryTextClr;
    [self addSubview:_titleLabel];

    // ── Subtitle ──
    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font         = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    _subtitleLabel.textColor    = UIColor.secondaryLabelColor;
    _subtitleLabel.numberOfLines = 2;
    _subtitleLabel.hidden       = YES;
    [self addSubview:_subtitleLabel];

    // ── Action button ──
    [self pp_buildActionButton];
    [self addSubview:_actionButton];

    // ── Layout ──
    CGFloat contentLeading = PPSpaceBase + 5.0;
    self.titleTopConstraint =
        [_titleLabel.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:PPSpaceXS + 2.0];
    self.titleCenterConstraint =
        [_titleLabel.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor];

    self.titleTopConstraint.active    = YES;
    self.titleCenterConstraint.active = NO;

    [NSLayoutConstraint activateConstraints:@[
        // Surface → edges
        [self.surfaceView.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor  constant:PPSpaceXS],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-PPSpaceXS],
        [self.surfaceView.topAnchor      constraintEqualToAnchor:self.topAnchor      constant:PPSpaceXS],
        [self.surfaceView.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor   constant:-PPSpaceXS],
        // Action button
        [_actionButton.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-12.0],
        [_actionButton.centerYAnchor  constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        // Title
        [_titleLabel.leadingAnchor  constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:contentLeading],
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_actionButton.leadingAnchor constant:-PPSpaceSM],
        // Subtitle
        [_subtitleLabel.leadingAnchor  constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subtitleLabel.topAnchor      constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4.0],
        [_subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_actionButton.leadingAnchor constant:-PPSpaceSM],
    ]];
}

- (void)pp_buildActionButton {
    _actionButton = [UIButton buttonWithConfiguration:[self pp_baseActionButtonConfiguration] primaryAction:nil];
    _actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    _actionButton.hidden = YES;
    _actionButton.layer.shadowColor   = UIColor.blackColor.CGColor;
    _actionButton.layer.shadowOpacity = 0.05;
    _actionButton.layer.shadowRadius  = 8.0;
    _actionButton.layer.shadowOffset  = CGSizeMake(0, 3.0);
    [_actionButton addTarget:self
                      action:@selector(pp_actionTapped)
            forControlEvents:UIControlEventTouchUpInside];
}

#pragma mark - Layout & Appearance

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = self.surfaceView.bounds;
    BOOL isRTL = (self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);
    CGFloat lineX = isRTL ? (CGRectGetWidth(bounds) - 2.5 - PPSpaceXS) : PPSpaceXS;
    self.accentLine.frame = CGRectMake(lineX, 10.0, 2.5, CGRectGetHeight(bounds) - 20.0);

    CGFloat leadR = 16.0, trailR = 16.0;
    CGFloat topL = isRTL ? trailR : leadR;
    CGFloat topR = isRTL ? leadR  : trailR;
    CGFloat botL = isRTL ? trailR : leadR;
    CGFloat botR = isRTL ? leadR  : trailR;
    UIBezierPath *path = [self pp_pathForRect:bounds topLeft:topL topRight:topR bottomLeft:botL bottomRight:botR];
    CAShapeLayer *mask = [CAShapeLayer layer];
    mask.path = path.CGPath;
    self.surfaceView.layer.mask = mask;
    
    self.surfaceView.layer.borderColor = [[UIColor labelColor] colorWithAlphaComponent:0.06].CGColor;
    self.surfaceView.layer.borderWidth = 0.75;
}

- (UIBezierPath *)pp_pathForRect:(CGRect)rect
                         topLeft:(CGFloat)tl topRight:(CGFloat)tr
                      bottomLeft:(CGFloat)bl bottomRight:(CGFloat)br
{
    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(tl, 0)];
    [p addLineToPoint:CGPointMake(CGRectGetWidth(rect) - tr, 0)];
    [p addArcWithCenter:CGPointMake(CGRectGetWidth(rect) - tr, tr)
                 radius:tr startAngle:-M_PI_2 endAngle:0 clockwise:YES];
    [p addLineToPoint:CGPointMake(CGRectGetWidth(rect), CGRectGetHeight(rect) - br)];
    [p addArcWithCenter:CGPointMake(CGRectGetWidth(rect) - br, CGRectGetHeight(rect) - br)
                 radius:br startAngle:0 endAngle:M_PI_2 clockwise:YES];
    [p addLineToPoint:CGPointMake(bl, CGRectGetHeight(rect))];
    [p addArcWithCenter:CGPointMake(bl, CGRectGetHeight(rect) - bl)
                 radius:bl startAngle:M_PI_2 endAngle:M_PI clockwise:YES];
    [p addLineToPoint:CGPointMake(0, tl)];
    [p addArcWithCenter:CGPointMake(tl, tl)
                 radius:tl startAngle:M_PI endAngle:-M_PI_2 clockwise:YES];
    [p closePath];
    return p;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previous]) {
        UIView *overlay = [self.surfaceView viewWithTag:999];
        overlay.backgroundColor = [self pp_overlayColor];
        self.accentLine.colors = @[
            (id)[(AppPrimaryClr ?: UIColor.systemTealColor) colorWithAlphaComponent:0.92].CGColor,
            (id)[(AppPrimaryClr ?: UIColor.systemTealColor) colorWithAlphaComponent:0.16].CGColor,
        ];
        _actionButton.layer.shadowColor = UIColor.blackColor.CGColor;
    }
}

- (void)hide {
    self.actionButton.hidden = YES;
}

#pragma mark - Configuration (Compact)

- (void)configureWithTitle:(nullable NSString *)title
               actionTitle:(nullable NSString *)actionTitle
                  iconName:(nullable NSString *)iconName
                      menu:(nullable UIMenu *)menu
             ppHomeSection:(PPHomeSection)ppHomeSection
{
    self.currentSection = ppHomeSection;
    self.titleLabel.text = title;
    self.actionButton.configuration = [self pp_baseActionButtonConfiguration];
    self.actionButton.imageView.transform = CGAffineTransformIdentity;

    // Action button visibility
    BOOL showAction = (ppHomeSection == PPHomeSectionMainKinds || actionTitle.length > 0);
    self.actionButton.hidden = !showAction;

    UIButtonConfiguration *cfg = self.actionButton.configuration;
    cfg.title = actionTitle.length > 0 ? actionTitle : @"";
    self.actionButton.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    // Custom icon for non-MainKinds sections
    if (iconName.length > 0 && ppHomeSection != PPHomeSectionMainKinds) {
        UIImage *symbol = [UIImage pp_symbolNamed:iconName
                                        pointSize:13
                                           weight:UIImageSymbolWeightBold
                                            scale:UIImageSymbolScaleMedium
                                          palette:@[AppSecondaryTextClr]
                                     makeTemplate:YES];
        cfg.image          = symbol;
        cfg.imagePlacement = NSDirectionalRectEdgeLeading;
        cfg.imagePadding   = 6;
    } else {
        cfg.imagePlacement = NSDirectionalRectEdgeTrailing;
    }
    self.actionButton.configuration = cfg;

    // Menu
    if (menu) {
        self.actionButton.menu = menu;
        self.actionButton.showsMenuAsPrimaryAction = YES;
        [PPMenuHelper presentMenuFromButton:self.actionButton
                                       Menu:menu
                                destructive:nil
                                    handler:^(NSInteger idx, NSString *t) { }];
    } else {
        self.actionButton.showsMenuAsPrimaryAction = NO;
        self.actionButton.menu = nil;
    }

    // Title centered (no subtitle in compact mode)
    self.titleTopConstraint.active    = NO;
    self.titleCenterConstraint.active = YES;

    //self.surfaceView.layer.cornerRadius = PPCornerCard;

    [self setNeedsUpdateConstraints];
    [self setNeedsLayout];
    [self layoutIfNeeded];

    if (ppHomeSection != PPHomeSectionMainKinds) { return; }
    [self pp_setExpanded:self.isExpanded animated:NO];
}

#pragma mark - Configuration (Full)

- (void)configureWithTitle:(nullable NSString *)title
                  subtitle:(nullable NSString *)subtitle
               actionTitle:(nullable NSString *)actionTitle
                  iconName:(nullable NSString *)iconName
                      menu:(nullable UIMenu *)menu
             ppHomeSection:(PPHomeSection)ppHomeSection
{
    // Forward shared setup to compact variant
    [self configureWithTitle:title
                 actionTitle:actionTitle
                    iconName:iconName
                        menu:menu
               ppHomeSection:ppHomeSection];

    // Subtitle handling
    if (subtitle.length > 0) {
        self.subtitleLabel.text   = subtitle;
        self.subtitleLabel.hidden = NO;
        self.titleTopConstraint.active    = YES;
        self.titleCenterConstraint.active = NO;
    } else {
        self.subtitleLabel.text   = nil;
        self.subtitleLabel.hidden = YES;
        self.titleTopConstraint.active    = NO;
        self.titleCenterConstraint.active = YES;
    }

    [self setNeedsUpdateConstraints];
    [self setNeedsLayout];
    [self layoutIfNeeded];

    [self pp_setExpanded:(ppHomeSection == PPHomeSectionMainKinds && self.isExpanded) animated:NO];
}

#pragma mark - Reuse

- (void)prepareForReuse {
    [super prepareForReuse];
    self.titleLabel.text      = nil;
    self.subtitleLabel.text   = nil;
    self.subtitleLabel.hidden = YES;
    self.actionButton.hidden  = YES;
    self.onTap                = nil;
    self.onTapMenu            = nil;
    self.lastActionTimestamp   = 0;

    // Reset menu state
    self.actionButton.showsMenuAsPrimaryAction = NO;
    self.actionButton.menu = nil;
    self.actionButton.configuration = [self pp_baseActionButtonConfiguration];
    self.titleTopConstraint.active = NO;
    self.titleCenterConstraint.active = YES;
    self.surfaceView.transform = CGAffineTransformIdentity;

    // Reset chevron rotation
    self.actionButton.imageView.transform = CGAffineTransformIdentity;
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    [super applyLayoutAttributes:layoutAttributes];
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

#pragma mark - Actions

- (void)pp_actionTapped {
    CFTimeInterval now = CACurrentMediaTime();
    if ((now - self.lastActionTimestamp) < 0.25) { return; }
    self.lastActionTimestamp = now;

    // Micro-interaction: surface press feedback
    [UIView animateWithDuration:0.08 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.surfaceView.transform = CGAffineTransformMakeScale(0.98, 0.98);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.18 delay:0
             usingSpringWithDamping:0.7
              initialSpringVelocity:0.4
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.surfaceView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];

    if (self.currentSection != PPHomeSectionMainKinds) {
        if (self.onTap) { self.onTap(); }
        return;
    }

    [PPFunc triggerMediumHaptic];
    self.isExpanded = !self.isExpanded;
    [self pp_setExpanded:self.isExpanded animated:YES];

    if (self.onTap) { self.onTap(); }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(UITouch *)touch
{
    (void)gestureRecognizer;
    UIView *hitView = touch.view;
    while (hitView) {
        if (hitView == self.actionButton) { return NO; }
        hitView = hitView.superview;
    }
    return YES;
}

#pragma mark - Expand / Collapse

- (void)pp_setExpanded:(BOOL)expanded animated:(BOOL)animated {
    _isExpanded = expanded;

    if (self.currentSection != PPHomeSectionMainKinds) {
        self.actionButton.imageView.transform = CGAffineTransformIdentity;
        return;
    }

    CGFloat angle = expanded ? M_PI : 0;
    void (^rotate)(void) = ^{
        self.actionButton.imageView.transform = CGAffineTransformMakeRotation(angle);
    };

    if (animated) {
        [UIView animateWithDuration:0.35
                              delay:0
             usingSpringWithDamping:0.72
              initialSpringVelocity:0.6
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:rotate
                         completion:nil];
    } else {
        rotate();
    }
}

@end
