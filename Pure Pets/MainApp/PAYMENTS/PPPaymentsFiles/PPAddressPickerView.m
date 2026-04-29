//
//  PPAddressPickerView.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 03/02/2026
//

#import "PPAddressPickerView.h"

typedef NS_ENUM(NSUInteger, PPAddressPickerState) {
    PPAddressPickerStateCollapsed,
    PPAddressPickerStateExpanded
};

static CGFloat const PPAddressPickerCollapsedSize = 58.0;
static CGFloat const PPAddressPickerExpandedHeight = 58.0;

static UIColor *PPAddressPickerBrandColor(void)
{
    return AppPrimaryClr ?: UIColor.systemOrangeColor;
}

static UIColor *PPAddressPickerSurfaceColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
            if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:0.12 alpha:0.82];
            }
            return [UIColor colorWithWhite:1.0 alpha:0.82];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.82];
}

static UIColor *PPAddressPickerStrokeColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
            if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.12];
            }
            return [UIColor colorWithWhite:0.0 alpha:0.08];
        }];
    }
    return [UIColor colorWithWhite:0.0 alpha:0.08];
}

static UIColor *PPAddressPickerPrimaryTextColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
            if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:0.96 alpha:1.0];
            }
            return AppPrimaryTextClr ?: UIColor.labelColor;
        }];
    }
    return AppPrimaryTextClr ?: UIColor.blackColor;
}

static UIColor *PPAddressPickerSecondaryTextColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
            if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:0.86 alpha:0.66];
            }
            return [(AppPrimaryTextClr ?: UIColor.labelColor) colorWithAlphaComponent:0.58];
        }];
    }
    return [(AppPrimaryTextClr ?: UIColor.darkGrayColor) colorWithAlphaComponent:0.58];
}

@interface PPAddressPickerView ()

@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *tintView;
@property (nonatomic, strong) UIView *iconPlateView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UILabel *addressLabel;
@property (nonatomic, strong) UIImageView *arrowView;
@property (nonatomic, strong) UIStackView *textStack;
@property (nonatomic, strong) UIStackView *contentStack;

@property (nonatomic) PPAddressPickerState state;
@property (nonatomic, strong) NSLayoutConstraint *widthConstraintCircle;
@property (nonatomic, strong) NSLayoutConstraint *widthConstraintFull;
@property (nonatomic, strong) NSLayoutConstraint *trailingConstraint;
@property (nonatomic, assign) CGFloat preferredExpandedWidth;
@property (nonatomic, assign) BOOL isCollapseDisabled;

@end

@implementation PPAddressPickerView

#pragma mark - Public

+ (instancetype)showInViewController:(UIViewController *)controller width:(float)width
{
    PPAddressPickerView *view = [[PPAddressPickerView alloc] init];
    view.preferredExpandedWidth = MAX(width, PPAddressPickerCollapsedSize);
    [controller.view addSubview:view];

    view.translatesAutoresizingMaskIntoConstraints = NO;

    NSLayoutConstraint *height =
        [view.heightAnchor constraintEqualToConstant:PPAddressPickerExpandedHeight];
    NSLayoutConstraint *trailing =
        [view.trailingAnchor constraintEqualToAnchor:controller.view.trailingAnchor constant:-16.0];
    NSLayoutConstraint *top =
        [view.topAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.topAnchor constant:12.0];

    [NSLayoutConstraint activateConstraints:@[
        trailing,
        top,
        height
    ]];

    view.topConstraint = top;
    view.widthConstraintCircle = [view.widthAnchor constraintEqualToConstant:PPAddressPickerCollapsedSize];
    view.widthConstraintFull = [view.widthAnchor constraintEqualToConstant:view.preferredExpandedWidth];
    view.trailingConstraint = trailing;
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
    [self pp_refreshAppearance];

    return self;
}

#pragma mark - UI

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

