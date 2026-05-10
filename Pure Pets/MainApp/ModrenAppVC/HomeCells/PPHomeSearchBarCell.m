//
//  PPHomeSearchBarCell.m
//  Pure Pets
//
//  Premium minimal search bar. One glass pill. One icon. One statement.
//  Quiet authority through restraint — no chips, no signals, no decoration.
//

#import "PPHomeSearchBarCell.h"
#import <QuartzCore/QuartzCore.h>

static inline UISemanticContentAttribute _PPHSSCSemantic(void) {
    return [Language semanticAttributeForCurrentLanguage];
}

static inline NSTextAlignment _PPHSSCAlignment(void) {
    return [Language alignmentForCurrentLanguage];
}

static CGFloat const kChromeCornerRadius = 22.0;
static CGFloat const kChromeHeight       = 44.0;
static CGFloat const kIconSize           = 16.0;
static CGFloat const kContentPadding     = PPSpaceBase;
static CGFloat const kIconToLabelSpacing = PPSpaceSM;

// Premium easing: cubic-bezier(0.4, 0, 0.2, 1) — Apple HIG deceleration
static CGFloat const kEaseP1X = 0.4;
static CGFloat const kEaseP1Y = 0.0;
static CGFloat const kEaseP2X = 0.2;
static CGFloat const kEaseP2Y = 1.0;

// Entrance
static NSTimeInterval const kEntranceDuration  = 0.46;
static NSTimeInterval const kEntranceDelay     = 0.18;
static CGFloat        const kEntranceDamping   = 0.78;
static CGFloat        const kEntranceVelocity  = 0.14;
static CGFloat        const kEntranceOffsetY   = -14.0;

// Text transition
static NSTimeInterval const kFadeOutDuration = 0.14;
static NSTimeInterval const kSettleInDuration = 0.32;
static CGFloat        const kSettleDamping   = 0.84;
static CGFloat        const kSettleVelocity  = 0.18;
static CGFloat        const kTextRiseOffset   = 6.0;

// Press feedback
static NSTimeInterval const kPressDownDuration = 0.10;
static NSTimeInterval const kPressUpDuration   = 0.22;
static CGFloat        const kPressScale        = 0.975;
static CGFloat        const kPressAlpha        = 0.94;

@implementation PPHomeSearchBarCell {
    UIView *_chromeView;
    UIImageView *_searchIconView;
    UILabel *_placeholderLabel;
    UIButton *_tapButton;
    NSUInteger _transitionGeneration;
    BOOL _didPerformEntrance;
}

#pragma mark - Lifecycle

+ (NSString *)reuseIdentifier {
    return @"PPHomeSearchBarCell";
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    [self pp_buildInterface];
    return self;
}

#pragma mark - Build

