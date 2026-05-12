#import "PPSectionHeaderView.h"
#import <QuartzCore/QuartzCore.h>

@interface PPSectionHeaderView () <UIGestureRecognizerDelegate>

@property (nonatomic, strong, readwrite) UILabel *titleLabel;
@property (nonatomic, strong, readwrite) UILabel *subtitleLabel;
@property (nonatomic, strong, readwrite) UIButton *actionButton;

@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *accentRailView;
@property (nonatomic, strong) UIStackView *contentStackView;
@property (nonatomic, strong) UIStackView *textStackView;

@property (nonatomic, assign) BOOL isExpanded;
@property (nonatomic, assign) PPHomeSection currentSection;
@property (nonatomic, assign) CFTimeInterval lastActionTimestamp;

@end

@implementation PPSectionHeaderView

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self pp_buildUI];
    }
    return self;
}

#pragma mark - Build UI

- (void)pp_buildUI
{
    self.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.preservesSuperviewLayoutMargins = YES;
    self.isAccessibilityElement = NO;

    [self pp_buildSurface];
    [self pp_buildLabels];
    [self pp_buildActionButton];
    [self pp_buildStacks];
    [self pp_installTapGesture];
    [self pp_refreshAppearance];
}

- (void)pp_buildSurface
{
    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.surfaceView.userInteractionEnabled = YES;
    self.surfaceView.clipsToBounds = NO;
    self.surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    self.surfaceView.layer.cornerRadius = 18.0;
    self.surfaceView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    [self addSubview:self.surfaceView];

    self.accentRailView = [[UIView alloc] init];
    self.accentRailView.translatesAutoresizingMaskIntoConstraints = NO;
    self.accentRailView.userInteractionEnabled = NO;
    self.accentRailView.layer.cornerRadius = 1.25;
    self.accentRailView.layer.cornerCurve = kCACornerCurveContinuous;
    [self.surfaceView addSubview:self.accentRailView];

    [NSLayoutConstraint activateConstraints:@[
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4.0],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-4.0],
        [self.surfaceView.topAnchor constraintEqualToAnchor:self.topAnchor constant:2.0],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-2.0],

        [self.accentRailView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:14.0],
        [self.accentRailView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:14.0],
        [self.accentRailView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor constant:-14.0],
        [self.accentRailView.widthAnchor constraintEqualToConstant:2.5],
    ]];
}

- (void)pp_buildLabels
{
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [self pp_titleFont];
    self.titleLabel.textColor = [self pp_titleColor];
    self.titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.86;
    self.titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [self pp_subtitleFont];
    self.subtitleLabel.textColor = [self pp_subtitleColor];
    self.subtitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.subtitleLabel.numberOfLines = 2;
    self.subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.subtitleLabel.adjustsFontForContentSizeCategory = YES;
    self.subtitleLabel.hidden = YES;

    [self.titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.subtitleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
}

- (void)pp_buildActionButton
{
    self.actionButton = [UIButton buttonWithConfiguration:[self pp_baseActionButtonConfiguration]
                                            primaryAction:nil];
    self.actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionButton.hidden = YES;
    self.actionButton.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.actionButton.layer.cornerRadius = 15.0;
    self.actionButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.actionButton.clipsToBounds = YES;
    self.actionButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.actionButton.titleLabel.minimumScaleFactor = 0.84;
    self.actionButton.accessibilityTraits = UIAccessibilityTraitButton;
    [self.actionButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.actionButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.actionButton addTarget:self
                          action:@selector(pp_actionTapped)
                forControlEvents:UIControlEventTouchUpInside];

    [NSLayoutConstraint activateConstraints:@[
        [self.actionButton.heightAnchor constraintGreaterThanOrEqualToConstant:34.0],
        [self.actionButton.widthAnchor constraintGreaterThanOrEqualToConstant:38.0],
        [self.actionButton.widthAnchor constraintLessThanOrEqualToConstant:152.0],
    ]];
}

- (void)pp_buildStacks
{
    self.textStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.titleLabel,
        self.subtitleLabel,
    ]];
    self.textStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textStackView.axis = UILayoutConstraintAxisVertical;
    self.textStackView.alignment = UIStackViewAlignmentFill;
    self.textStackView.distribution = UIStackViewDistributionFill;
    self.textStackView.spacing = 2.0;
    self.textStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.textStackView setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    self.contentStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.textStackView,
        self.actionButton,
    ]];
    self.contentStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStackView.axis = UILayoutConstraintAxisHorizontal;
    self.contentStackView.alignment = UIStackViewAlignmentCenter;
    self.contentStackView.distribution = UIStackViewDistributionFill;
    self.contentStackView.spacing = 12.0;
    self.contentStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.surfaceView addSubview:self.contentStackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.contentStackView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:30.0],
        [self.contentStackView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-13.0],
        [self.contentStackView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.contentStackView.topAnchor constraintGreaterThanOrEqualToAnchor:self.surfaceView.topAnchor constant:8.0],
        [self.contentStackView.bottomAnchor constraintLessThanOrEqualToAnchor:self.surfaceView.bottomAnchor constant:-8.0],
    ]];
}

