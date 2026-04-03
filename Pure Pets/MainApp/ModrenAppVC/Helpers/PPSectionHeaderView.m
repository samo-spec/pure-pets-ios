#import "PPSectionHeaderView.h"
#import <QuartzCore/QuartzCore.h>

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - PPCollectionSectionHeader
// ──────────────────────────────────────────────────────────────────────────────

@interface PPCollectionSectionHeader ()
@property (nonatomic, strong) UIView *surfaceView;
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

    // Glass surface
    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.surfaceView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.55];
    self.surfaceView.layer.cornerRadius  = PPCornerCard;
    self.surfaceView.layer.cornerCurve   = kCACornerCurveContinuous;
    self.surfaceView.layer.borderWidth   = 0.33;
    self.surfaceView.layer.borderColor   = [AppForgroundColr colorWithAlphaComponent:0.68].CGColor;
    self.surfaceView.layer.shadowColor   = UIColor.blackColor.CGColor;
    self.surfaceView.layer.shadowOpacity = PPShadowCardOpacity;
    self.surfaceView.layer.shadowRadius  = PPShadowCardRadius;
    self.surfaceView.layer.shadowOffset  = CGSizeMake(0, PPShadowCardOffsetY);
    [self addSubview:self.surfaceView];

    // Title
    self.ppTitleLabel = [[UILabel alloc] init];
    self.ppTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.ppTitleLabel.font      = [GM boldFontWithSize:PPFontTitle3];
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

    [NSLayoutConstraint activateConstraints:@[
        [self.surfaceView.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor  constant:PPSpaceSM],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-PPSpaceSM],
        [self.surfaceView.topAnchor      constraintEqualToAnchor:self.topAnchor      constant:PPSpaceXS],
        [self.surfaceView.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor   constant:-PPSpaceXS],

        [self.ppTitleLabel.leadingAnchor  constraintEqualToAnchor:self.surfaceView.leadingAnchor  constant:PPSpaceBase],
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
    self.surfaceView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.surfaceView.bounds
                                   cornerRadius:self.surfaceView.layer.cornerRadius].CGPath;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previous]) {
        self.surfaceView.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.28].CGColor;
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
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, assign) BOOL isExpanded;
@property (nonatomic, assign) PPHomeSection currentSection;
@property (nonatomic, assign) CFTimeInterval lastActionTimestamp;
@end

@implementation PPSectionHeaderView

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) { [self pp_buildUI]; }
    return self;
}

#pragma mark - Build UI

- (void)pp_buildUI {
    self.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = GM.setSemantic;

    // ── Surface card ──
    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.surfaceView.backgroundColor  = [AppForgroundColr colorWithAlphaComponent:0.55];
    self.surfaceView.layer.cornerRadius = PPCornerMedium;
    self.surfaceView.layer.cornerCurve  = kCACornerCurveContinuous;
    self.surfaceView.layer.borderWidth  = 0.33;
    self.surfaceView.layer.borderColor  = [AppForgroundColr colorWithAlphaComponent:0.68].CGColor;
    self.surfaceView.layer.shadowColor   = UIColor.blackColor.CGColor;
    self.surfaceView.layer.shadowOpacity = PPShadowCardOpacity;
    self.surfaceView.layer.shadowRadius  = PPShadowCardRadius;
    self.surfaceView.layer.shadowOffset  = CGSizeMake(0, PPShadowCardOffsetY);
    [self addSubview:self.surfaceView];
    [self sendSubviewToBack:self.surfaceView];

    // ── Tap gesture ──
    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_actionTapped)];
    tap.delegate = self;
    tap.cancelsTouchesInView = NO;
    [self addGestureRecognizer:tap];

    // ── Title ──
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font      = [GM boldFontWithSize:PPFontTitle2];
    _titleLabel.textColor = AppPrimaryTextClr;
    [self addSubview:_titleLabel];

    // ── Subtitle ──
    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font         = [GM MidFontWithSize:PPFontSubheadline];
    _subtitleLabel.textColor    = UIColor.secondaryLabelColor;
    _subtitleLabel.numberOfLines = 1;
    _subtitleLabel.hidden       = YES;
    [self addSubview:_subtitleLabel];

    // ── Action button ──
    [self pp_buildActionButton];
    [self addSubview:_actionButton];

    // ── Layout ──
    self.titleTopConstraint =
        [_titleLabel.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:PPSpaceXS];
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
        [_actionButton.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-PPSpaceXS],
        [_actionButton.centerYAnchor  constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        // Title
        [_titleLabel.leadingAnchor  constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:PPSpaceBase],
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_actionButton.leadingAnchor constant:-PPSpaceSM],
        // Subtitle
        [_subtitleLabel.leadingAnchor  constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subtitleLabel.topAnchor      constraintEqualToAnchor:_titleLabel.bottomAnchor constant:PPSpaceXXS],
        [_subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_actionButton.leadingAnchor constant:-PPSpaceSM],
    ]];
}