- (void)pp_buildInterface {
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds = NO;
    self.clipsToBounds = NO;
    self.semanticContentAttribute = _PPHSSCSemantic();
    self.contentView.semanticContentAttribute = _PPHSSCSemantic();
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton | UIAccessibilityTraitSearchField;

    // --- Chrome surface ---
    UIView *chromeView = [[UIView alloc] init];
    chromeView.translatesAutoresizingMaskIntoConstraints = NO;
    chromeView.userInteractionEnabled = NO;
    chromeView.clipsToBounds = NO;
    chromeView.layer.cornerRadius = kChromeCornerRadius;
    if (@available(iOS 13.0, *)) {
        chromeView.layer.cornerCurve = kCACornerCurveContinuous;
        chromeView.layer.masksToBounds = NO;
    }
    [self.contentView addSubview:chromeView];
    _chromeView = chromeView;

    // Glass blur background
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.userInteractionEnabled = NO;
    blurView.clipsToBounds = YES;
    blurView.layer.cornerRadius = kChromeCornerRadius;
    if (@available(iOS 13.0, *)) {
        blurView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [chromeView addSubview:blurView];

    // --- Search icon ---
    UIImage *iconImage = [UIImage pp_symbolNamed:@"magnifyingglass"
                                       pointSize:kIconSize
                                          weight:UIImageSymbolWeightMedium
                                           scale:UIImageSymbolScaleMedium
                                         palette:@[AppSecondaryTextClr ?: UIColor.secondaryLabelColor]
                                    makeTemplate:YES];
    UIImageView *searchIconView = [[UIImageView alloc] initWithImage:iconImage];
    searchIconView.translatesAutoresizingMaskIntoConstraints = NO;
    searchIconView.contentMode = UIViewContentModeScaleAspectFit;
    searchIconView.userInteractionEnabled = NO;
    [chromeView addSubview:searchIconView];
    _searchIconView = searchIconView;

    // --- Placeholder label ---
    UILabel *placeholderLabel = [UILabel new];
    placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    placeholderLabel.font = [GM boldFontWithSize:PPFontSubheadline]
        ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    placeholderLabel.textAlignment = _PPHSSCAlignment();
    placeholderLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    placeholderLabel.numberOfLines = 1;
    placeholderLabel.userInteractionEnabled = NO;
    [chromeView addSubview:placeholderLabel];
    _placeholderLabel = placeholderLabel;

    // --- Tap overlay ---
    _tapButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _tapButton.translatesAutoresizingMaskIntoConstraints = NO;
    _tapButton.backgroundColor = UIColor.clearColor;
    [_tapButton addTarget:self action:@selector(pp_handleTap) forControlEvents:UIControlEventTouchUpInside];
    [_tapButton addTarget:self action:@selector(pp_handleTouchDown) forControlEvents:UIControlEventTouchDown];
    [_tapButton addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchUpInside];
    [_tapButton addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchUpOutside];
    [_tapButton addTarget:self action:@selector(pp_handleTouchUp) forControlEvents:UIControlEventTouchCancel];
    [self.contentView addSubview:_tapButton];

    // --- Layout ---
    [NSLayoutConstraint activateConstraints:@[
        // Tap button covers entire cell
        [_tapButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [_tapButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_tapButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_tapButton.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        // Blur fills chrome
        [blurView.topAnchor constraintEqualToAnchor:chromeView.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:chromeView.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:chromeView.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:chromeView.bottomAnchor],

        // Chrome height + vertical margins
        [chromeView.heightAnchor constraintEqualToConstant:kChromeHeight],
        [chromeView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:PPSpaceXS],
        [chromeView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [chromeView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [chromeView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-PPSpaceXS],

        // Icon: leading + center-Y
        [_searchIconView.leadingAnchor constraintEqualToAnchor:chromeView.leadingAnchor constant:kContentPadding],
        [_searchIconView.centerYAnchor constraintEqualToAnchor:chromeView.centerYAnchor],
        [_searchIconView.widthAnchor constraintEqualToConstant:kIconSize],
        [_searchIconView.heightAnchor constraintEqualToConstant:kIconSize],

        // Label: trailing + center-Y
        [_placeholderLabel.leadingAnchor constraintEqualToAnchor:_searchIconView.trailingAnchor constant:kIconToLabelSpacing],
        [_placeholderLabel.trailingAnchor constraintEqualToAnchor:chromeView.trailingAnchor constant:-kContentPadding],
        [_placeholderLabel.centerYAnchor constraintEqualToAnchor:chromeView.centerYAnchor],
    ]];

    [_placeholderLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [_searchIconView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    [self pp_applyPalette];
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    // Shadow path for performance
    if (CGRectGetWidth(_chromeView.bounds) > 0) {
        _chromeView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_chromeView.bounds
                                                                   cornerRadius:kChromeCornerRadius].CGPath;
    }
}

#pragma mark - Configuration

- (void)configureWithTrendingQuery:(NSString *)query {
    [self pp_applySearchPlaceholderText:query animated:YES];
}

- (void)setQueryText:(NSString *)text animated:(BOOL)animated {
    [self pp_applySearchPlaceholderText:text animated:animated];
}

#pragma mark - Placeholder text

- (NSString *)pp_defaultPlaceholder {
    return kLang(@"home_nav_search_base_placeholder") ?: @"What does your pet need today?";
}

- (void)pp_applySearchPlaceholderText:(NSString *)text animated:(BOOL)animated {
    NSString *safeText = PPSafeString(text);
    if (safeText.length == 0) {
        safeText = [self pp_defaultPlaceholder];
    }
    self.accessibilityValue = safeText;
    self.accessibilityHint = kLang(@"home_search_hint") ?: @"What are you looking for?";
    self.accessibilityLabel = kLang(@"home_nav_search_accessibility") ?: @"Open smart search";

    if ([_placeholderLabel.text isEqualToString:safeText]) return;

    if (!animated || UIAccessibilityIsReduceMotionEnabled() || !self.window) {
        _transitionGeneration++;
        _placeholderLabel.text = safeText;
        _placeholderLabel.alpha = 1.0;
        _placeholderLabel.transform = CGAffineTransformIdentity;
        return;
    }

    [self pp_performPlaceholderTransitionToText:safeText];
}

- (void)pp_performPlaceholderTransitionToText:(NSString *)safeText {
    _transitionGeneration++;
    NSUInteger generation = _transitionGeneration;

    [UIView animateWithDuration:kFadeOutDuration
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self->_placeholderLabel.alpha = 0.0;
    } completion:^(__unused BOOL finished) {
        if (generation != self->_transitionGeneration) return;

        self->_placeholderLabel.text = safeText;
        self->_placeholderLabel.transform = CGAffineTransformMakeTranslation(0.0, kTextRiseOffset);

        [UIView animateWithDuration:kSettleInDuration
                              delay:0.0
             usingSpringWithDamping:kSettleDamping
              initialSpringVelocity:kSettleVelocity
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self->_placeholderLabel.transform = CGAffineTransformIdentity;
            self->_placeholderLabel.alpha = 1.0;
        } completion:nil];
    }];
}

#pragma mark - Interaction

- (void)pp_handleTap {
    if (self.onTap) self.onTap();
}

- (void)pp_handleTouchDown {
    [self pp_applyPressedState:YES animated:YES];
}

- (void)pp_handleTouchUp {
    [self pp_applyPressedState:NO animated:YES];
}

- (void)pp_applyPressedState:(BOOL)pressed animated:(BOOL)animated {
    CGFloat targetScale = pressed ? kPressScale : 1.0;
    CGFloat targetAlpha = pressed ? kPressAlpha : 1.0;
    CGFloat targetShadowOpacity = pressed ? 0.04 : 0.08;

    void (^changes)(void) = ^{
        self->_chromeView.transform = CGAffineTransformMakeScale(targetScale, targetScale);
        self->_chromeView.alpha = targetAlpha;
        self->_chromeView.layer.shadowOpacity = targetShadowOpacity;
    };

    if (!animated) { changes(); return; }

    NSTimeInterval duration = pressed ? kPressDownDuration : kPressUpDuration;
    if (pressed) {
        [UIView animateWithDuration:duration
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState
                         animations:changes completion:nil];
    } else {
        [UIView animateWithDuration:duration
                              delay:0.0
             usingSpringWithDamping:0.80
              initialSpringVelocity:0.22
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:changes completion:nil];
    }
}

#pragma mark - Palette

- (void)pp_applyPalette {
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *brand = AppPrimaryClr ?: UIColor.systemOrangeColor;

    // Glass surface: thin material + whisper of brand
    _chromeView.backgroundColor = [UIColor clearColor];

    // Border: subtle brand presence
    _chromeView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    UIColor *borderColor = isDark
        ? [brand colorWithAlphaComponent:0.10]
        : [brand colorWithAlphaComponent:0.08];
    if (@available(iOS 13.0, *)) {
        borderColor = [borderColor resolvedColorWithTraitCollection:self.traitCollection];
    }
    _chromeView.layer.borderColor = borderColor.CGColor;

    // Shadow: soft luxury with brand warmth
    _chromeView.layer.shadowColor = brand.CGColor;
    _chromeView.layer.shadowOpacity = 0.08;
    _chromeView.layer.shadowRadius = 20.0;
    _chromeView.layer.shadowOffset = CGSizeMake(0.0, 6.0);

    // Icon: muted secondary, warm in dark
    _searchIconView.tintColor = [AppSecondaryTextClr colorWithAlphaComponent:isDark ? 0.64 : 0.54];

    // Text: primary with quiet authority
    _placeholderLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:isDark ? 0.88 : 0.78];
}

- (void)tintColorDidChange {
    [super tintColorDidChange];
    [self pp_applyPalette];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self pp_applyPalette];
    }
}

#pragma mark - Entrance

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window && !_didPerformEntrance) {
        [self pp_performEntrance];
    }
}

