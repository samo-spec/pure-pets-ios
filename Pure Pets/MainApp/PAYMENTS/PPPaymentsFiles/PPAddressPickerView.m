//
//  PPAddressPickerView.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 03/02/2026.
//

#import "PPAddressPickerView.h"

typedef NS_ENUM(NSUInteger, PPAddressPickerState) {
    PPAddressPickerStateCollapsed,
    PPAddressPickerStateExpanded
};

static CGFloat const PPAddressPickerCollapsedSize = 64.0;
static CGFloat const PPAddressPickerExpandedHeight = 64.0;
static CGFloat const PPAddressPickerIconPlateSize = 42.0;

static UIColor *PPAddressPickerBrandColor(void)
{
    return AppPrimaryClr ?: [UIColor systemOrangeColor];
}

static UIColor *PPAddressPickerSurfaceColor(void)
{
    return AppSurfColor ?: [UIColor secondarySystemBackgroundColor];
}

static UIColor *PPAddressPickerStrokeColor(void)
{
    return [UIColor ppSurfaceBorder] ?: [UIColor separatorColor];
}

static UIColor *PPAddressPickerPrimaryTextColor(void)
{
    return AppPrimaryTextClr ?: [UIColor labelColor];
}

static UIColor *PPAddressPickerSecondaryTextColor(void)
{
    return AppSecondaryTextClr ?: [UIColor secondaryLabelColor];
}

@interface PPAddressPickerView ()

@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *tintView;
@property (nonatomic, strong) UIView *iconPlateView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UIView *statusDotView;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UILabel *addressLabel;
@property (nonatomic, strong) UIView *actionChipView;
@property (nonatomic, strong) UILabel *actionTitleLabel;
@property (nonatomic, strong) UIImageView *actionChevronView;
@property (nonatomic, strong) UIStackView *actionStack;
@property (nonatomic, strong) UIStackView *textStack;
@property (nonatomic, strong) UIStackView *contentStack;

@property (nonatomic) PPAddressPickerState state;
@property (nonatomic, strong) NSLayoutConstraint *widthConstraintCircle;
@property (nonatomic, strong) NSLayoutConstraint *widthConstraintFull;
@property (nonatomic, strong) NSLayoutConstraint *heightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *trailingConstraint;
@property (nonatomic, assign) CGFloat preferredExpandedWidth;
@property (nonatomic, assign) BOOL isCollapseDisabled;

- (void)pp_updateMetrics;
- (void)pp_refreshAppearance;

@end

@implementation PPAddressPickerView

#pragma mark - Public Factory

+ (instancetype)showInViewController:(UIViewController *)controller width:(float)width
{
    PPAddressPickerView *view = [[PPAddressPickerView alloc] init];
    view.preferredExpandedWidth = MAX(width, PPAddressPickerCollapsedSize);
    [controller.view addSubview:view];

    view.translatesAutoresizingMaskIntoConstraints = NO;

    NSLayoutConstraint *height =
        [view.heightAnchor constraintEqualToConstant:PPAddressPickerExpandedHeight];
    NSLayoutConstraint *trailing =
        [view.trailingAnchor constraintEqualToAnchor:controller.view.trailingAnchor constant:-PPSpaceBase];
    NSLayoutConstraint *top =
        [view.topAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.topAnchor constant:PPSpaceMD];

    [NSLayoutConstraint activateConstraints:@[
        trailing,
        top,
        height
    ]];

    view.topConstraint = top;
    view.heightConstraint = height;
    view.widthConstraintCircle = [view.widthAnchor constraintEqualToConstant:PPAddressPickerCollapsedSize];
    view.widthConstraintFull = [view.widthAnchor constraintEqualToConstant:view.preferredExpandedWidth];
    view.trailingConstraint = trailing;
    [view pp_updateMetrics];
    view.widthConstraintCircle.active = YES;
    view.widthConstraintFull.active = NO;
    [view pp_applyStateAnimated:NO];

    return view;
}

#pragma mark - Init