- (void)pp_installTapGesture
{
    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_actionTapped)];
    tap.delegate = self;
    tap.cancelsTouchesInView = NO;
    [self addGestureRecognizer:tap];
}

#pragma mark - Appearance

- (UIButtonConfiguration *)pp_baseActionButtonConfiguration
{
    UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
    cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    cfg.contentInsets = NSDirectionalEdgeInsetsMake(7.0, 12.0, 7.0, 12.0);
    cfg.imagePadding = 6.0;
    cfg.imagePlacement = NSDirectionalRectEdgeTrailing;
    cfg.baseForegroundColor = [self pp_accentColor];

    UIBackgroundConfiguration *background = [UIBackgroundConfiguration clearConfiguration];
    background.cornerRadius = 15.0;
    background.strokeWidth = 1.0 / UIScreen.mainScreen.scale;
    background.strokeColor = [[self pp_accentColor] colorWithAlphaComponent:[self pp_isDarkMode] ? 0.28 : 0.18];
    background.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:[self pp_isDarkMode] ? 0.13 : 0.09];
    cfg.background = background;

    UIImageSymbolConfiguration *symbolConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:12.5
                                                        weight:UIImageSymbolWeightSemibold
                                                         scale:UIImageSymbolScaleMedium];
    UIImage *chevron = [UIImage systemImageNamed:@"chevron.down" withConfiguration:symbolConfig];
    if (@available(iOS 15.0, *)) {
        chevron = [chevron imageByApplyingSymbolConfiguration:
                   [UIImageSymbolConfiguration configurationWithPaletteColors:@[[self pp_accentColor]]]];
    }
    cfg.image = chevron;

    __weak typeof(self) weakSelf = self;
    cfg.titleTextAttributesTransformer =
    ^NSDictionary<NSAttributedStringKey,id> *(NSDictionary<NSAttributedStringKey,id> *attrs) {
        __strong typeof(weakSelf) self = weakSelf;
        NSMutableDictionary *values = attrs.mutableCopy ?: [NSMutableDictionary dictionary];
        values[NSFontAttributeName] = [self pp_actionFont];
        values[NSForegroundColorAttributeName] = [self pp_accentColor];
        return values;
    };

    return cfg;
}