- (void)buildUI
{
    UIBlurEffectStyle blurStyle = UIBlurEffectStyleExtraLight;
    if (@available(iOS 13.0, *)) {
        blurStyle = UIBlurEffectStyleSystemUltraThinMaterial;
    }
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:blurStyle];
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.blurView.translatesAutoresizingMaskIntoConstraints = NO;
    self.blurView.layer.cornerRadius = PPAddressPickerCollapsedSize * 0.5;
    if (@available(iOS 13.0, *)) {
        self.blurView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.blurView.clipsToBounds = YES;
    [self addSubview:self.blurView];

    self.tintView = [[UIView alloc] init];
    self.tintView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tintView.userInteractionEnabled = NO;
    [self.blurView.contentView addSubview:self.tintView];

    self.iconPlateView = [[UIView alloc] init];
    self.iconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconPlateView.layer.cornerRadius = 18.0;
    if (@available(iOS 13.0, *)) {
        self.iconPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }
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

    self.hintLabel = [[UILabel alloc] init];
    self.hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.hintLabel.font = [GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    self.hintLabel.text = kLang(@"DeliverTo");
    self.hintLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.hintLabel.numberOfLines = 1;
    self.hintLabel.adjustsFontSizeToFitWidth = YES;
    self.hintLabel.minimumScaleFactor = 0.78;

    self.addressLabel = [[UILabel alloc] init];
    self.addressLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.addressLabel.font = [GM boldFontWithSize:14.5] ?: [UIFont systemFontOfSize:14.5 weight:UIFontWeightSemibold];
    self.addressLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.addressLabel.numberOfLines = 1;
    self.addressLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.addressLabel.adjustsFontSizeToFitWidth = YES;
    self.addressLabel.minimumScaleFactor = 0.74;
    self.addressLabel.text = [self pp_addressPlaceholderText];

    UIImage *arrow = nil;
    if (@available(iOS 13.0, *)) {
        arrow = [UIImage systemImageNamed:@"chevron.down"];
    }
    self.arrowView = [[UIImageView alloc] initWithImage:arrow];
    self.arrowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.arrowView.contentMode = UIViewContentModeScaleAspectFit;

    self.textStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.hintLabel,
        self.addressLabel
    ]];
    self.textStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.textStack.axis = UILayoutConstraintAxisVertical;
    self.textStack.alignment = UIStackViewAlignmentFill;
    self.textStack.distribution = UIStackViewDistributionFill;
    self.textStack.spacing = 1.0;

    self.contentStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.iconPlateView,
        self.textStack,
        self.arrowView
    ]];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisHorizontal;
    self.contentStack.alignment = UIStackViewAlignmentCenter;
    self.contentStack.distribution = UIStackViewDistributionFill;
    self.contentStack.spacing = 10.0;
    self.contentStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.blurView.contentView addSubview:self.contentStack];

    [self.textStack setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.textStack setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.iconPlateView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.arrowView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    [NSLayoutConstraint activateConstraints:@[
        [self.blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],

        [self.tintView.topAnchor constraintEqualToAnchor:self.blurView.contentView.topAnchor],
        [self.tintView.bottomAnchor constraintEqualToAnchor:self.blurView.contentView.bottomAnchor],
        [self.tintView.leadingAnchor constraintEqualToAnchor:self.blurView.contentView.leadingAnchor],
        [self.tintView.trailingAnchor constraintEqualToAnchor:self.blurView.contentView.trailingAnchor],

        [self.contentStack.centerYAnchor constraintEqualToAnchor:self.blurView.contentView.centerYAnchor],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.blurView.contentView.leadingAnchor constant:11.0],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.blurView.contentView.trailingAnchor constant:-13.0],

        [self.iconPlateView.widthAnchor constraintEqualToConstant:36.0],
        [self.iconPlateView.heightAnchor constraintEqualToConstant:36.0],

        [self.iconView.centerXAnchor constraintEqualToAnchor:self.iconPlateView.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:self.iconPlateView.centerYAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:21.0],
        [self.iconView.heightAnchor constraintEqualToConstant:21.0],

        [self.arrowView.widthAnchor constraintEqualToConstant:16.0],
        [self.arrowView.heightAnchor constraintEqualToConstant:16.0]
    ]];
}