- (void)pp_buildActionButton {
    UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
    cfg.contentInsets = NSDirectionalEdgeInsetsMake(PPSpaceXS, PPSpaceSM, PPSpaceXS, PPSpaceSM);
    cfg.imagePadding  = 6;
    cfg.imagePlacement = NSDirectionalRectEdgeTrailing;

    UIImageSymbolConfiguration *symbolCfg =
        [UIImageSymbolConfiguration configurationWithPointSize:17
                                                        weight:UIImageSymbolWeightSemibold
                                                         scale:UIImageSymbolScaleMedium];
    UIImage *chevron = [UIImage systemImageNamed:@"chevron.down" withConfiguration:symbolCfg];
    if (@available(iOS 15.0, *)) {
        chevron = [chevron imageByApplyingSymbolConfiguration:
            [UIImageSymbolConfiguration configurationWithPaletteColors:@[
                UIColor.tertiaryLabelColor, AppPrimaryClr
            ]]];
    }
    cfg.image = chevron;

    cfg.titleTextAttributesTransformer =
    ^NSDictionary<NSAttributedStringKey,id> *(NSDictionary<NSAttributedStringKey,id> *attrs) {
        NSMutableDictionary *m = attrs.mutableCopy;
        m[NSFontAttributeName]            = [GM MidFontWithSize:PPFontSubheadline];
        m[NSForegroundColorAttributeName] = UIColor.secondaryLabelColor;
        return m;
    };

    cfg.background.backgroundColor = UIColor.clearColor;
    cfg.baseBackgroundColor        = UIColor.clearColor;

    _actionButton = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    _actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    _actionButton.hidden = YES;
    [_actionButton addTarget:self
                      action:@selector(pp_actionTapped)
            forControlEvents:UIControlEventTouchUpInside];
}

#pragma mark - Layout & Appearance

- (void)layoutSubviews {
    [super layoutSubviews];
    self.surfaceView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.surfaceView.bounds
                                   cornerRadius:self.surfaceView.layer.cornerRadius].CGPath;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previous]) {
        self.surfaceView.layer.borderColor =
            [UIColor.separatorColor colorWithAlphaComponent:0.28].CGColor;
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

    // Action button visibility
    BOOL showAction = (ppHomeSection == PPHomeSectionMainKinds || actionTitle.length > 0);
    self.actionButton.hidden = !showAction;

    if (actionTitle.length > 0) {
        [self.actionButton setTitle:actionTitle forState:UIControlStateNormal];
        self.actionButton.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    }

    // Custom icon for non-MainKinds sections
    if (iconName.length > 0 && ppHomeSection != PPHomeSectionMainKinds) {
        UIButtonConfiguration *cfg = self.actionButton.configuration;
        UIImage *symbol = [UIImage pp_symbolNamed:iconName
                                        pointSize:16
                                           weight:UIImageSymbolWeightSemibold
                                            scale:UIImageSymbolScaleMedium
                                          palette:@[UIColor.tertiaryLabelColor]
                                     makeTemplate:YES];
        if (@available(iOS 15.0, *)) {
            symbol = [symbol imageByApplyingSymbolConfiguration:
                [UIImageSymbolConfiguration configurationWithPaletteColors:@[UIColor.tertiaryLabelColor]]];
        }
        cfg.image          = symbol;
        cfg.imagePlacement = NSDirectionalRectEdgeLeading;
        cfg.imagePadding   = 6;
        self.actionButton.configuration = cfg;
    }

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

    self.surfaceView.layer.cornerRadius = PPCornerCard;

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

    // Reset chevron rotation
    self.actionButton.imageView.transform = CGAffineTransformIdentity;
}

#pragma mark - Actions

- (void)pp_actionTapped {
    CFTimeInterval now = CACurrentMediaTime();
    if ((now - self.lastActionTimestamp) < 0.25) { return; }
    self.lastActionTimestamp = now;

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
        [UIView animateWithDuration:PPAnimDurationNormal
                              delay:0
             usingSpringWithDamping:PPAnimSpringDamping
              initialSpringVelocity:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:rotate
                         completion:nil];
    } else {
        rotate();
    }
}

@end