- (instancetype)init
{
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;

    self.isCollapseDisabled = NO;
    self.state = PPAddressPickerStateCollapsed;
    self.clipsToBounds = NO;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;

    [self buildUI];
    [self setupGesture];
    [self pp_updateMetrics];
    [self pp_refreshAppearance];

    return self;
}

#pragma mark - Helpers & Placeholders

- (NSString *)pp_addressPlaceholderText
{
    NSString *value = kLang(@"PleaseSelectDeliveryLocation");
    if (![value isKindOfClass:NSString.class] || value.length == 0 || [value isEqualToString:@"PleaseSelectDeliveryLocation"]) {
        value = kLang(@"SelectAddress");
    }
    if (![value isKindOfClass:NSString.class] || value.length == 0 || [value isEqualToString:@"SelectAddress"]) {
        value = @"Select address";
    }
    return value;
}

- (BOOL)pp_hasSelectedAddress
{
    if (!_addressText || _addressText.length == 0) {
        return NO;
    }
    NSString *placeholder = [self pp_addressPlaceholderText];
    return ![_addressText isEqualToString:placeholder];
}

#pragma mark - UI Construction

- (void)buildUI
{
    self.containerView = [[UIView alloc] init];
    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.containerView, PPCornerCard);
    self.containerView.clipsToBounds = YES;
    [self addSubview:self.containerView];

    UIBlurEffectStyle blurStyle = UIBlurEffectStyleExtraLight;
    if (@available(iOS 13.0, *)) {
        blurStyle = UIBlurEffectStyleSystemUltraThinMaterial;
    }
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:blurStyle];
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerView addSubview:self.blurView];

    self.tintView = [[UIView alloc] init];
    self.tintView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tintView.userInteractionEnabled = NO;
    [self.blurView.contentView addSubview:self.tintView];

    // Leading Icon Squircle Plate
    self.iconPlateView = [[UIView alloc] init];
    self.iconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.iconPlateView, PPCorner16);
    self.iconPlateView.layer.masksToBounds = YES;

    UIImage *icon = [[UIImage imageNamed:@"fast-delivery"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    if (!icon) {
        if (@available(iOS 13.0, *)) {
            icon = [[UIImage systemImageNamed:@"location.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
    }
    self.iconView = [[UIImageView alloc] initWithImage:icon];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.iconPlateView addSubview:self.iconView];

    // Verified / Status Indicator Dot
    self.statusDotView = [[UIView alloc] init];
    self.statusDotView.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusDotView.layer.cornerRadius = 4.0;
    self.statusDotView.layer.masksToBounds = YES;
    self.statusDotView.layer.borderWidth = 1.5;
    [self.containerView addSubview:self.statusDotView];

    // Top Row Meta Hint ("Deliver To" / "توصيل الي")
    self.hintLabel = [[UILabel alloc] init];
    self.hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *hintBaseFont = [GM MidFontWithSize:PPFontCaption1]
        ?: [UIFont systemFontOfSize:PPFontCaption1 weight:UIFontWeightMedium];
    self.hintLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1]
        scaledFontForFont:hintBaseFont
        maximumPointSize:17.0];
    self.hintLabel.adjustsFontForContentSizeCategory = YES;
    self.hintLabel.text = kLang(@"DeliverTo");
    self.hintLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.hintLabel.numberOfLines = 1;
    self.hintLabel.adjustsFontSizeToFitWidth = NO;

    // Main Address Headline
    self.addressLabel = [[UILabel alloc] init];
    self.addressLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *addressBaseFont = [GM boldFontWithSize:PPFontHeadline]
        ?: [UIFont systemFontOfSize:PPFontHeadline weight:UIFontWeightSemibold];
    self.addressLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline]
        scaledFontForFont:addressBaseFont
        maximumPointSize:24.0];
    self.addressLabel.adjustsFontForContentSizeCategory = YES;
    self.addressLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.addressLabel.numberOfLines = 0;
    self.addressLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.addressLabel.adjustsFontSizeToFitWidth = NO;
    self.addressLabel.text = [self pp_addressPlaceholderText];

    // Trailing Action Pill / Chip
    self.actionChipView = [[UIView alloc] init];
    self.actionChipView.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.actionChipView, PPCornerSmall);
    self.actionChipView.userInteractionEnabled = NO;

    self.actionTitleLabel = [[UILabel alloc] init];
    self.actionTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *actionFont = [GM MidFontWithSize:PPFontCaption1]
        ?: [UIFont systemFontOfSize:PPFontCaption1 weight:UIFontWeightMedium];
    self.actionTitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1]
        scaledFontForFont:actionFont
        maximumPointSize:16.0];
    self.actionTitleLabel.adjustsFontForContentSizeCategory = YES;
    self.actionTitleLabel.text = kLang(@"Change");
    self.actionTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.actionTitleLabel.numberOfLines = 1;

    UIImage *chevronImage = nil;
    if (@available(iOS 13.0, *)) {
        chevronImage = [UIImage systemImageNamed:@"chevron.forward"];
        if (!chevronImage) {
            chevronImage = [UIImage systemImageNamed:@"chevron.right"];
        }
    }
    self.actionChevronView = [[UIImageView alloc] initWithImage:chevronImage];
    self.actionChevronView.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionChevronView.contentMode = UIViewContentModeScaleAspectFit;

    self.actionStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.actionTitleLabel,
        self.actionChevronView
    ]];
    self.actionStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionStack.axis = UILayoutConstraintAxisHorizontal;
    self.actionStack.alignment = UIStackViewAlignmentCenter;
    self.actionStack.distribution = UIStackViewDistributionFill;
    self.actionStack.spacing = PPSpaceXS;
    self.actionStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.actionChipView addSubview:self.actionStack];

    // Center Text Stack
    self.textStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.hintLabel,
        self.addressLabel
    ]];
    self.textStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.textStack.axis = UILayoutConstraintAxisVertical;
    self.textStack.alignment = UIStackViewAlignmentFill;
    self.textStack.distribution = UIStackViewDistributionFill;
    self.textStack.spacing = PPSpaceXXS;

    // Main Horizontal Content Stack
    self.contentStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.iconPlateView,
        self.textStack,
        self.actionChipView
    ]];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisHorizontal;
    self.contentStack.alignment = UIStackViewAlignmentCenter;
    self.contentStack.distribution = UIStackViewDistributionFill;
    self.contentStack.spacing = PPSpaceMD;
    self.contentStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.blurView.contentView addSubview:self.contentStack];

    [self.textStack setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.textStack setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.iconPlateView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.iconPlateView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.actionChipView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.actionChipView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    [NSLayoutConstraint activateConstraints:@[
        [self.containerView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.containerView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.containerView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.containerView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],

        [self.blurView.topAnchor constraintEqualToAnchor:self.containerView.topAnchor],
        [self.blurView.bottomAnchor constraintEqualToAnchor:self.containerView.bottomAnchor],
        [self.blurView.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor],
        [self.blurView.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor],

        [self.tintView.topAnchor constraintEqualToAnchor:self.blurView.contentView.topAnchor],
        [self.tintView.bottomAnchor constraintEqualToAnchor:self.blurView.contentView.bottomAnchor],
        [self.tintView.leadingAnchor constraintEqualToAnchor:self.blurView.contentView.leadingAnchor],
        [self.tintView.trailingAnchor constraintEqualToAnchor:self.blurView.contentView.trailingAnchor],

        [self.contentStack.centerYAnchor constraintEqualToAnchor:self.blurView.contentView.centerYAnchor],
        [self.contentStack.topAnchor constraintGreaterThanOrEqualToAnchor:self.blurView.contentView.topAnchor constant:PPSpaceSM],
        [self.contentStack.bottomAnchor constraintLessThanOrEqualToAnchor:self.blurView.contentView.bottomAnchor constant:-PPSpaceSM],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.blurView.contentView.leadingAnchor constant:PPSpaceMD],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.blurView.contentView.trailingAnchor constant:-PPSpaceMD],

        [self.iconPlateView.widthAnchor constraintEqualToConstant:PPAddressPickerIconPlateSize],
        [self.iconPlateView.heightAnchor constraintEqualToConstant:PPAddressPickerIconPlateSize],

        [self.iconView.centerXAnchor constraintEqualToAnchor:self.iconPlateView.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:self.iconPlateView.centerYAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:24.0],
        [self.iconView.heightAnchor constraintEqualToConstant:24.0],

        [self.statusDotView.widthAnchor constraintEqualToConstant:8.0],
        [self.statusDotView.heightAnchor constraintEqualToConstant:8.0],
        [self.statusDotView.topAnchor constraintEqualToAnchor:self.iconPlateView.topAnchor constant:1.0],
        [self.statusDotView.trailingAnchor constraintEqualToAnchor:self.iconPlateView.trailingAnchor constant:-1.0],

        [self.actionStack.topAnchor constraintEqualToAnchor:self.actionChipView.topAnchor constant:PPSpaceMDHalf],
        [self.actionStack.bottomAnchor constraintEqualToAnchor:self.actionChipView.bottomAnchor constant:-PPSpaceMDHalf],
        [self.actionStack.leadingAnchor constraintEqualToAnchor:self.actionChipView.leadingAnchor constant:PPSpaceSM],
        [self.actionStack.trailingAnchor constraintEqualToAnchor:self.actionChipView.trailingAnchor constant:-PPSpaceSM],

        [self.actionChevronView.widthAnchor constraintEqualToConstant:12.0],
        [self.actionChevronView.heightAnchor constraintEqualToConstant:12.0]
    ]];
}