- (void)pp_refreshAppearance
{
    self.surfaceView.backgroundColor = [self pp_surfaceFillColor];
    self.surfaceView.layer.borderColor = [self pp_surfaceBorderColor].CGColor;
    self.surfaceView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.surfaceView.layer.shadowOpacity = [self pp_isDarkMode] ? 0.0 : 0.00;
    self.surfaceView.layer.shadowRadius =0.0;
    self.surfaceView.layer.shadowOffset = CGSizeMake(0.0, 0.0);
    
    //self.surfaceView.layer.shadowOpacity = [self pp_isDarkMode] ? 0.0 : 0.045;
    //self.surfaceView.layer.shadowRadius = 14.0;
    //self.surfaceView.layer.shadowOffset = CGSizeMake(0.0, 6.0);

    self.accentRailView.backgroundColor = [self pp_accentColor];
    self.titleLabel.textColor = [self pp_titleColor];
    self.subtitleLabel.textColor = [self pp_subtitleColor];

    UIButtonConfiguration *cfg = self.actionButton.configuration ?: [self pp_baseActionButtonConfiguration];
    UIBackgroundConfiguration *background = cfg.background ?: [UIBackgroundConfiguration clearConfiguration];
    background.strokeColor = [[self pp_accentColor] colorWithAlphaComponent:[self pp_isDarkMode] ? 0.28 : 0.18];
    background.backgroundColor = [[self pp_accentColor] colorWithAlphaComponent:[self pp_isDarkMode] ? 0.13 : 0.09];
    cfg.background = background;
    cfg.baseForegroundColor = [self pp_accentColor];
    self.actionButton.configuration = cfg;
}

- (UIColor *)pp_accentColor
{
    return AppPrimaryClr ?: UIColor.systemTealColor;
}

- (UIColor *)pp_titleColor
{
    return AppPrimaryTextClr ?: UIColor.labelColor;
}

- (UIColor *)pp_subtitleColor
{
    return AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
}

- (UIColor *)pp_surfaceFillColor
{
    if ([self pp_isDarkMode]) {
        return [UIColor colorWithWhite:1.0 alpha:0.045];
    }
   
    
    UIColor *baseColor = AppBackgroundClr ?: UIColor.secondarySystemGroupedBackgroundColor;
    return [baseColor colorWithAlphaComponent:1.0];
}

- (UIColor *)pp_surfaceBorderColor
{
    if ([self pp_isDarkMode]) {
        return [UIColor colorWithWhite:1.0 alpha:0.08];
    }
    UIColor *accent = [self pp_accentColor];
    if (self.currentSection == PPHomeSectionMainKinds) {
        return [accent colorWithAlphaComponent:0.075];
    }
    return [accent colorWithAlphaComponent:0.08];
}

- (UIFont *)pp_titleFont
{
    UIFont *font = [GM boldFontWithSize:18.5] ?: [UIFont systemFontOfSize:18.5 weight:UIFontWeightBold];
    return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline] scaledFontForFont:font];
}

- (UIFont *)pp_subtitleFont
{
    UIFont *font = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:font];
}

- (UIFont *)pp_actionFont
{
    UIFont *font = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1] scaledFontForFont:font];
}

- (BOOL)pp_isDarkMode
{
    return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
}

#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.surfaceView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.surfaceView.bounds
                                   cornerRadius:self.surfaceView.layer.cornerRadius].CGPath;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self pp_refreshAppearance];
    }
}

#pragma mark - Public

- (void)hide
{
    self.actionButton.hidden = YES;
    [self pp_updateAccessibility];
}

#pragma mark - Configuration