- (void)pp_performEntrance {
    if (_didPerformEntrance) return;
    if (CGRectGetWidth(self.bounds) <= 0.0) return;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        _didPerformEntrance = YES;
        return;
    }
    _didPerformEntrance = YES;

    _chromeView.transform = CGAffineTransformMakeTranslation(0.0, kEntranceOffsetY);
    _chromeView.alpha = 0.0;

    [UIView animateWithDuration:kEntranceDuration
                          delay:kEntranceDelay
         usingSpringWithDamping:kEntranceDamping
          initialSpringVelocity:kEntranceVelocity
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self->_chromeView.transform = CGAffineTransformIdentity;
        self->_chromeView.alpha = 1.0;
    } completion:nil];
}

#pragma mark - Reuse

- (void)prepareForReuse {
    [super prepareForReuse];
    self.onTap = nil;
    _transitionGeneration++;
    _didPerformEntrance = NO;
    _chromeView.transform = CGAffineTransformIdentity;
    _chromeView.alpha = 1.0;
    _chromeView.layer.shadowOpacity = 0.08;
    _placeholderLabel.text = [self pp_defaultPlaceholder];
    _placeholderLabel.transform = CGAffineTransformIdentity;
    _placeholderLabel.alpha = 1.0;
    [self pp_applyPalette];
}

@end