#pragma mark - Appearance & Styling

- (void)pp_refreshAppearance
{
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    BOOL reduceTransparency = UIAccessibilityIsReduceTransparencyEnabled();
    if (reduceTransparency || dark) {
        self.blurView.effect = nil;
        self.tintView.backgroundColor = PPAddressPickerSurfaceColor();
    } else {
        UIBlurEffectStyle blurStyle = UIBlurEffectStyleExtraLight;
        if (@available(iOS 13.0, *)) {
            blurStyle = UIBlurEffectStyleSystemUltraThinMaterial;
        }
        self.blurView.effect = [UIBlurEffect effectWithStyle:blurStyle];
        self.tintView.backgroundColor = [PPAddressPickerSurfaceColor() colorWithAlphaComponent:0.75];
    }

    CGFloat borderWidth = UIAccessibilityDarkerSystemColorsEnabled() ? 1.5 : 1.0;
    self.containerView.layer.borderWidth = borderWidth;
    [self.containerView pp_setBorderColor:PPAddressPickerStrokeColor()];

    UIColor *brand = PPAddressPickerBrandColor();
    BOOL hasAddress = [self pp_hasSelectedAddress];

    if (hasAddress) {
        self.iconPlateView.backgroundColor = [brand colorWithAlphaComponent:dark ? 0.20 : 0.12];
        self.iconView.tintColor = brand;
        self.statusDotView.backgroundColor = AppSuccessClr ?: [UIColor systemGreenColor];
        self.statusDotView.layer.borderColor = (dark ? [UIColor blackColor] : [UIColor whiteColor]).CGColor;
        self.statusDotView.hidden = NO;

        self.addressLabel.textColor = PPAddressPickerPrimaryTextColor();
        self.actionTitleLabel.text = kLang(@"Change");
        self.actionTitleLabel.textColor = brand;
        self.actionChevronView.tintColor = brand;
        self.actionChipView.backgroundColor = [brand colorWithAlphaComponent:dark ? 0.16 : 0.08];
    } else {
        self.iconPlateView.backgroundColor = [brand colorWithAlphaComponent:dark ? 0.15 : 0.08];
        self.iconView.tintColor = brand;
        self.statusDotView.hidden = YES;

        self.addressLabel.textColor = PPAddressPickerSecondaryTextColor();
        self.actionTitleLabel.text = kLang(@"Select");
        self.actionTitleLabel.textColor = brand;
        self.actionChevronView.tintColor = brand;
        self.actionChipView.backgroundColor = [brand colorWithAlphaComponent:dark ? 0.20 : 0.12];
    }

    self.hintLabel.textColor = PPAddressPickerSecondaryTextColor();

    PPApplyCardShadow(self);
    self.layer.shadowOpacity = dark ? 0.0 : PPShadowCardOpacity;
    self.layer.masksToBounds = NO;
}