- (void)configureWithTitle:(nullable NSString *)title
               actionTitle:(nullable NSString *)actionTitle
                  iconName:(nullable NSString *)iconName
                      menu:(nullable UIMenu *)menu
             ppHomeSection:(PPHomeSection)ppHomeSection
{
    self.currentSection = ppHomeSection;
    self.titleLabel.text = title;
    self.subtitleLabel.text = nil;
    self.subtitleLabel.hidden = YES;
    [self pp_applySemanticDirection];

    self.actionButton.configuration = [self pp_baseActionButtonConfiguration];
    self.actionButton.imageView.transform = CGAffineTransformIdentity;

    BOOL showAction = (ppHomeSection == PPHomeSectionMainKinds ||
                       actionTitle.length > 0 ||
                       menu != nil);
    self.actionButton.hidden = !showAction;

    UIButtonConfiguration *cfg = self.actionButton.configuration;
    cfg.title = actionTitle.length > 0 ? actionTitle : @"";
    cfg = [self pp_applyIconNamed:iconName
                 toConfiguration:cfg
                      forSection:ppHomeSection];
    self.actionButton.configuration = cfg;

    [self pp_configureMenu:menu];
    [self pp_refreshAppearance];
    [self pp_updateAccessibility];

    if (ppHomeSection == PPHomeSectionMainKinds) {
        [self pp_setExpanded:self.isExpanded animated:NO];
    }

    [self setNeedsLayout];
}

- (void)configureWithTitle:(nullable NSString *)title
                  subtitle:(nullable NSString *)subtitle
               actionTitle:(nullable NSString *)actionTitle
                  iconName:(nullable NSString *)iconName
                      menu:(nullable UIMenu *)menu
             ppHomeSection:(PPHomeSection)ppHomeSection
{
    [self configureWithTitle:title
                 actionTitle:actionTitle
                    iconName:iconName
                        menu:menu
               ppHomeSection:ppHomeSection];

    BOOL hasSubtitle = subtitle.length > 0;
    self.subtitleLabel.text = hasSubtitle ? subtitle : nil;
    self.subtitleLabel.hidden = !hasSubtitle;
    self.textStackView.spacing = hasSubtitle ? 2.0 : 0.0;
    [self pp_updateAccessibility];
    [self setNeedsLayout];
}

- (UIButtonConfiguration *)pp_applyIconNamed:(nullable NSString *)iconName
                             toConfiguration:(UIButtonConfiguration *)configuration
                                  forSection:(PPHomeSection)section
{
    UIButtonConfiguration *cfg = configuration;
    UIImage *image = nil;

    if (iconName.length > 0) {
        image = [UIImage pp_symbolNamed:iconName
                              pointSize:12.5
                                 weight:UIImageSymbolWeightSemibold
                                  scale:UIImageSymbolScaleMedium
                                palette:@[[self pp_accentColor]]
                           makeTemplate:YES];
    } else if (section == PPHomeSectionMainKinds) {
        UIImageSymbolConfiguration *symbolConfig =
            [UIImageSymbolConfiguration configurationWithPointSize:12.5
                                                            weight:UIImageSymbolWeightSemibold
                                                             scale:UIImageSymbolScaleMedium];
        image = [UIImage systemImageNamed:@"chevron.down" withConfiguration:symbolConfig];
    }

    cfg.image = image;
    cfg.imagePadding = image ? 6.0 : 0.0;
    cfg.imagePlacement = section == PPHomeSectionMainKinds ? NSDirectionalRectEdgeTrailing : NSDirectionalRectEdgeLeading;

    if (cfg.title.length == 0 && image) {
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(8.0, 10.0, 8.0, 10.0);
    }

    return cfg;
}

- (void)pp_configureMenu:(nullable UIMenu *)menu
{
    if (menu) {
        self.actionButton.menu = menu;
        self.actionButton.showsMenuAsPrimaryAction = YES;
        [PPMenuHelper presentMenuFromButton:self.actionButton
                                       Menu:menu
                                destructive:nil
                                    handler:^(NSInteger idx, NSString *t) { }];
    } else {
        self.actionButton.menu = nil;
        self.actionButton.showsMenuAsPrimaryAction = NO;
    }
}

- (void)pp_applySemanticDirection
{
    UISemanticContentAttribute semantic = [Language semanticAttributeForCurrentLanguage];
    NSTextAlignment alignment = [Language alignmentForCurrentLanguage];

    self.semanticContentAttribute = semantic;
    self.surfaceView.semanticContentAttribute = semantic;
    self.contentStackView.semanticContentAttribute = semantic;
    self.textStackView.semanticContentAttribute = semantic;
    self.actionButton.semanticContentAttribute = semantic;
    self.titleLabel.textAlignment = alignment;
    self.subtitleLabel.textAlignment = alignment;
}