- (void)pp_refreshAppearance
{
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIBlurEffectStyle blurStyle = UIBlurEffectStyleExtraLight;
    if (@available(iOS 13.0, *)) {
        blurStyle = dark ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterialLight;
    }
    self.blurView.effect = [UIBlurEffect effectWithStyle:blurStyle];
    self.tintView.backgroundColor = PPAddressPickerSurfaceColor();
    self.blurView.layer.borderWidth = 0.8;
    [self.blurView pp_setBorderColor:PPAddressPickerStrokeColor()];

    UIColor *brand = PPAddressPickerBrandColor();
    self.iconPlateView.backgroundColor = [brand colorWithAlphaComponent:dark ? 0.18 : 0.10];
    self.iconView.tintColor = brand;
    self.arrowView.tintColor = PPAddressPickerSecondaryTextColor();
    self.hintLabel.textColor = PPAddressPickerSecondaryTextColor();
    self.addressLabel.textColor = PPAddressPickerPrimaryTextColor();

    [self pp_setShadowColor:[UIColor blackColor]];
    self.layer.shadowOpacity = dark ? 0.26 : 0.10;
    self.layer.shadowRadius = self.state == PPAddressPickerStateExpanded ? 18.0 : 14.0;
    self.layer.shadowOffset = CGSizeMake(0.0, dark ? 9.0 : 7.0);
    self.layer.masksToBounds = NO;
}

#pragma mark - Gesture

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

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self collapse];
    });
}

- (void)pp_runTapFeedback
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.transform = CGAffineTransformMakeScale(0.985, 0.985);
    } completion:^(__unused BOOL finished) {
        [UIView animateWithDuration:0.22
                              delay:0.0
             usingSpringWithDamping:0.72
              initialSpringVelocity:0.30
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

#pragma mark - State

- (void)setAddressText:(NSString *)addressText
{
    _addressText = [addressText copy];
    NSString *text = [addressText isKindOfClass:NSString.class] && addressText.length > 0
        ? addressText
        : [self pp_addressPlaceholderText];
    self.addressLabel.text = text;
    self.accessibilityLabel = [NSString stringWithFormat:@"%@ %@", kLang(@"DeliverTo"), text];
}

- (void)pp_prepareExpandedWidth
{
    CGFloat maxWidth = CGRectGetWidth(self.superview.bounds);
    if (maxWidth <= 0.0) {
        maxWidth = UIScreen.mainScreen.bounds.size.width;
    }
    CGFloat targetWidth = self.preferredExpandedWidth > 0.0
        ? self.preferredExpandedWidth
        : (maxWidth - 32.0);
    CGFloat availableWidth = MAX(PPAddressPickerCollapsedSize, maxWidth - 32.0);
    self.widthConstraintFull.constant = MIN(MAX(targetWidth, PPAddressPickerCollapsedSize), availableWidth);
}

- (void)pp_applyStateAnimated:(BOOL)animated
{
    BOOL expanded = self.state == PPAddressPickerStateExpanded;
    CGFloat radius = expanded ? 22.0 : PPAddressPickerCollapsedSize * 0.5;
    void (^changes)(void) = ^{
        self.blurView.layer.cornerRadius = radius;
        self.iconPlateView.transform = expanded ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.96, 0.96);
        self.textStack.alpha = expanded ? 1.0 : 0.0;
        self.arrowView.alpha = expanded ? 1.0 : 0.0;
        self.arrowView.transform = expanded ? CGAffineTransformIdentity : CGAffineTransformMakeRotation((CGFloat)M_PI * -0.5);
        [self.superview layoutIfNeeded];
    };
    void (^completion)(BOOL) = ^(__unused BOOL finished) {
        self.textStack.hidden = !expanded;
        self.arrowView.hidden = !expanded;
        [self pp_refreshAppearance];
    };

    if (expanded) {
        self.textStack.hidden = NO;
        self.arrowView.hidden = NO;
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
    self.layer.shadowOpacity = dark ? 0.30 : 0.12;

    if (!UIAccessibilityIsReduceMotionEnabled()) {
        UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [haptic impactOccurred];
    }

    [self pp_applyStateAnimated:YES];
}

- (void)expandAndLock
{
    self.isCollapseDisabled = YES;
    [self expand];
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
    self.layer.shadowOpacity = dark ? 0.26 : 0.10;

    [self pp_applyStateAnimated:YES];
}

- (void)attachToScrollView:(UIScrollView *)scrollView
{
    [scrollView.panGestureRecognizer addTarget:self action:@selector(handleScroll:)];
}

- (void)handleScroll:(UIPanGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan && self.state == PPAddressPickerStateExpanded) {
        [self collapse];
    }
}

#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];

    if (!CGRectIsEmpty(self.bounds)) {
        self.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                      cornerRadius:self.blurView.layer.cornerRadius].CGPath;
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_refreshAppearance];
        }
    }
}

@end