- (void)pp_updateMetrics
{
    BOOL usesAccessibilityLayout = UIContentSizeCategoryIsAccessibilityCategory(
        self.traitCollection.preferredContentSizeCategory
    );

    CGFloat maxWidth = CGRectGetWidth(self.superview.bounds);
    if (maxWidth <= 0.0) {
        maxWidth = UIScreen.mainScreen.bounds.size.width;
    }
    CGFloat availableFullWidth = self.preferredExpandedWidth > 0.0
        ? MIN(self.preferredExpandedWidth, maxWidth - (PPSpaceBase * 2.0))
        : (maxWidth - (PPSpaceBase * 2.0));

    CGFloat nonTextWidth = (PPSpaceMD * 2.0) + PPAddressPickerIconPlateSize + 85.0 + (PPSpaceMD * 2.0);
    CGFloat textAvailableWidth = MAX(120.0, availableFullWidth - nonTextWidth);

    NSString *text = self.addressLabel.text ?: @"";
    UIFont *font = self.addressLabel.font ?: [UIFont systemFontOfSize:PPFontHeadline weight:UIFontWeightSemibold];
    CGRect textRect = [text boundingRectWithSize:CGSizeMake(textAvailableWidth, CGFLOAT_MAX)
                                         options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                      attributes:@{NSFontAttributeName: font}
                                         context:nil];
    CGFloat textHeight = ceil(textRect.size.height);

    CGFloat baseHeight = usesAccessibilityLayout ? 96.0 : PPAddressPickerExpandedHeight;
    CGFloat dynamicHeight = baseHeight;
    if (textHeight > 24.0) {
        // Multi-line address: dynamically extend height to comfortably fit address text + hint + padding
        dynamicHeight = MAX(baseHeight, ceil(textHeight + 46.0));
    }

    self.heightConstraint.constant = dynamicHeight;
    self.widthConstraintCircle.constant = PPAddressPickerCollapsedSize;
    self.addressLabel.numberOfLines = 0;
    self.addressLabel.lineBreakMode = NSLineBreakByWordWrapping;

    [self setNeedsLayout];
}