#pragma mark - Reuse

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.subtitleLabel.hidden = YES;
    self.textStackView.spacing = 0.0;
    self.actionButton.hidden = YES;
    self.actionButton.menu = nil;
    self.actionButton.showsMenuAsPrimaryAction = NO;
    self.actionButton.configuration = [self pp_baseActionButtonConfiguration];
    self.actionButton.imageView.transform = CGAffineTransformIdentity;
    self.surfaceView.transform = CGAffineTransformIdentity;
    self.onTap = nil;
    self.onTapMenu = nil;
    self.lastActionTimestamp = 0;
    [self pp_updateAccessibility];
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    [super applyLayoutAttributes:layoutAttributes];
    [self setNeedsLayout];
}

#pragma mark - Actions

- (void)pp_actionTapped
{
    CFTimeInterval now = CACurrentMediaTime();
    if ((now - self.lastActionTimestamp) < 0.22) {
        return;
    }
    self.lastActionTimestamp = now;

    [self pp_animatePressFeedback];

    if (self.currentSection != PPHomeSectionMainKinds) {
        if (self.onTap) {
            self.onTap();
        }
        return;
    }

    [PPFunc triggerMediumHaptic];
    self.isExpanded = !self.isExpanded;
    [self pp_setExpanded:self.isExpanded animated:YES];

    if (self.onTap) {
        self.onTap();
    }
}

- (void)pp_animatePressFeedback
{
    [UIView animateWithDuration:0.08
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.surfaceView.transform = CGAffineTransformMakeScale(0.992, 0.992);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.22
                              delay:0
             usingSpringWithDamping:0.78
              initialSpringVelocity:0.35
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.surfaceView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(UITouch *)touch
{
    (void)gestureRecognizer;
    UIView *hitView = touch.view;
    while (hitView) {
        if (hitView == self.actionButton) {
            return NO;
        }
        hitView = hitView.superview;
    }
    return YES;
}

#pragma mark - Expand / Collapse

- (void)pp_setExpanded:(BOOL)expanded animated:(BOOL)animated
{
    _isExpanded = expanded;

    if (self.currentSection != PPHomeSectionMainKinds) {
        self.actionButton.imageView.transform = CGAffineTransformIdentity;
        return;
    }

    CGFloat angle = expanded ? M_PI : 0.0;
    void (^updates)(void) = ^{
        self.actionButton.imageView.transform = CGAffineTransformMakeRotation(angle);
    };

    if (animated) {
        [UIView animateWithDuration:0.34
                              delay:0
             usingSpringWithDamping:0.76
              initialSpringVelocity:0.55
                            options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                         animations:updates
                         completion:nil];
    } else {
        updates();
    }
}

#pragma mark - Accessibility

- (void)pp_updateAccessibility
{
    NSString *title = self.titleLabel.text ?: @"";
    NSString *subtitle = self.subtitleLabel.hidden ? @"" : (self.subtitleLabel.text ?: @"");
    NSString *actionTitle = self.actionButton.configuration.title ?: @"";

    self.titleLabel.accessibilityLabel = title;
    self.subtitleLabel.accessibilityLabel = subtitle;
    self.actionButton.accessibilityLabel = actionTitle.length > 0 ? actionTitle : title;
    self.actionButton.accessibilityHint = nil;

    if (self.currentSection == PPHomeSectionMainKinds) {
        self.actionButton.accessibilityTraits = UIAccessibilityTraitButton;
        self.actionButton.accessibilityValue = self.isExpanded ? kLang(@"ShowLess") : kLang(@"ShowAll");
    }
}

@end