#pragma mark - Gesture & Haptic Feedback

- (void)setupGesture
{
    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
    [self addGestureRecognizer:tap];
}

- (void)handleTap
{
    [self pp_runTapFeedback];

    if (self.state == PPAddressPickerStateCollapsed) {
        [self expand];
        return;
    }

    if (self.onPickAddress) {
        self.onPickAddress();
    }
}

- (void)pp_runTapFeedback
{
    if (!UIAccessibilityIsReduceMotionEnabled()) {
        UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [haptic impactOccurred];

        [UIView animateWithDuration:PPAnimDurationFast
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.transform = CGAffineTransformMakeScale(PPTapCardScaleDown, PPTapCardScaleDown);
        } completion:^(__unused BOOL finished) {
            [UIView animateWithDuration:PPAnimDurationNormal
                                  delay:0.0
                 usingSpringWithDamping:PPAnimSpringDamping
                  initialSpringVelocity:PPAnimSpringVelocity
                                options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                self.transform = CGAffineTransformIdentity;
            } completion:nil];
        }];
    }
}

#pragma mark - State & Content Binding

- (void)setAddressText:(NSString *)addressText
{
    _addressText = [addressText copy];
    BOOL hasAddress = [self pp_hasSelectedAddress];
    NSString *displayText = hasAddress ? _addressText : [self pp_addressPlaceholderText];
    self.addressLabel.text = displayText;

    [self pp_refreshAppearance];
    [self pp_updateMetrics];

    NSString *hint = kLang(@"DeliverTo") ?: @"Deliver to";
    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", hint, displayText];
    self.accessibilityHint = kLang(@"order_change_delivery_address") ?: @"Double tap to change delivery address";
    self.accessibilityValue = hasAddress ? kLang(@"Selected") : kLang(@"SelectAddress");
}

- (void)pp_prepareExpandedWidth
{
    CGFloat maxWidth = CGRectGetWidth(self.superview.bounds);
    if (maxWidth <= 0.0) {
        maxWidth = UIScreen.mainScreen.bounds.size.width;
    }
    CGFloat targetWidth = self.preferredExpandedWidth > 0.0
        ? self.preferredExpandedWidth
        : (maxWidth - (PPSpaceBase * 2.0));
    CGFloat availableWidth = MAX(PPAddressPickerCollapsedSize, maxWidth - (PPSpaceBase * 2.0));
    self.widthConstraintFull.constant = MIN(MAX(targetWidth, PPAddressPickerCollapsedSize), availableWidth);
}

- (void)pp_applyStateAnimated:(BOOL)animated
{
    BOOL expanded = self.state == PPAddressPickerStateExpanded;
    CGFloat radius = expanded ? PPCornerCard : (PPAddressPickerCollapsedSize * 0.5);

    void (^changes)(void) = ^{
        PPApplyContinuousCorners(self.containerView, radius);
        self.iconPlateView.transform = expanded ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.94, 0.94);
        self.textStack.alpha = expanded ? 1.0 : 0.0;
        self.actionChipView.alpha = expanded ? 1.0 : 0.0;
        [self.superview layoutIfNeeded];
    };

    void (^completion)(BOOL) = ^(__unused BOOL finished) {
        self.textStack.hidden = !expanded;
        self.actionChipView.hidden = !expanded;
        [self pp_refreshAppearance];
    };

    if (expanded) {
        self.textStack.hidden = NO;
        self.actionChipView.hidden = NO;
    }

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        changes();
        completion(YES);
        return;
    }

    [UIView animateWithDuration:0.34
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:changes
                     completion:completion];
}

- (void)expand
{
    if (self.state == PPAddressPickerStateExpanded) return;
    if (!self.superview) return;

    self.state = PPAddressPickerStateExpanded;
    [self pp_prepareExpandedWidth];
    self.widthConstraintCircle.active = NO;
    self.widthConstraintFull.active = YES;
    self.layer.shadowRadius = 18.0;

    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    self.layer.shadowOpacity = dark ? 0.0 : 0.12;

    if (!UIAccessibilityIsReduceMotionEnabled()) {
        UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [haptic impactOccurred];
    }

    [self pp_applyStateAnimated:YES];
}

- (void)expandAndLock
{
    self.isCollapseDisabled = YES;
    if (self.state == PPAddressPickerStateExpanded || !self.superview) return;
    self.state = PPAddressPickerStateExpanded;
    [self pp_prepareExpandedWidth];
    self.widthConstraintCircle.active = NO;
    self.widthConstraintFull.active = YES;
    [self pp_applyStateAnimated:NO];
}

- (void)collapse
{
    if (self.isCollapseDisabled) return;
    if (self.state == PPAddressPickerStateCollapsed) return;

    self.state = PPAddressPickerStateCollapsed;
    self.widthConstraintFull.active = NO;
    self.widthConstraintCircle.active = YES;
    self.layer.shadowRadius = 14.0;

    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    self.layer.shadowOpacity = dark ? 0.0 : 0.10;

    [self pp_applyStateAnimated:YES];
}

- (void)attachToScrollView:(UIScrollView *)scrollView
{
    [scrollView.panGestureRecognizer addTarget:self action:@selector(handleScroll:)];
}

- (void)handleScroll:(UIPanGestureRecognizer *)gesture
{
    if (self.isCollapseDisabled) return;
    if (gesture.state == UIGestureRecognizerStateBegan && self.state == PPAddressPickerStateExpanded) {
        [self collapse];
    }
}

#pragma mark - Layout & Trait Updates

- (void)layoutSubviews
{
    [super layoutSubviews];

    if (!CGRectIsEmpty(self.bounds)) {
        self.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                       cornerRadius:self.containerView.layer.cornerRadius].CGPath;
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self pp_updateMetrics];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_refreshAppearance];
        }
    }
}

@end

