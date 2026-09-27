//
//  PPCartTableCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/11/2025.
//

#import "PPCartTableCell.h"
#import "CartItem.h"
#import "PPSaveForLaterManager.h"
#import "PPChatsFunc.h"
#import "PPCommerceFeedbackManager.h"
#import "PPDesignTokens.h"
#import "UIImageView+YYWebImage.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import <CoreText/CoreText.h>

#ifndef DLog
#define DLog(fmt, ...) NSLog((@"[PPCartCell] " fmt), ##__VA_ARGS__)
#endif

// One product, one purchase decision: identity above, line total and quantity below.
static NSTimeInterval const kPPCartSavedArrivalDuration = 0.28;
static CGFloat const kPPCartSavedActionCornerRadius = PPCorner16;

static UIColor *PPCartCellAccentColor(void) { return AppPrimaryClr; }
static UIColor *PPCartCellDeferredAccentColor(void) { return AppSecondaryTextClr; }
static UIColor *PPCartCellSurfaceColor(void) { return AppForgroundColr; }
static UIColor *PPCartCellPrimaryTextColor(void) { return AppPrimaryTextClr; }
static UIColor *PPCartCellSecondaryTextColor(void) { return AppSecondaryTextClr; }
static UIColor *PPCartCellHairlineColor(void) { return UIColor.separatorColor; }
static UIColor *PPCartCellSoftFillColor(void) { return UIColor.tertiarySystemFillColor; }

// Keep the Beiruti character while preventing totals and quantities from jittering.
static UIFont *PPCartNumberFont(CGFloat size, UIFontTextStyle style, UITraitCollection *traits)
{
    UIFont *base = [GM boldFontWithSize:size];
    UIFontDescriptor *descriptor = [base.fontDescriptor fontDescriptorByAddingAttributes:@{
        UIFontDescriptorFeatureSettingsAttribute: @[@{
            UIFontFeatureTypeIdentifierKey: @(kNumberSpacingType),
            UIFontFeatureSelectorIdentifierKey: @(kMonospacedNumbersSelector)
        }]
    }];
    UIFont *numberFont = [UIFont fontWithDescriptor:descriptor size:base.pointSize];
    return [[UIFontMetrics metricsForTextStyle:style] scaledFontForFont:numberFont compatibleWithTraitCollection:traits];
}

static NSString *PPCartIsolatedText(NSString *text)
{
    return text.length ? [NSString stringWithFormat:@"\u2068%@\u2069", text] : @"";
}

static NSString *PPCartLocalizedSnapshotName(id value)
{
    if ([value isKindOfClass:NSString.class]) return value;
    if (![value isKindOfClass:NSDictionary.class]) return @"";
    NSString *language = Language.isRTL ? @"ar" : @"en";
    id name = value[language];
    if (![name isKindOfClass:NSString.class] || ![name length]) {
        name = value[Language.isRTL ? @"en" : @"ar"];
    }
    return [name isKindOfClass:NSString.class] ? name : @"";
}

typedef NS_ENUM(NSInteger, PPCartActionButtonKind) {
    PPCartActionButtonKindNeutral,
    PPCartActionButtonKindAccent,
    PPCartActionButtonKindDestructive,
    PPCartActionButtonKindSuccess,
};

// A fine seam opens into a circular paw mark on the product image's axis.
// Its geometry follows the image, including Arabic and accessibility reflow.
@interface PPCartSeamView : UIView
@property (nonatomic, assign) CGFloat imageAxisOffset;
@end

@implementation PPCartSeamView
- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.opaque = NO;
        self.backgroundColor = UIColor.clearColor;
        self.contentMode = UIViewContentModeRedraw;
        self.userInteractionEnabled = NO;
        self.accessibilityElementsHidden = YES;
        _imageAxisOffset = 44;
    }
    return self;
}

- (void)setImageAxisOffset:(CGFloat)imageAxisOffset
{
    if (_imageAxisOffset == imageAxisOffset) return;
    _imageAxisOffset = imageAxisOffset;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGFloat width = CGRectGetWidth(self.bounds);
    if (width < 24) return;
    BOOL highContrast = self.traitCollection.accessibilityContrast == UIAccessibilityContrastHigh;
    CGFloat scale = MAX(self.traitCollection.displayScale, 1);
    CGFloat stroke = highContrast ? 1 : 1 / scale;
    CGFloat y = floor(CGRectGetMidY(self.bounds) * scale) / scale + stroke / 2;
    CGFloat x = MIN(MAX(self.imageAxisOffset, 10), width - 10);
    if (self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft) x = width - x;

    UIImageSymbolConfiguration *symbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:(highContrast ? 14 : 13)
                                                        weight:(highContrast ? UIImageSymbolWeightMedium : UIImageSymbolWeightRegular)];
    UIImage *paw = [UIImage systemImageNamed:@"pawprint.circle" withConfiguration:symbolConfiguration];
    CGFloat symbolWidth = paw ? paw.size.width : 14;
    CGFloat symbolGap = MAX(8, symbolWidth / 2.0 + 3);

    UIBezierPath *rule = [UIBezierPath bezierPath];
    rule.lineWidth = stroke;
    [rule moveToPoint:CGPointMake(0, y)];
    [rule addLineToPoint:CGPointMake(x - symbolGap, y)];
    [rule moveToPoint:CGPointMake(x + symbolGap, y)];
    [rule addLineToPoint:CGPointMake(width, y)];
    [(highContrast ? UIColor.labelColor : PPCartCellHairlineColor()) setStroke];
    [rule stroke];

    if (paw) {
        UIColor *symbolColor = highContrast ? UIColor.labelColor : PPCartCellSecondaryTextColor();
        UIImage *tintedPaw = [paw imageWithTintColor:symbolColor renderingMode:UIImageRenderingModeAlwaysOriginal];
        CGSize size = tintedPaw.size;
        CGRect symbolRect = CGRectMake(round(x - size.width / 2.0),
                                       round(y - size.height / 2.0),
                                       size.width,
                                       size.height);
        [tintedPaw drawInRect:symbolRect];
    }
}
@end

@interface PPCartProductTitleLabel : UILabel
@property (nonatomic, copy) BOOL (^onActivate)(void);
@end

@implementation PPCartProductTitleLabel
- (BOOL)accessibilityActivate
{
    return self.onActivate ? self.onActivate() : [super accessibilityActivate];
}
@end

#pragma mark - Custom Stepper & Save Components

@interface PPCartSaveForLaterButton : UIButton
@property (nonatomic, assign) BOOL isSavedState;
- (void)playBloomAnimationWithSaved:(BOOL)saved completion:(void (^ _Nullable)(void))completion;
@end

@implementation PPCartSaveForLaterButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.adjustsImageWhenHighlighted = NO;
        PPApplyContinuousCorners(self, 14.0);
    }
    return self;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    CGFloat dx = MAX(0.0, (48.0 - CGRectGetWidth(self.bounds)) / 2.0);
    CGFloat dy = MAX(0.0, (48.0 - CGRectGetHeight(self.bounds)) / 2.0);
    CGRect hitFrame = CGRectInset(self.bounds, -dx, -dy);
    return CGRectContainsPoint(hitFrame, point);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    PPApplyContinuousCorners(self, 14.0);
}

- (void)playBloomAnimationWithSaved:(BOOL)saved completion:(void (^ _Nullable)(void))completion
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        if (completion) completion();
        return;
    }

    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleRigid];
    [feedback prepare];
    [feedback impactOccurred];

    CGAffineTransform squashTransform = CGAffineTransformConcat(
        CGAffineTransformMakeScale(0.86, 0.86),
        CGAffineTransformMakeRotation(-0.07)
    );

    CAShapeLayer *bloomRing = [CAShapeLayer layer];
    CGFloat dimension = CGRectGetWidth(self.bounds);
    bloomRing.frame = self.bounds;
    UIBezierPath *startPath = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(self.bounds, dimension * 0.35, dimension * 0.35)];
    UIBezierPath *endPath = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(self.bounds, -12, -12)];
    bloomRing.path = startPath.CGPath;
    bloomRing.fillColor = [PPCartCellAccentColor() colorWithAlphaComponent:0.25].CGColor;
    bloomRing.strokeColor = PPCartCellAccentColor().CGColor;
    bloomRing.lineWidth = 1.5;
    bloomRing.opacity = 1.0;
    [self.layer addSublayer:bloomRing];

    CABasicAnimation *pathAnim = [CABasicAnimation animationWithKeyPath:@"path"];
    pathAnim.fromValue = (__bridge id)startPath.CGPath;
    pathAnim.toValue = (__bridge id)endPath.CGPath;

    CABasicAnimation *opacityAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityAnim.fromValue = @(0.9);
    opacityAnim.toValue = @(0.0);

    CABasicAnimation *lineWidthAnim = [CABasicAnimation animationWithKeyPath:@"lineWidth"];
    lineWidthAnim.fromValue = @(2.0);
    lineWidthAnim.toValue = @(0.5);

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[pathAnim, opacityAnim, lineWidthAnim];
    group.duration = 0.36;
    group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    group.removedOnCompletion = YES;
    [bloomRing addAnimation:group forKey:@"bloomAnimation"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.36 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [bloomRing removeFromSuperlayer];
    });

    [UIView animateWithDuration:0.09
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.transform = squashTransform;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.38
                              delay:0.0
             usingSpringWithDamping:0.56
              initialSpringVelocity:0.8
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.transform = CGAffineTransformIdentity;
        } completion:^(BOOL fin) {
            if (completion) completion();
        }];
    }];
}

@end

typedef NS_ENUM(NSInteger, PPCartStepperKeyKind) {
    PPCartStepperKeyKindMinus,
    PPCartStepperKeyKindPlus,
};

@interface PPCartStepperKeyButton : UIButton
@property (nonatomic, assign) PPCartStepperKeyKind keyKind;
@property (nonatomic, assign) BOOL isAtLimitFloor;
@property (nonatomic, assign) BOOL isAtLimitCeiling;
- (void)playLimitResistanceRejectionAnimation;
@end

@implementation PPCartStepperKeyButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.adjustsImageWhenHighlighted = NO;
    }
    return self;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    CGFloat dx = MAX(0.0, (44.0 - CGRectGetWidth(self.bounds)) / 2.0);
    CGFloat dy = MAX(0.0, (44.0 - CGRectGetHeight(self.bounds)) / 2.0);
    CGRect hitFrame = CGRectInset(self.bounds, -dx, -dy);
    return CGRectContainsPoint(hitFrame, point);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.layer.cornerRadius = CGRectGetHeight(self.bounds) / 2.0;

    if (self.keyKind == PPCartStepperKeyKindPlus && !self.isAtLimitCeiling) {
        BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        self.layer.shadowColor = PPCartCellAccentColor().CGColor;
        self.layer.shadowOpacity = dark ? 0.38 : 0.26;
        self.layer.shadowRadius = 4.0;
        self.layer.shadowOffset = CGSizeMake(0, 2.0);
    } else {
        self.layer.shadowOpacity = 0.0;
    }
}

- (void)playLimitResistanceRejectionAnimation
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    UINotificationFeedbackGenerator *feedback = [[UINotificationFeedbackGenerator alloc] init];
    [feedback prepare];
    [feedback notificationOccurred:UINotificationFeedbackTypeWarning];

    CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    shake.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    shake.duration = 0.24;
    CGFloat offset = (self.keyKind == PPCartStepperKeyKindMinus) ? -3.5 : 3.5;
    shake.values = @[@(0), @(offset), @(-offset * 0.7), @(offset * 0.4), @(-offset * 0.2), @(0)];
    [self.layer addAnimation:shake forKey:@"limitResistanceShake"];
}

@end

@interface PPCartStepperCapsuleView : UIView
- (void)playBreathPulseAnimationWithIncreasing:(BOOL)increasing;
@end

@implementation PPCartStepperCapsuleView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.clipsToBounds = NO;
        PPApplyContinuousCorners(self, 21.0);
    }
    return self;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    CGRect hitFrame = CGRectInset(self.bounds, -4.0, -4.0);
    return CGRectContainsPoint(hitFrame, point);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    PPApplyContinuousCorners(self, CGRectGetHeight(self.bounds) / 2.0);
}

- (void)playBreathPulseAnimationWithIncreasing:(BOOL)increasing
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    CGAffineTransform flexTransform = increasing
        ? CGAffineTransformMakeScale(1.035, 0.97)
        : CGAffineTransformMakeScale(0.97, 1.035);

    [UIView animateWithDuration:0.08
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.transform = flexTransform;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.26
                              delay:0.0
             usingSpringWithDamping:0.68
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

@end

@interface PPCartTableCell ()
@property (nonatomic, strong) UIView *cardContainer;
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *savedStateTintView;
@property (nonatomic, strong) UIView *imageShellView;
@property (nonatomic, strong) UIView *quantityControlView;
@property (nonatomic, strong) PPCartSeamView *dividerView;
@property (nonatomic, strong) UIView *purchaseSurfaceView;
@property (nonatomic, strong) UIImageView *placeholderImageView;
@property (nonatomic, strong) UILabel *lineTotalLabel;
@property (nonatomic, strong) UILabel *subtotalCaptionLabel;
@property (nonatomic, strong) UILabel *savingsLabel;
@property (nonatomic, strong) UILabel *savedStatusBadgeLabel;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIStackView *identityRow;
@property (nonatomic, strong) UIStackView *textStack;
@property (nonatomic, strong) UIStackView *priceRow;
@property (nonatomic, strong) UIStackView *stepperStack;
@property (nonatomic, strong) UIStackView *totalStack;
@property (nonatomic, strong) UIStackView *bottomActionsStack;
@property (nonatomic, strong) UIStackView *bottomRow;
@property (nonatomic, strong) UIStackView *savedActionsRow;
@property (nonatomic, strong, readwrite) UIImageView *itemImageView;
@property (nonatomic, strong, readwrite) UILabel *nameLabel;
@property (nonatomic, strong, readwrite) UILabel *variantOptionsLabel;
@property (nonatomic, strong) UIStackView *variantOptionsRow;
@property (nonatomic, strong, readwrite) UILabel *priceLabel;
@property (nonatomic, strong) UILabel *originalPriceLabel;
@property (nonatomic, strong, readwrite) UILabel *quantityLabel;
@property (nonatomic, strong) UIButton *minusButton;
@property (nonatomic, strong) UIButton *plusButton;
@property (nonatomic, strong, readwrite) UIButton *saveForLaterButton;
@property (nonatomic, strong) UIButton *savedRemoveButton;
@property (nonatomic, strong) UIButton *savedPrimaryButton;
@property (nonatomic, strong) NSLayoutConstraint *imageWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *textWidthConstraint;
@property (nonatomic, strong) CartItem *currentItem;
@property (nonatomic, copy) NSString *representedImageURL;
@property (nonatomic, assign) BOOL savedForLaterMode;
@property (nonatomic, copy) NSString *savedForLaterPrimaryActionName;
@property (nonatomic, assign) BOOL savedForLaterActionCompleted;
@property (nonatomic, assign) NSUInteger savedArrivalAnimationToken;
@property (nonatomic, assign) NSUInteger imageRequestToken;
@end

@implementation PPCartTableCell

#pragma mark - Init

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupViews];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_resetTransientMotion)
                                                     name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_resetTransientMotion)
                                                     name:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
    }
    return self;
}

#pragma mark - Composition

- (UILabel *)pp_labelWithSize:(CGFloat)size bold:(BOOL)bold style:(UIFontTextStyle)style
{
    return [self pp_configureLabel:[[UILabel alloc] init] size:size bold:bold style:style];
}

- (UILabel *)pp_configureLabel:(UILabel *)label size:(CGFloat)size bold:(BOOL)bold style:(UIFontTextStyle)style
{
    label.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *base = bold ? [GM boldFontWithSize:size] : [GM fontWithSize:size];
    label.font = [[UIFontMetrics metricsForTextStyle:style] scaledFontForFont:base compatibleWithTraitCollection:self.traitCollection];
    label.adjustsFontForContentSizeCategory = YES;
    label.numberOfLines = 0;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    [label setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [label setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    return label;
}

- (UIStackView *)pp_stackWithViews:(NSArray<UIView *> *)views axis:(UILayoutConstraintAxis)axis spacing:(CGFloat)spacing
{
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:views];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = axis;
    stack.spacing = spacing;
    stack.alignment = UIStackViewAlignmentFill;
    stack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    return stack;
}

- (void)setupViews
{
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.isAccessibilityElement = NO;
    self.shouldGroupAccessibilityChildren = YES;

    self.cardContainer = [[UIView alloc] init];
    self.cardContainer.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.cardContainer, PPCornerCard);
    [self.contentView addSubview:self.cardContainer];

    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.surfaceView, PPCornerCard);
    self.surfaceView.clipsToBounds = YES;
    [self.cardContainer addSubview:self.surfaceView];

    self.savedStateTintView = [[UIView alloc] init];
    self.savedStateTintView.translatesAutoresizingMaskIntoConstraints = NO;
    self.savedStateTintView.userInteractionEnabled = NO;
    [self.surfaceView addSubview:self.savedStateTintView];

    self.imageShellView = [[UIView alloc] init];
    self.imageShellView.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.imageShellView, PPCornerMedium);
    self.imageShellView.clipsToBounds = YES;
    self.imageShellView.isAccessibilityElement = NO;
    self.imageShellView.accessibilityElementsHidden = YES;
    self.placeholderImageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"pawprint.fill"]];
    self.placeholderImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.placeholderImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.imageShellView addSubview:self.placeholderImageView];
    self.itemImageView = [[UIImageView alloc] init];
    self.itemImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.itemImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.itemImageView.clipsToBounds = YES;
    PPApplyContinuousCorners(self.itemImageView, PPCorner16);
    [self.imageShellView addSubview:self.itemImageView];

    PPCartProductTitleLabel *titleLabel = [[PPCartProductTitleLabel alloc] init];
    self.nameLabel = [self pp_configureLabel:titleLabel size:20 bold:YES style:UIFontTextStyleHeadline];
    __weak typeof(self) weakSelf = self;
    titleLabel.onActivate = ^BOOL{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.isEditing || !self.currentItem || !self.onAction) return NO;
        self.onAction(self.currentItem, @"preview");
        return YES;
    };
    self.variantOptionsLabel = [self pp_labelWithSize:14 bold:NO style:UIFontTextStyleSubheadline];
    UIStackView *variantOptionsRow = [[UIStackView alloc] initWithArrangedSubviews:@[self.variantOptionsLabel]];
    variantOptionsRow.translatesAutoresizingMaskIntoConstraints = NO;
    variantOptionsRow.axis = UILayoutConstraintAxisVertical;
    variantOptionsRow.hidden = YES;
    self.variantOptionsRow = variantOptionsRow;
    self.priceLabel = [self pp_labelWithSize:13 bold:NO style:UIFontTextStyleSubheadline];
    self.originalPriceLabel = [self pp_labelWithSize:12 bold:NO style:UIFontTextStyleFootnote];
    self.originalPriceLabel.hidden = YES;
    self.savingsLabel = [self pp_labelWithSize:12 bold:NO style:UIFontTextStyleFootnote];
    self.savingsLabel.hidden = YES;
    self.savedStatusBadgeLabel = [self pp_labelWithSize:12 bold:YES style:UIFontTextStyleFootnote];
    self.savedStatusBadgeLabel.hidden = YES;
    self.priceRow = [self pp_stackWithViews:@[self.priceLabel, self.originalPriceLabel]
                                     axis:UILayoutConstraintAxisVertical spacing:PPSpaceXXS];
    self.textStack = [self pp_stackWithViews:@[self.savedStatusBadgeLabel, self.nameLabel,
                                             self.variantOptionsRow, self.priceRow]
                                      axis:UILayoutConstraintAxisVertical spacing:PPSpaceXS];
    self.identityRow = [self pp_stackWithViews:@[self.imageShellView, self.textStack]
                                        axis:UILayoutConstraintAxisHorizontal spacing:PPSpaceMD];
    self.identityRow.alignment = UIStackViewAlignmentTop;

    self.subtotalCaptionLabel = [self pp_labelWithSize:12 bold:NO style:UIFontTextStyleCaption1];
    self.lineTotalLabel = [self pp_labelWithSize:27 bold:YES style:UIFontTextStyleTitle1];
    self.lineTotalLabel.font = PPCartNumberFont(27, UIFontTextStyleTitle1, self.traitCollection);
    self.totalStack = [self pp_stackWithViews:@[self.subtotalCaptionLabel, self.lineTotalLabel, self.savingsLabel]
                                       axis:UILayoutConstraintAxisVertical spacing:PPSpaceXXS];

    self.minusButton = [self pp_createStepperKeyWithKind:PPCartStepperKeyKindMinus systemName:@"minus"];
    self.plusButton = [self pp_createStepperKeyWithKind:PPCartStepperKeyKindPlus systemName:@"plus"];
    [self.minusButton addTarget:self action:@selector(didTapMinus) forControlEvents:UIControlEventTouchUpInside];
    [self.plusButton addTarget:self action:@selector(didTapPlus) forControlEvents:UIControlEventTouchUpInside];
    [self pp_applyPressTargetsToButton:self.minusButton];
    [self pp_applyPressTargetsToButton:self.plusButton];
    self.quantityLabel = [self pp_labelWithSize:17 bold:YES style:UIFontTextStyleBody];
    self.quantityLabel.font = PPCartNumberFont(17, UIFontTextStyleBody, self.traitCollection);
    self.quantityLabel.textAlignment = NSTextAlignmentCenter;
    self.quantityLabel.numberOfLines = 1;
    [self.quantityLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [self.quantityLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    self.stepperStack = [self pp_stackWithViews:@[self.minusButton, self.quantityLabel, self.plusButton]
                                         axis:UILayoutConstraintAxisHorizontal spacing:PPSpaceXS];
    self.stepperStack.alignment = UIStackViewAlignmentCenter;
    self.stepperStack.distribution = UIStackViewDistributionFill;
    self.quantityControlView = [[PPCartStepperCapsuleView alloc] init];
    self.quantityControlView.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.quantityControlView, 21.0);
    [self.quantityControlView addSubview:self.stepperStack];
    [self.quantityControlView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    self.saveForLaterButton = [self pp_createSaveForLaterButton];
    [self.saveForLaterButton addTarget:self action:@selector(didTapSaveForLaterButton) forControlEvents:UIControlEventTouchUpInside];
    [self pp_applyPressTargetsToButton:self.saveForLaterButton];
    [self.saveForLaterButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.saveForLaterButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    self.bottomActionsStack = [self pp_stackWithViews:@[self.saveForLaterButton, self.quantityControlView]
                                                 axis:UILayoutConstraintAxisHorizontal spacing:PPSpaceSM];
    self.bottomActionsStack.alignment = UIStackViewAlignmentCenter;
    [self.bottomActionsStack setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    self.bottomRow = [self pp_stackWithViews:@[self.totalStack, self.bottomActionsStack]
                                      axis:UILayoutConstraintAxisHorizontal spacing:PPSpaceMD];
    self.bottomRow.alignment = UIStackViewAlignmentCenter;

    self.savedRemoveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.savedPrimaryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    for (UIButton *button in @[self.savedRemoveButton, self.savedPrimaryButton]) {
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [self pp_applyPressTargetsToButton:button];
    }
    [self.savedRemoveButton addTarget:self action:@selector(didTapSavedRemoveButton) forControlEvents:UIControlEventTouchUpInside];
    [self.savedPrimaryButton addTarget:self action:@selector(didTapSavedPrimaryButton) forControlEvents:UIControlEventTouchUpInside];
    self.savedActionsRow = [self pp_stackWithViews:@[self.savedRemoveButton, self.savedPrimaryButton]
                                             axis:UILayoutConstraintAxisHorizontal spacing:PPSpaceSM];
    self.savedActionsRow.distribution = UIStackViewDistributionFillEqually;
    self.savedActionsRow.hidden = YES;

    self.dividerView = [[PPCartSeamView alloc] initWithFrame:CGRectZero];
    self.dividerView.translatesAutoresizingMaskIntoConstraints = NO;
    // Give the price/quantity decision its own quiet surface within the same card.
    self.purchaseSurfaceView = [[UIView alloc] init];
    self.purchaseSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.purchaseSurfaceView.userInteractionEnabled = NO;
    self.purchaseSurfaceView.isAccessibilityElement = NO;
    [self.surfaceView addSubview:self.purchaseSurfaceView];
    self.contentStack = [self pp_stackWithViews:@[self.identityRow, self.dividerView, self.bottomRow]
                                         axis:UILayoutConstraintAxisVertical spacing:PPSpaceMD];
    [self.surfaceView addSubview:self.contentStack];
    self.imageWidthConstraint = [self.imageShellView.widthAnchor constraintEqualToConstant:88];
    // Full-width columns only when the content needs vertical reflow.
    self.textWidthConstraint = [self.textStack.widthAnchor constraintEqualToAnchor:self.identityRow.widthAnchor];

    [NSLayoutConstraint activateConstraints:@[
        [self.cardContainer.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:PPSpaceSM],
        [self.cardContainer.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-PPSpaceSM],
        [self.cardContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPSpaceBase],
        [self.cardContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPSpaceBase],
        [self.surfaceView.topAnchor constraintEqualToAnchor:self.cardContainer.topAnchor],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.cardContainer.bottomAnchor],
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.cardContainer.leadingAnchor],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.cardContainer.trailingAnchor],
        [self.savedStateTintView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor],
        [self.savedStateTintView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor],
        [self.savedStateTintView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor],
        [self.savedStateTintView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor],
        [self.purchaseSurfaceView.topAnchor constraintEqualToAnchor:self.dividerView.topAnchor],
        [self.purchaseSurfaceView.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor],
        [self.purchaseSurfaceView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor],
        [self.purchaseSurfaceView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor],
        [self.contentStack.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:PPSpaceBase],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor constant:-PPSpaceBase],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:PPSpaceBase],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-PPSpaceBase],
        self.imageWidthConstraint,
        [self.imageShellView.heightAnchor constraintEqualToAnchor:self.imageShellView.widthAnchor],
        [self.itemImageView.topAnchor constraintEqualToAnchor:self.imageShellView.topAnchor constant:1 * PPSpaceXXS],
        [self.itemImageView.bottomAnchor constraintEqualToAnchor:self.imageShellView.bottomAnchor constant:-1 * PPSpaceXXS],
        [self.itemImageView.leadingAnchor constraintEqualToAnchor:self.imageShellView.leadingAnchor constant:1 * PPSpaceXXS],
        [self.itemImageView.trailingAnchor constraintEqualToAnchor:self.imageShellView.trailingAnchor constant:-1 * PPSpaceXXS],
        [self.placeholderImageView.centerXAnchor constraintEqualToAnchor:self.imageShellView.centerXAnchor],
        [self.placeholderImageView.centerYAnchor constraintEqualToAnchor:self.imageShellView.centerYAnchor],
        [self.placeholderImageView.widthAnchor constraintEqualToConstant:28],
        [self.placeholderImageView.heightAnchor constraintEqualToConstant:28],
        [self.dividerView.heightAnchor constraintEqualToConstant:16],
        [self.stepperStack.centerYAnchor constraintEqualToAnchor:self.quantityControlView.centerYAnchor],
        [self.stepperStack.topAnchor constraintGreaterThanOrEqualToAnchor:self.quantityControlView.topAnchor constant:4.0],
        [self.stepperStack.bottomAnchor constraintLessThanOrEqualToAnchor:self.quantityControlView.bottomAnchor constant:-4.0],
        [self.stepperStack.leadingAnchor constraintEqualToAnchor:self.quantityControlView.leadingAnchor constant:5.0],
        [self.stepperStack.trailingAnchor constraintEqualToAnchor:self.quantityControlView.trailingAnchor constant:-5.0],
        [self.quantityControlView.heightAnchor constraintEqualToConstant:42.0],
        [self.minusButton.widthAnchor constraintEqualToConstant:32.0],
        [self.minusButton.heightAnchor constraintEqualToConstant:32.0],
        [self.plusButton.widthAnchor constraintEqualToConstant:32.0],
        [self.plusButton.heightAnchor constraintEqualToConstant:32.0],
        [self.saveForLaterButton.widthAnchor constraintEqualToConstant:42.0],
        [self.saveForLaterButton.heightAnchor constraintEqualToConstant:42.0],
        [self.quantityLabel.widthAnchor constraintGreaterThanOrEqualToConstant:30.0],
        [self.savedRemoveButton.heightAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin],
        [self.savedPrimaryButton.heightAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin],
    ]];
    [self pp_applyLanguage];
    [self pp_applyVisualTheme];
}

- (void)pp_updatePresentationRows
{
    // Detach the inactive controls instead of collapsing their required touch targets.
    UIStackView *inactive = self.savedForLaterMode ? self.bottomRow : self.savedActionsRow;
    UIStackView *active = self.savedForLaterMode ? self.savedActionsRow : self.bottomRow;
    if ([self.contentStack.arrangedSubviews containsObject:inactive]) {
        [self.contentStack removeArrangedSubview:inactive];
        [inactive removeFromSuperview];
    }
    if (![self.contentStack.arrangedSubviews containsObject:active]) [self.contentStack addArrangedSubview:active];
    active.hidden = NO;
    UIStackView *savingsParent = self.savedForLaterMode ? self.priceRow : self.totalStack;
    if (self.savingsLabel.superview != savingsParent) {
        UIStackView *oldParent = (UIStackView *)self.savingsLabel.superview;
        [oldParent removeArrangedSubview:self.savingsLabel];
        [self.savingsLabel removeFromSuperview];
        [savingsParent addArrangedSubview:self.savingsLabel];
    }
}

- (void)pp_applyLanguage
{
    UISemanticContentAttribute semantic = Language.semanticAttributeForCurrentLanguage;
    for (UIView *view in @[self, self.contentView, self.cardContainer, self.surfaceView, self.contentStack,
                          self.identityRow, self.textStack, self.variantOptionsRow, self.priceRow,
                          self.totalStack, self.bottomRow, self.bottomActionsStack, self.quantityControlView, self.stepperStack,
                          self.savedActionsRow, self.dividerView, self.minusButton, self.plusButton, self.saveForLaterButton,
                          self.savedRemoveButton, self.savedPrimaryButton]) view.semanticContentAttribute = semantic;
    for (UILabel *label in @[self.nameLabel, self.variantOptionsLabel, self.priceLabel, self.originalPriceLabel,
                             self.subtotalCaptionLabel, self.lineTotalLabel, self.savingsLabel,
                             self.savedStatusBadgeLabel]) label.textAlignment = Language.alignmentForCurrentLanguage;
    self.variantOptionsLabel.textAlignment = NSTextAlignmentNatural;
    self.subtotalCaptionLabel.text = kLang(@"cart_cell_line_total");
    self.minusButton.accessibilityLabel = kLang(@"a11y_btn_decrease_qty");
    self.plusButton.accessibilityLabel = kLang(@"a11y_btn_increase_qty");
    self.saveForLaterButton.accessibilityLabel = kLang(@"cart_cell_save_for_later");
    self.saveForLaterButton.accessibilityHint = kLang(@"cart_cell_save_hint");
    [self.dividerView setNeedsDisplay];
}

- (void)pp_updateLayoutForWidth:(CGFloat)width
{
    BOOL accessibility = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    // A real width is supplied by table fitting, including edit-mode indentation.
    CGFloat available = MAX(0, width - 2 * (PPSpaceBase + PPSpaceBase));
    BOOL verticalIdentity = accessibility || (available > 0 && available < 240);
    if (!verticalIdentity) self.textWidthConstraint.active = NO;
    self.identityRow.axis = verticalIdentity ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    self.identityRow.alignment = UIStackViewAlignmentLeading;
    if (!verticalIdentity) self.identityRow.alignment = UIStackViewAlignmentTop;
    // In vertical mode the text column must retain the full measured width.
    if (verticalIdentity) self.textWidthConstraint.active = YES;
    self.imageWidthConstraint.constant = accessibility ? 72 : 88;
    self.dividerView.imageAxisOffset = self.imageWidthConstraint.constant / 2;
    CGFloat quantityWidth = MAX(30, ceil(self.quantityLabel.intrinsicContentSize.width));
    CGFloat totalWidth = MAX(96, ceil(self.lineTotalLabel.attributedText.length
        ? self.lineTotalLabel.attributedText.size.width
        : [self.lineTotalLabel.text sizeWithAttributes:@{NSFontAttributeName: self.lineTotalLabel.font}].width));
    CGFloat actionsWidth = quantityWidth + 82.0 + 42.0 + PPSpaceSM;
    BOOL verticalFooter = accessibility || available < totalWidth + actionsWidth + PPSpaceMD;
    self.bottomRow.axis = verticalFooter ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    self.bottomRow.alignment = verticalFooter ? UIStackViewAlignmentFill : UIStackViewAlignmentCenter;
    self.savedActionsRow.axis = (accessibility || available < 280) ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    // The quantity stays centred when its control expands to the whole footer.
    self.stepperStack.distribution = UIStackViewDistributionFill;
}

- (void)pp_refineTotalTypography
{
    NSString *text = self.lineTotalLabel.text;
    if (!text.length) return;
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.alignment = Language.alignmentForCurrentLanguage;
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    NSMutableAttributedString *amount = [[NSMutableAttributedString alloc] initWithString:text attributes:@{
        NSFontAttributeName: self.lineTotalLabel.font,
        NSForegroundColorAttributeName: PPCartCellPrimaryTextColor(),
        NSParagraphStyleAttributeName: paragraph
    }];
    // Style the existing formatter output; the value, digits and currency stay intact.
    static NSRegularExpression *currencyRuns;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        currencyRuns = [NSRegularExpression regularExpressionWithPattern:@"[\\p{L}\\p{Sc}]+" options:0 error:nil];
    });
    UIFont *currencyFont = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
                            scaledFontForFont:[GM MidFontWithSize:14] compatibleWithTraitCollection:self.traitCollection];
    for (NSTextCheckingResult *match in [currencyRuns matchesInString:text options:0 range:NSMakeRange(0, text.length)]) {
        [amount addAttributes:@{
            NSFontAttributeName: currencyFont,
            NSForegroundColorAttributeName: PPCartCellSecondaryTextColor()
        } range:match.range];
    }
    self.lineTotalLabel.attributedText = amount;
}

- (void)pp_refineVariantTypography
{
    NSString *text = self.variantOptionsLabel.text;
    if (!text.length) return;
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.alignment = Language.alignmentForCurrentLanguage;
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.lineSpacing = PPSpaceXXS;
    NSMutableAttributedString *options = [[NSMutableAttributedString alloc] initWithString:text attributes:@{
        NSFontAttributeName: self.variantOptionsLabel.font,
        NSForegroundColorAttributeName: PPCartCellSecondaryTextColor(),
        NSParagraphStyleAttributeName: paragraph
    }];
    // Emphasise the selected value, keeping the backend's exact text and bidi isolates.
    static NSRegularExpression *values;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        values = [NSRegularExpression regularExpressionWithPattern:@"[:：]\\s*\\u2068?([^\\u2069·]+)" options:0 error:nil];
    });
    UIFont *valueFont = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
                         scaledFontForFont:[GM MidFontWithSize:14] compatibleWithTraitCollection:self.traitCollection];
    for (NSTextCheckingResult *match in [values matchesInString:text options:0 range:NSMakeRange(0, text.length)]) {
        [options addAttributes:@{NSFontAttributeName: valueFont, NSForegroundColorAttributeName: PPCartCellPrimaryTextColor()}
                         range:[match rangeAtIndex:1]];
    }
    self.variantOptionsLabel.attributedText = options;
}

- (void)pp_applyVisualTheme
{
    BOOL highContrast = self.traitCollection.accessibilityContrast == UIAccessibilityContrastHigh;
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    CGFloat hairline = 1.0 / MAX(self.traitCollection.displayScale, 1.0);
    self.surfaceView.backgroundColor = PPCartCellSurfaceColor();
    self.surfaceView.layer.borderWidth = highContrast ? 1 : hairline;
    [self.surfaceView pp_setBorderColor:highContrast ? PPCartCellHairlineColor()
        : [PPCartCellPrimaryTextColor() colorWithAlphaComponent:dark ? 0.12 : 0.04]];
    [self.cardContainer pp_setShadowColor:UIColor.blackColor];
    self.cardContainer.layer.shadowOpacity = (highContrast || dark) ? 0 : 0.04;
    self.cardContainer.layer.shadowRadius = PPShadowSubtleRadius;
    self.cardContainer.layer.shadowOffset = CGSizeMake(0, PPSpaceXS);
    self.savedStateTintView.backgroundColor = PPCartCellSoftFillColor();
    self.savedStateTintView.alpha = self.savedForLaterMode ? 0.3 : 0;
    self.imageShellView.backgroundColor = [PPCartCellAccentColor() colorWithAlphaComponent:dark ? 0.14 : 0.065];
    self.purchaseSurfaceView.backgroundColor = UIColor.clearColor;
    self.imageShellView.layer.borderWidth = highContrast ? 1 : hairline;
    [self.imageShellView pp_setBorderColor:highContrast ? PPCartCellHairlineColor()
        : [PPCartCellPrimaryTextColor() colorWithAlphaComponent:dark ? 0.12 : 0.06]];
    self.placeholderImageView.tintColor = UIColor.tertiaryLabelColor;
    self.itemImageView.backgroundColor = UIColor.clearColor;
    self.dividerView.backgroundColor = UIColor.clearColor;
    self.dividerView.alpha = 1;
    [self.dividerView setNeedsDisplay];
    self.nameLabel.textColor = PPCartCellPrimaryTextColor();
    self.lineTotalLabel.textColor = PPCartCellPrimaryTextColor();
    self.quantityLabel.textColor = PPCartCellPrimaryTextColor();
    for (UILabel *label in @[self.variantOptionsLabel, self.priceLabel, self.originalPriceLabel,
                             self.subtotalCaptionLabel, self.savedStatusBadgeLabel]) label.textColor = PPCartCellSecondaryTextColor();
    self.savingsLabel.textColor = PPCartCellSecondaryTextColor();
    self.quantityControlView.backgroundColor = dark
        ? [UIColor colorWithWhite:0.15 alpha:0.85]
        : [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
            return trait.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithWhite:0.15 alpha:0.85]
                : [UIColor colorWithWhite:0.965 alpha:0.98];
        }];
    self.quantityControlView.layer.borderWidth = highContrast ? 1.0 : hairline;
    [self.quantityControlView pp_setBorderColor:highContrast ? PPCartCellHairlineColor()
        : (dark ? [UIColor colorWithWhite:1.0 alpha:0.12] : [UIColor colorWithWhite:0.0 alpha:0.07])];
    self.quantityControlView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.quantityControlView.layer.shadowOpacity = (highContrast || dark) ? 0.0 : 0.04;
    self.quantityControlView.layer.shadowRadius = 4.0;
    self.quantityControlView.layer.shadowOffset = CGSizeMake(0, 1.5);

    self.saveForLaterButton.layer.shadowColor = UIColor.blackColor.CGColor;
    self.saveForLaterButton.layer.shadowOpacity = (highContrast || dark) ? 0.0 : 0.04;
    self.saveForLaterButton.layer.shadowRadius = 3.5;
    self.saveForLaterButton.layer.shadowOffset = CGSizeMake(0, 1.5);
    [self pp_refineTotalTypography];
    [self pp_refineVariantTypography];
    [self pp_updateActionAvailability];
}

#pragma mark - Lifecycle

- (void)prepareForReuse
{
    [super prepareForReuse];

    self.savedArrivalAnimationToken += 1;
    self.imageRequestToken += 1;
    self.representedImageURL = nil;
    [self.itemImageView cancelCurrentImageRequest];
    self.currentItem = nil;
    self.accessibilityElements = nil;
    self.savedForLaterMode = NO;
    self.savedForLaterPrimaryActionName = nil;
    self.savedForLaterActionCompleted = NO;
    [self pp_updatePresentationRows];
    self.onAction = nil;
    self.itemImageView.image = nil;
    self.nameLabel.text = @"";
    self.variantOptionsLabel.text = @"";
    self.variantOptionsRow.hidden = YES;
    self.priceLabel.text = @"";
    self.originalPriceLabel.attributedText = nil;
    self.originalPriceLabel.hidden = YES;
    self.quantityLabel.text = @"";
    self.lineTotalLabel.text = @"";
    self.savingsLabel.text = @"";
    self.savingsLabel.hidden = YES;
    self.savedStatusBadgeLabel.text = @"";
    self.savedStatusBadgeLabel.hidden = YES;
    self.bottomRow.hidden = NO;
    self.savedActionsRow.hidden = YES;

    [self pp_setCardHighlighted:NO animated:NO];

    [self.cardContainer.layer removeAllAnimations];
    [self.surfaceView.layer removeAllAnimations];
    [self.quantityControlView.layer removeAllAnimations];
    [self.savedActionsRow.layer removeAllAnimations];
    [self.quantityLabel.layer removeAllAnimations];
    [self.lineTotalLabel.layer removeAllAnimations];
    [self.savedStateTintView.layer removeAllAnimations];
    [self.itemImageView.layer removeAllAnimations];
    [self.saveForLaterButton.layer removeAllAnimations];
    self.cardContainer.alpha = 1.0;
    self.cardContainer.transform = CGAffineTransformIdentity;
    self.surfaceView.transform = CGAffineTransformIdentity;
    self.quantityControlView.transform = CGAffineTransformIdentity;
    self.savedActionsRow.transform = CGAffineTransformIdentity;
    self.quantityLabel.transform = CGAffineTransformIdentity;
    self.minusButton.transform = CGAffineTransformIdentity;
    self.plusButton.transform = CGAffineTransformIdentity;
    self.saveForLaterButton.transform = CGAffineTransformIdentity;
    self.minusButton.alpha = 1.0;
    self.plusButton.alpha = 1.0;
    self.saveForLaterButton.alpha = 1.0;
    self.savedRemoveButton.alpha = 1.0;
    self.savedPrimaryButton.alpha = 1.0;
    self.savedRemoveButton.transform = CGAffineTransformIdentity;
    self.savedPrimaryButton.transform = CGAffineTransformIdentity;
    self.savedStateTintView.alpha = 0.0;
    self.itemImageView.alpha = 1.0;
    [self pp_setActionButton:self.minusButton systemName:@"minus"];
    [self pp_setActionButton:self.plusButton systemName:@"plus"];
    [self pp_setActionButton:self.saveForLaterButton systemName:@"bookmark"];
    self.minusButton.accessibilityLabel = kLang(@"a11y_btn_decrease_qty");
    self.minusButton.accessibilityHint = nil;
    self.plusButton.accessibilityLabel = kLang(@"a11y_btn_increase_qty");
    self.plusButton.accessibilityHint = nil;
    self.saveForLaterButton.accessibilityLabel = kLang(@"cart_cell_save_for_later");
    self.saveForLaterButton.accessibilityHint = kLang(@"cart_cell_save_hint");

    [self pp_applyVisualTheme];
    [self pp_styleActionButton:self.minusButton kind:PPCartActionButtonKindNeutral enabled:YES];
    [self pp_styleActionButton:self.plusButton kind:PPCartActionButtonKindAccent enabled:YES];
    [self pp_styleActionButton:self.saveForLaterButton kind:PPCartActionButtonKindNeutral enabled:YES];
}

- (CGSize)systemLayoutSizeFittingSize:(CGSize)targetSize
          withHorizontalFittingPriority:(UILayoutPriority)horizontalFittingPriority
                verticalFittingPriority:(UILayoutPriority)verticalFittingPriority
{
    CGFloat editingInset = MAX(0, CGRectGetWidth(self.bounds) - CGRectGetWidth(self.contentView.bounds));
    [self pp_updateLayoutForWidth:targetSize.width - editingInset];
    return [super systemLayoutSizeFittingSize:targetSize
              withHorizontalFittingPriority:horizontalFittingPriority
                    verticalFittingPriority:verticalFittingPriority];
}

- (void)layoutSubviews
{
    [self pp_updateLayoutForWidth:CGRectGetWidth(self.contentView.bounds)];
    [super layoutSubviews];
    self.cardContainer.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.cardContainer.bounds
                                                                   cornerRadius:PPCornerCard].CGPath;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (!self.contentStack) return;
    self.lineTotalLabel.font = PPCartNumberFont(27, UIFontTextStyleTitle1, self.traitCollection);
    self.quantityLabel.font = PPCartNumberFont(17, UIFontTextStyleBody, self.traitCollection);
    [self pp_applyVisualTheme];
    for (UIButton *button in @[self.savedRemoveButton, self.savedPrimaryButton]) {
        UIButtonConfiguration *configuration = button.configuration;
        if (configuration.attributedTitle.length) {
            NSMutableAttributedString *title = [configuration.attributedTitle mutableCopy];
            UIFont *font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
                            scaledFontForFont:[GM boldFontWithSize:14] compatibleWithTraitCollection:self.traitCollection];
            [title addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, title.length)];
            configuration.attributedTitle = title;
            button.configuration = configuration;
        }
    }
    [self setNeedsLayout];
}

- (void)pp_resetTransientMotion
{
    if (!self.contentStack) return;
    self.savedArrivalAnimationToken += 1;
    for (UIView *view in @[self.cardContainer, self.itemImageView, self.savedStateTintView,
                          self.quantityControlView, self.quantityLabel, self.lineTotalLabel, self.savedActionsRow,
                          self.minusButton, self.plusButton, self.saveForLaterButton,
                          self.savedRemoveButton, self.savedPrimaryButton]) {
        [view.layer removeAllAnimations];
        view.transform = CGAffineTransformIdentity;
    }
    self.cardContainer.alpha = 1;
    self.itemImageView.alpha = 1;
    self.savedStateTintView.alpha = self.savedForLaterMode ? 0.3 : 0;
    for (UIButton *button in @[self.minusButton, self.plusButton, self.saveForLaterButton, self.savedRemoveButton, self.savedPrimaryButton]) {
        button.alpha = button.enabled ? 1 : 0.46;
    }
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (!self.window) [self pp_resetTransientMotion];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.itemImageView cancelCurrentImageRequest];
}

#pragma mark - Configuration

- (void)configureWithItem:(CartItem *)item
{
    if (self.currentItem && ![self.currentItem.itemID isEqualToString:item.itemID]) [self pp_resetTransientMotion];
    self.savedForLaterMode = NO;
    self.savedForLaterPrimaryActionName = nil;
    self.savedForLaterActionCompleted = NO;

    [self pp_setActionButton:self.minusButton systemName:@"minus"];
    [self pp_setActionButton:self.plusButton systemName:@"plus"];
    BOOL isSaved = item && [[PPSaveForLaterManager sharedManager] isItemSaved:item.itemID];
    [self pp_setActionButton:self.saveForLaterButton systemName:isSaved ? @"bookmark.fill" : @"bookmark"];
    [self pp_styleActionButton:self.saveForLaterButton kind:isSaved ? PPCartActionButtonKindAccent : PPCartActionButtonKindNeutral enabled:YES];
    self.minusButton.accessibilityLabel = kLang(@"a11y_btn_decrease_qty");
    self.minusButton.accessibilityHint = nil;
    self.plusButton.accessibilityLabel = kLang(@"a11y_btn_increase_qty");
    self.plusButton.accessibilityHint = nil;
    self.saveForLaterButton.accessibilityLabel = [NSString stringWithFormat:kLang(@"cart_cell_save_format"), item.name ?: @""];
    self.saveForLaterButton.accessibilityHint = kLang(@"cart_cell_save_hint");
    self.savedStatusBadgeLabel.hidden = YES;
    self.bottomRow.hidden = NO;
    self.savedActionsRow.hidden = YES;

    self.currentItem = item;
    [self pp_refreshContentForCurrentItem];

    DLog(@"Configured cell | itemID=%@ | name=%@ | price=%.2f | original=%.2f | discount=%@ | qty=%ld",
         item.itemID, item.name, item.price, item.originalPrice,
         item.hasDiscount ? @"YES" : @"NO", (long)item.quantity);
}

- (void)configureWithSavedForLaterItem:(CartItem *)item
                      pendingOperation:(NSString * _Nullable)pendingOperation
                             completed:(BOOL)completed
{
    if (self.currentItem && ![self.currentItem.itemID isEqualToString:item.itemID]) [self pp_resetTransientMotion];
    self.savedForLaterMode = YES;
    self.savedForLaterActionCompleted = completed;
    self.currentItem = item;

    BOOL pendingMove = [pendingOperation isEqualToString:@"move"];
    BOOL pendingRemove = [pendingOperation isEqualToString:@"remove"];
    BOOL pendingNotify = [pendingOperation isEqualToString:@"notify"];
    BOOL hasPending = pendingMove || pendingRemove || pendingNotify;
    BOOL stockIsKnown = item.stockQuantity != NSNotFound;
    BOOL isOutOfStock = stockIsKnown && item.stockQuantity <= 0;

    self.savedForLaterPrimaryActionName = isOutOfStock ? @"notifySavedWhenAvailable" : @"moveSavedToCart";

    self.savedStatusBadgeLabel.text = kLang(@"saved_for_later_short_badge");
    self.savedStatusBadgeLabel.hidden = NO;
    self.bottomRow.hidden = YES;
    self.savedActionsRow.hidden = NO;

    [self pp_refreshContentForCurrentItem];

    NSString *primarySymbol = isOutOfStock ? @"bell.badge" : @"cart.badge.plus";
    NSString *primaryLabel = isOutOfStock ? kLang(@"notify_me") : kLang(@"move_to_cart");
    NSString *primaryHint = isOutOfStock ? kLang(@"stock_notify_success") : kLang(@"saved_for_later_move_hint");

    if (pendingMove) {
        primarySymbol = @"hourglass";
        primaryLabel = kLang(@"moving_to_cart");
    } else if (pendingNotify) {
        primarySymbol = @"hourglass";
        primaryLabel = kLang(@"notify_me_loading");
    } else if (completed) {
        primarySymbol = @"checkmark";
        primaryLabel = kLang(@"saved_for_later_moved_action");
    }

    NSString *removeSymbol = pendingRemove ? @"hourglass" : @"trash";
    [self pp_setActionButton:self.minusButton systemName:removeSymbol];
    [self pp_setActionButton:self.plusButton systemName:primarySymbol];
    self.quantityLabel.text = primaryLabel;

    self.minusButton.accessibilityLabel = kLang(@"saved_for_later_delete_action");
    self.minusButton.accessibilityHint = kLang(@"saved_for_later_remove_hint");
    self.plusButton.accessibilityLabel = primaryLabel;
    self.plusButton.accessibilityHint = primaryHint;

    [self pp_configureSavedActionButton:self.savedRemoveButton
                                  title:pendingRemove ? kLang(@"saved_for_later_removing") : kLang(@"saved_for_later_remove_action")
                             systemName:removeSymbol
                                primary:NO
                            destructive:YES
                                enabled:!hasPending && !completed];
    [self pp_configureSavedActionButton:self.savedPrimaryButton
                                  title:primaryLabel
                             systemName:primarySymbol
                                primary:YES
                            destructive:NO
                                enabled:!hasPending && !completed];
    self.savedRemoveButton.accessibilityHint = kLang(@"saved_for_later_remove_hint");
    self.savedPrimaryButton.accessibilityHint = primaryHint;

    [self pp_applyVisualTheme];
    [self pp_styleActionButton:self.minusButton
                          kind:PPCartActionButtonKindDestructive
                       enabled:!hasPending && !completed];
    [self pp_styleActionButton:self.plusButton
                          kind:completed ? PPCartActionButtonKindSuccess : PPCartActionButtonKindAccent
                       enabled:!hasPending && !completed];
    [self pp_loadImageForItem:item];
    [self pp_updateAccessibility];
}

- (void)pp_refreshContentForCurrentItem
{
    CartItem *item = self.currentItem;
    if (!item) return;
    [self pp_updatePresentationRows];
    [self pp_applyLanguage];
    self.nameLabel.text = item.name.length ? item.name : kLang(@"cart_cell_unnamed_item");
    // Preserve legacy summaries, but prefer the snapshot's current-language display names.
    self.variantOptionsLabel.text = item.optionsSummary;
    NSString *options = [self pp_optionsTextForItem:item];
    if (options.length) {
        self.variantOptionsLabel.text = options;
        self.variantOptionsLabel.accessibilityLabel = [NSString stringWithFormat:@"%@: %@", kLang(@"accessory_view_options_title"), item.optionsSummary];
        self.variantOptionsLabel.hidden = NO;
        self.variantOptionsRow.hidden = NO;
    } else {
        self.variantOptionsLabel.text = @"";
        self.variantOptionsLabel.accessibilityLabel = nil;
        self.variantOptionsLabel.hidden = YES;
        self.variantOptionsRow.hidden = YES;
    }
    self.quantityLabel.text = [NSString stringWithFormat:@"%ld", (long)MAX(1, item.quantity)];
    self.priceLabel.text = [NSString stringWithFormat:kLang(@"cart_cell_unit_price_format"),
                           PPCartIsolatedText([PPChatsFunc formattedCurrency:item.price])];
    self.lineTotalLabel.text = PPCartIsolatedText([PPChatsFunc formattedCurrency:item.lineSubtotal]);
    if (item.hasDiscount) {
        NSString *original = [NSString stringWithFormat:kLang(@"cart_cell_original_price_format"),
                              PPCartIsolatedText([PPChatsFunc formattedCurrency:item.originalPrice])];
        self.originalPriceLabel.attributedText = [[NSAttributedString alloc] initWithString:original attributes:@{
            NSStrikethroughStyleAttributeName: @(NSUnderlineStyleSingle)
        }];
        self.originalPriceLabel.hidden = NO;
        self.savingsLabel.text = [NSString stringWithFormat:kLang(@"cart_cell_savings_format"),
                                     PPCartIsolatedText([PPChatsFunc formattedCurrency:self.savedForLaterMode ? item.discountPerUnit : item.lineDiscountTotal])];
        self.savingsLabel.hidden = NO;
    } else {
        self.originalPriceLabel.attributedText = nil;
        self.originalPriceLabel.hidden = YES;
        self.savingsLabel.text = @"";
        self.savingsLabel.hidden = YES;
    }
    [self pp_applyVisualTheme];
    [self pp_loadImageForItem:item];
    [self pp_updateAccessibility];
    [self setNeedsLayout];
}

- (NSString *)pp_optionsTextForItem:(CartItem *)item
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSArray *snapshots = [item.selectedOptionsSnapshot isKindOfClass:NSArray.class] ? item.selectedOptionsSnapshot : @[];
    for (id raw in snapshots) {
        if (![raw isKindOfClass:NSDictionary.class]) continue;
        NSString *name = PPCartLocalizedSnapshotName(raw[@"optionName"]);
        NSString *value = PPCartLocalizedSnapshotName(raw[@"valueName"]);
        if (value.length) {
            [parts addObject:name.length ? [NSString stringWithFormat:@"%@: %@", PPCartIsolatedText(name), PPCartIsolatedText(value)] : PPCartIsolatedText(value)];
        }
    }
    if (parts.count) return [parts componentsJoinedByString:@" · "];
    // Legacy cart documents retain exact selected values without guessing translated names.
    if ([item.selectedOptions isKindOfClass:NSDictionary.class] && item.selectedOptions.count) {
        NSArray *keys = [item.selectedOptions.allKeys filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id key, NSDictionary *bindings) {
            return [key isKindOfClass:NSString.class];
        }]];
        for (NSString *key in [keys sortedArrayUsingSelector:@selector(compare:)]) {
            NSString *value = item.selectedOptions[key];
            if (![value isKindOfClass:NSString.class] || !value.length) continue;
            NSString *name = [key.lowercaseString isEqualToString:@"color"] ? kLang(@"Color") :
                             [key.lowercaseString isEqualToString:@"size"] ? kLang(@"Size") : key;
            [parts addObject:[NSString stringWithFormat:@"%@: %@", PPCartIsolatedText(name), PPCartIsolatedText(value)]];
        }
    }
    return parts.count ? [parts componentsJoinedByString:@" · "] : (item.optionsSummary ?: @"");
}

- (void)pp_loadImageForItem:(CartItem *)item
{
    NSString *url = item.imageURL ?: @"";
    if ([self.representedImageURL isEqualToString:url]) return;
    self.representedImageURL = url;
    NSUInteger token = ++self.imageRequestToken;
    [self.itemImageView cancelCurrentImageRequest];
    self.itemImageView.image = nil;
    if (!url.length) return;
    NSURL *imageURL = [NSURL URLWithString:url];
    if (!imageURL) return;
    // Use the app's existing image cache/decoder, with assignment owned by this reuse token.
    __weak typeof(self) weakSelf = self;
    [self.itemImageView setImageWithURL:imageURL placeholder:nil options:YYWebImageOptionAvoidSetImage
                             progress:nil transform:nil
                           completion:^(UIImage *image, NSURL *responseURL, YYWebImageFromType from, YYWebImageStage stage, NSError *error) {
        if (stage != YYWebImageStageFinished || error || !image) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.imageRequestToken != token || ![self.representedImageURL isEqualToString:url]) return;
            self.itemImageView.image = image;
        });
    }];
}

- (void)pp_updateAccessibility
{
    if (!self.currentItem) return;
    NSString *name = self.currentItem.name ?: @"";
    self.nameLabel.accessibilityTraits = UIAccessibilityTraitButton;
    self.nameLabel.accessibilityHint = kLang(@"cart_cell_preview_hint");
    self.quantityLabel.accessibilityLabel = kLang(@"a11y_cart_qty_stepper");
    self.quantityLabel.accessibilityValue = self.quantityLabel.text;
    self.minusButton.accessibilityLabel = [NSString stringWithFormat:kLang(@"cart_cell_decrease_format"), name];
    self.plusButton.accessibilityLabel = [NSString stringWithFormat:kLang(@"cart_cell_increase_format"), name];
    self.minusButton.accessibilityValue = (self.currentItem.quantity <= 1) ? kLang(@"a11y_btn_decrease_qty") : self.quantityLabel.text;
    self.plusButton.accessibilityValue = self.quantityLabel.text;
    self.saveForLaterButton.accessibilityLabel = [NSString stringWithFormat:kLang(@"cart_cell_save_format"), name];
    self.saveForLaterButton.accessibilityHint = kLang(@"cart_cell_save_hint");
    BOOL isSaved = [[PPSaveForLaterManager sharedManager] isItemSaved:self.currentItem.itemID];
    self.saveForLaterButton.accessibilityValue = isSaved ? kLang(@"saved_for_later_short_badge") : nil;
    self.saveForLaterButton.accessibilityTraits = isSaved ? (UIAccessibilityTraitButton | UIAccessibilityTraitSelected) : UIAccessibilityTraitButton;
    self.lineTotalLabel.accessibilityLabel = [NSString stringWithFormat:@"%@: %@", kLang(@"cart_cell_line_total"), [PPChatsFunc formattedCurrency:self.currentItem.lineSubtotal]];
    self.subtotalCaptionLabel.isAccessibilityElement = NO;
    NSMutableArray *elements = [NSMutableArray arrayWithObject:self.nameLabel];
    if (!self.variantOptionsRow.hidden) [elements addObject:self.variantOptionsLabel];
    [elements addObject:self.priceLabel];
    if (!self.originalPriceLabel.hidden) [elements addObject:self.originalPriceLabel];
    if (self.savedForLaterMode) {
        if (!self.savingsLabel.hidden) [elements addObject:self.savingsLabel];
        [elements addObjectsFromArray:@[self.savedStatusBadgeLabel, self.savedRemoveButton, self.savedPrimaryButton]];
    } else {
        [elements addObject:self.lineTotalLabel];
        if (!self.savingsLabel.hidden) [elements addObject:self.savingsLabel];
        [elements addObjectsFromArray:@[self.minusButton, self.quantityLabel, self.plusButton, self.saveForLaterButton]];
    }
    self.accessibilityElements = elements;
}

- (void)pp_updateActionAvailability
{
    if (!self.currentItem) return;
    if (self.savedForLaterMode) return;

    BOOL canDecrease = self.currentItem.quantity > 1;
    BOOL stockIsKnown = self.currentItem.stockQuantity != NSNotFound;
    BOOL canIncrease = !stockIsKnown || self.currentItem.quantity < self.currentItem.stockQuantity;
    BOOL isSaved = [[PPSaveForLaterManager sharedManager] isItemSaved:self.currentItem.itemID];

    if ([self.minusButton isKindOfClass:[PPCartStepperKeyButton class]]) {
        ((PPCartStepperKeyButton *)self.minusButton).isAtLimitFloor = !canDecrease;
    }
    if ([self.plusButton isKindOfClass:[PPCartStepperKeyButton class]]) {
        ((PPCartStepperKeyButton *)self.plusButton).isAtLimitCeiling = !canIncrease;
    }

    [self pp_styleActionButton:self.minusButton kind:PPCartActionButtonKindNeutral enabled:canDecrease];
    [self pp_styleActionButton:self.plusButton kind:PPCartActionButtonKindAccent enabled:canIncrease];
    [self pp_setActionButton:self.saveForLaterButton systemName:isSaved ? @"bookmark.fill" : @"bookmark"];
    [self pp_styleActionButton:self.saveForLaterButton kind:isSaved ? PPCartActionButtonKindAccent : PPCartActionButtonKindNeutral enabled:YES];
}

#pragma mark - Actions

- (void)didTapMinus
{
    if (self.savedForLaterMode) {
        [self pp_animateSavedForLaterActionFromButton:self.minusButton];
        if (self.onAction) {
            self.onAction(self.currentItem, @"removeSavedForLater");
        }
        return;
    }

    if (!self.currentItem) return;

    if (self.currentItem.quantity <= 1) {
        if ([self.minusButton isKindOfClass:[PPCartStepperKeyButton class]]) {
            [(PPCartStepperKeyButton *)self.minusButton playLimitResistanceRejectionAnimation];
        }
        return;
    }

    DLog(@"Minus tapped for %@", self.currentItem.name);
    self.currentItem.quantity -= 1;
    [self pp_preparePriceAnimationIncreasing:NO];
    [self pp_refreshContentForCurrentItem];
    [self pp_animateQuantityChangeWithIncreasing:NO];
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventCartQuantityChanged];

    if (self.onAction) {
        self.onAction(self.currentItem, @"minus");
    }
}

- (void)didTapPlus
{
    if (self.savedForLaterMode) {
        [self pp_animateSavedForLaterActionFromButton:self.plusButton];
        if (self.onAction) {
            self.onAction(self.currentItem, self.savedForLaterPrimaryActionName ?: @"moveSavedToCart");
        }
        return;
    }

    if (!self.currentItem || self.currentItem.quantity == NSIntegerMax) return;
    if (self.currentItem.stockQuantity != NSNotFound &&
        self.currentItem.quantity >= self.currentItem.stockQuantity) {
        if ([self.plusButton isKindOfClass:[PPCartStepperKeyButton class]]) {
            [(PPCartStepperKeyButton *)self.plusButton playLimitResistanceRejectionAnimation];
        }
        return;
    }

    DLog(@"Plus tapped for %@", self.currentItem.name);
    self.currentItem.quantity += 1;
    [self pp_preparePriceAnimationIncreasing:YES];
    [self pp_refreshContentForCurrentItem];
    [self pp_animateQuantityChangeWithIncreasing:YES];
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventCartQuantityChanged];

    if (self.onAction) {
        self.onAction(self.currentItem, @"plus");
    }
}

- (void)didTapSaveForLaterButton
{
    if (self.savedForLaterMode || !self.currentItem || !self.saveForLaterButton.userInteractionEnabled) {
        return;
    }

    DLog(@"Save for later tapped for %@", self.currentItem.name);
    BOOL wasSaved = [[PPSaveForLaterManager sharedManager] isItemSaved:self.currentItem.itemID];
    if ([self.saveForLaterButton isKindOfClass:[PPCartSaveForLaterButton class]]) {
        [(PPCartSaveForLaterButton *)self.saveForLaterButton playBloomAnimationWithSaved:!wasSaved completion:nil];
    } else {
        [self pp_animateSavedForLaterActionFromButton:self.saveForLaterButton];
    }
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventSuccess];

    if (self.onAction) {
        self.onAction(self.currentItem, @"moveToSavedForLater");
    }
}

- (void)didTapSavedRemoveButton
{
    if (!self.savedForLaterMode || !self.currentItem || !self.savedRemoveButton.userInteractionEnabled) {
        return;
    }
    [self pp_animateSavedForLaterActionFromButton:self.savedRemoveButton];
    if (self.onAction) {
        self.onAction(self.currentItem, @"removeSavedForLater");
    }
}

- (void)didTapSavedPrimaryButton
{
    if (!self.savedForLaterMode || !self.currentItem || !self.savedPrimaryButton.userInteractionEnabled) {
        return;
    }
    [self pp_animateSavedForLaterActionFromButton:self.savedPrimaryButton];
    if (self.onAction) {
        self.onAction(self.currentItem, self.savedForLaterPrimaryActionName ?: @"moveSavedToCart");
    }
}

#pragma mark - Helpers

- (PPCartSaveForLaterButton *)pp_createSaveForLaterButton
{
    PPCartSaveForLaterButton *button = [[PPCartSaveForLaterButton alloc] initWithFrame:CGRectZero];
    [self pp_setActionButton:button systemName:@"bookmark"];
    [self pp_styleActionButton:button kind:PPCartActionButtonKindNeutral enabled:YES];
    return button;
}

- (PPCartStepperKeyButton *)pp_createStepperKeyWithKind:(PPCartStepperKeyKind)kind systemName:(NSString *)iconName
{
    PPCartStepperKeyButton *button = [[PPCartStepperKeyButton alloc] initWithFrame:CGRectZero];
    button.keyKind = kind;
    [self pp_setActionButton:button systemName:iconName];
    [self pp_styleActionButton:button kind:(kind == PPCartStepperKeyKindPlus ? PPCartActionButtonKindAccent : PPCartActionButtonKindNeutral) enabled:YES];
    return button;
}

- (UIButton *)pp_createIconButtonWithSystemName:(NSString *)iconName kind:(PPCartActionButtonKind)kind
{
    UIImage *image = [self pp_actionImageNamed:iconName];

    UIButton *button;
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.contentInsets = NSDirectionalEdgeInsetsMake(6.0, 6.0, 6.0, 6.0);
        config.image = image;
        button = [UIButton buttonWithConfiguration:config primaryAction:nil];
    } else {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setImage:image forState:UIControlStateNormal];
        button.contentEdgeInsets = UIEdgeInsetsMake(6.0, 6.0, 6.0, 6.0);
        button.layer.cornerRadius = 14.0;
        button.clipsToBounds = YES;
    }

    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.adjustsImageWhenHighlighted = NO;
    [self pp_styleActionButton:button kind:kind enabled:YES];
    return button;
}

- (UIImage *)pp_actionImageNamed:(NSString *)systemName pointSize:(CGFloat)pointSize weight:(UIImageSymbolWeight)weight
{
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:pointSize
                                                        weight:weight];
    return [[UIImage systemImageNamed:systemName ?: @"circle"] imageByApplyingSymbolConfiguration:configuration];
}

- (UIImage *)pp_actionImageNamed:(NSString *)systemName
{
    return [self pp_actionImageNamed:systemName pointSize:16.0 weight:UIImageSymbolWeightSemibold];
}

- (void)pp_setActionButton:(UIButton *)button systemName:(NSString *)systemName
{
    if (!button) return;
    CGFloat pointSize = 16.0;
    UIImageSymbolWeight weight = UIImageSymbolWeightSemibold;
    if (button == self.minusButton || button == self.plusButton) {
        pointSize = 13.5;
        weight = UIImageSymbolWeightBold;
    } else if (button == self.saveForLaterButton) {
        pointSize = 15.5;
        weight = UIImageSymbolWeightSemibold;
    }
    UIImage *image = [self pp_actionImageNamed:systemName pointSize:pointSize weight:weight];
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = button.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
        config.image = image;
        button.configuration = config;
    } else {
        [button setImage:image forState:UIControlStateNormal];
    }
}

- (void)pp_styleActionButton:(UIButton *)button kind:(PPCartActionButtonKind)kind enabled:(BOOL)enabled
{
    if (!button) return;

    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    BOOL highContrast = self.traitCollection.accessibilityContrast == UIAccessibilityContrastHigh;
    CGFloat hairline = 1.0 / MAX(self.traitCollection.displayScale, 1.0);

    if (button == self.saveForLaterButton) {
        BOOL isSaved = (kind == PPCartActionButtonKindAccent);
        if ([button isKindOfClass:[PPCartSaveForLaterButton class]]) {
            ((PPCartSaveForLaterButton *)button).isSavedState = isSaved;
        }

        UIColor *foregroundColor = isSaved ? PPCartCellAccentColor() : PPCartCellSecondaryTextColor();
        UIColor *backgroundColor = isSaved
            ? [PPCartCellAccentColor() colorWithAlphaComponent:dark ? 0.18 : 0.12]
            : (dark ? [UIColor colorWithWhite:0.20 alpha:0.75] : PPCartCellSoftFillColor());
        UIColor *borderColor = isSaved
            ? [PPCartCellAccentColor() colorWithAlphaComponent:dark ? 0.42 : 0.28]
            : (highContrast ? PPCartCellHairlineColor() : (dark ? [UIColor colorWithWhite:1.0 alpha:0.12] : [PPCartCellPrimaryTextColor() colorWithAlphaComponent:0.06]));

        button.enabled = YES;
        button.userInteractionEnabled = YES;
        button.alpha = 1.0;

        if (@available(iOS 15.0, *)) {
            UIButtonConfiguration *configuration = button.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
            configuration.baseForegroundColor = foregroundColor;
            configuration.background.backgroundColor = backgroundColor;
            configuration.background.strokeColor = borderColor;
            configuration.background.strokeWidth = highContrast ? 1.5 : (isSaved ? 1.0 : hairline);
            configuration.cornerStyle = UIButtonConfigurationCornerStyleFixed;
            configuration.background.cornerRadius = 14.0;
            configuration.contentInsets = NSDirectionalEdgeInsetsMake(8.0, 8.0, 8.0, 8.0);
            button.configuration = configuration;
        } else {
            button.backgroundColor = backgroundColor;
            [button pp_setBorderColor:borderColor];
            button.layer.borderWidth = highContrast ? 1.5 : hairline;
            button.tintColor = foregroundColor;
        }
        return;
    }

    if (button == self.minusButton) {
        if ([button isKindOfClass:[PPCartStepperKeyButton class]]) {
            ((PPCartStepperKeyButton *)button).isAtLimitFloor = !enabled;
        }

        UIColor *foregroundColor = enabled ? PPCartCellPrimaryTextColor() : UIColor.tertiaryLabelColor;
        UIColor *backgroundColor = enabled
            ? (dark ? [UIColor colorWithWhite:0.24 alpha:0.65] : PPCartCellSoftFillColor())
            : UIColor.clearColor;

        button.enabled = YES;
        button.userInteractionEnabled = YES;
        button.alpha = enabled ? 1.0 : 0.32;

        if (@available(iOS 15.0, *)) {
            UIButtonConfiguration *configuration = button.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
            configuration.baseForegroundColor = foregroundColor;
            configuration.background.backgroundColor = backgroundColor;
            configuration.background.strokeWidth = 0;
            configuration.cornerStyle = UIButtonConfigurationCornerStyleFixed;
            configuration.background.cornerRadius = 16.0;
            configuration.contentInsets = NSDirectionalEdgeInsetsMake(6.0, 6.0, 6.0, 6.0);
            button.configuration = configuration;
        } else {
            button.backgroundColor = backgroundColor;
            button.tintColor = foregroundColor;
            button.layer.cornerRadius = 16.0;
        }
        return;
    }

    if (button == self.plusButton) {
        if ([button isKindOfClass:[PPCartStepperKeyButton class]]) {
            ((PPCartStepperKeyButton *)button).isAtLimitCeiling = !enabled;
        }

        UIColor *foregroundColor = enabled ? UIColor.whiteColor : UIColor.tertiaryLabelColor;
        UIColor *backgroundColor = enabled
            ? PPCartCellAccentColor()
            : (dark ? [UIColor colorWithWhite:0.20 alpha:0.50] : PPCartCellSoftFillColor());

        button.enabled = YES;
        button.userInteractionEnabled = YES;
        button.alpha = enabled ? 1.0 : 0.35;

        if (@available(iOS 15.0, *)) {
            UIButtonConfiguration *configuration = button.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
            configuration.baseForegroundColor = foregroundColor;
            configuration.background.backgroundColor = backgroundColor;
            configuration.background.strokeWidth = 0;
            configuration.cornerStyle = UIButtonConfigurationCornerStyleFixed;
            configuration.background.cornerRadius = 16.0;
            configuration.contentInsets = NSDirectionalEdgeInsetsMake(6.0, 6.0, 6.0, 6.0);
            button.configuration = configuration;
        } else {
            button.backgroundColor = backgroundColor;
            button.tintColor = foregroundColor;
            button.layer.cornerRadius = 16.0;
        }
        return;
    }

    UIColor *foreground = PPCartCellPrimaryTextColor();
    UIColor *background = enabled ? PPCartCellSoftFillColor() : UIColor.clearColor;
    if (kind == PPCartActionButtonKindAccent) {
        foreground = enabled ? UIColor.whiteColor : UIColor.tertiaryLabelColor;
        background = enabled ? PPCartCellAccentColor() : UIColor.clearColor;
    } else if (kind == PPCartActionButtonKindDestructive) {
        foreground = UIColor.systemRedColor;
    } else if (kind == PPCartActionButtonKindSuccess) {
        foreground = UIColor.systemGreenColor;
    }
    button.enabled = enabled;
    button.userInteractionEnabled = enabled;
    button.alpha = enabled ? 1 : 0.46;
    UIButtonConfiguration *configuration = button.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
    configuration.baseForegroundColor = foreground;
    configuration.background.backgroundColor = background;
    configuration.background.strokeWidth = 0;
    configuration.cornerStyle = UIButtonConfigurationCornerStyleFixed;
    configuration.background.cornerRadius = PPTouchTargetMin * 0.5;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(PPSpaceSM, PPSpaceSM, PPSpaceSM, PPSpaceSM);
    button.configuration = configuration;
}

- (void)pp_configureSavedActionButton:(UIButton *)button
                                title:(NSString *)title
                           systemName:(NSString *)systemName
                              primary:(BOOL)primary
                          destructive:(BOOL)destructive
                              enabled:(BOOL)enabled
{
    if (!button) return;

    NSString *resolvedTitle = title.length > 0 ? title : @"";
    UIColor *savedAccentColor = PPCartCellDeferredAccentColor();
    UIColor *foregroundColor = primary ? UIColor.whiteColor : (destructive ? UIColor.systemRedColor : savedAccentColor);
    UIColor *backgroundColor = primary
        ? savedAccentColor
        : [savedAccentColor colorWithAlphaComponent:enabled ? 0.105 : 0.050];
    UIColor *borderColor = primary
        ? [UIColor.whiteColor colorWithAlphaComponent:0.17]
        : [savedAccentColor colorWithAlphaComponent:enabled ? 0.22 : 0.10];
    UIImage *image = [self pp_actionImageNamed:systemName];

    button.enabled = enabled;
    button.userInteractionEnabled = enabled;
    button.alpha = enabled ? 1.0 : 0.52;
    button.accessibilityLabel = resolvedTitle;
    button.titleLabel.adjustsFontSizeToFitWidth = NO;
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.titleLabel.numberOfLines = 0;
    button.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *configuration = primary
            ? [UIButtonConfiguration filledButtonConfiguration]
            : [UIButtonConfiguration tintedButtonConfiguration];
        configuration.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        configuration.baseForegroundColor = foregroundColor;
        configuration.background.backgroundColor = backgroundColor;
        configuration.background.cornerRadius = kPPCartSavedActionCornerRadius;
        configuration.background.strokeColor = borderColor;
        configuration.background.strokeWidth = 0.8;
        configuration.image = image;
        configuration.titleLineBreakMode = NSLineBreakByWordWrapping;
        configuration.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;
        configuration.imagePadding = 6.0;
        configuration.imagePlacement = NSDirectionalRectEdgeLeading;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(7.0, primary ? 14.0 : 11.0, 7.0, primary ? 14.0 : 11.0);
        configuration.attributedTitle = [[NSAttributedString alloc]
            initWithString:resolvedTitle
                attributes:@{
                    NSFontAttributeName: [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:[GM boldFontWithSize:14] compatibleWithTraitCollection:self.traitCollection],
                    NSForegroundColorAttributeName: foregroundColor
                }];
        button.configuration = configuration;
    } else {
        [button setTitle:resolvedTitle forState:UIControlStateNormal];
        [button setTitleColor:foregroundColor forState:UIControlStateNormal];
        [button setImage:image forState:UIControlStateNormal];
        button.tintColor = foregroundColor;
        button.titleLabel.font = [GM boldFontWithSize:12.5];
        button.backgroundColor = backgroundColor;
        button.layer.cornerRadius = kPPCartSavedActionCornerRadius;
        button.layer.borderWidth = 0.8;
        [button pp_setBorderColor:borderColor];
        button.contentEdgeInsets = UIEdgeInsetsMake(7.0, primary ? 14.0 : 11.0, 7.0, primary ? 14.0 : 11.0);
        if (@available(iOS 13.0, *)) {
            button.layer.cornerCurve = kCACornerCurveContinuous;
        }
    }
}

#pragma mark - Selection / Motion

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    [self pp_setCardHighlighted:highlighted animated:animated];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    [self pp_setCardHighlighted:selected animated:animated];
}

- (void)pp_setCardHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    (void)highlighted;
    (void)animated;
    self.cardContainer.transform = CGAffineTransformIdentity;
    self.cardContainer.alpha = 1;
}

- (void)pp_applyPressTargetsToButton:(UIButton *)button
{
    if (!button) return;

    [button addTarget:self action:@selector(pp_buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(pp_buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(pp_buttonTouchUp:) forControlEvents:UIControlEventTouchUpOutside];
    [button addTarget:self action:@selector(pp_buttonTouchUp:) forControlEvents:UIControlEventTouchCancel];
}

- (void)pp_buttonTouchDown:(UIButton *)button
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        button.alpha = button.userInteractionEnabled ? 0.90 : button.alpha;
        return;
    }

    CGFloat scale = (button == self.minusButton || button == self.plusButton) ? 0.88 : (button == self.saveForLaterButton ? 0.90 : PPTapScaleDown);
    [UIView animateWithDuration:0.08
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        button.transform = CGAffineTransformMakeScale(scale, scale);
        button.alpha = button.userInteractionEnabled ? 0.92 : button.alpha;
    } completion:nil];
}

- (void)pp_buttonTouchUp:(UIButton *)button
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        button.transform = CGAffineTransformIdentity;
        button.alpha = button.userInteractionEnabled ? 1.0 : 0.46;
        return;
    }

    CGFloat damping = (button == self.minusButton || button == self.plusButton) ? 0.65 : 0.82;
    CGFloat velocity = (button == self.minusButton || button == self.plusButton) ? 0.5 : 0.0;
    CGFloat targetAlpha = 1.0;
    if (button == self.minusButton && [button isKindOfClass:[PPCartStepperKeyButton class]] && ((PPCartStepperKeyButton *)button).isAtLimitFloor) {
        targetAlpha = 0.32;
    } else if (button == self.plusButton && [button isKindOfClass:[PPCartStepperKeyButton class]] && ((PPCartStepperKeyButton *)button).isAtLimitCeiling) {
        targetAlpha = 0.35;
    } else if (!button.userInteractionEnabled) {
        targetAlpha = 0.46;
    }

    [UIView animateWithDuration:PPAnimDurationNormal
                          delay:0.0
         usingSpringWithDamping:damping
          initialSpringVelocity:velocity
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        button.transform = CGAffineTransformIdentity;
        button.alpha = targetAlpha;
    } completion:nil];
}

- (void)pp_animateSavedForLaterActionFromButton:(UIButton *)button
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    UIView *targetButton = button ?: self.plusButton;
    UIView *animatingRow = self.savedForLaterMode ? self.savedActionsRow : self.bottomRow;
    animatingRow.transform = CGAffineTransformMakeScale(0.992, 0.992);
    targetButton.transform = CGAffineTransformMakeScale(0.94, 0.94);

    [UIView animateWithDuration:0.30
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        animatingRow.transform = CGAffineTransformIdentity;
        targetButton.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)playSavedForLaterArrivalAnimation
{
    [self playSavedForLaterArrivalAnimationWithCompletion:nil];
}

- (void)playSavedForLaterArrivalAnimationWithCompletion:(dispatch_block_t)completion
{
    [self pp_resetTransientMotion];
    NSUInteger animationToken = self.savedArrivalAnimationToken;
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    self.cardContainer.alpha = 0;
    if (!reduceMotion) self.cardContainer.transform = CGAffineTransformMakeTranslation(0, PPSpaceSM);
    [UIView animateWithDuration:reduceMotion ? 0.15 : kPPCartSavedArrivalDuration
                          delay:0
         usingSpringWithDamping:0.93
          initialSpringVelocity:0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.cardContainer.alpha = 1;
        self.cardContainer.transform = CGAffineTransformIdentity;
    } completion:^(__unused BOOL finished) {
        if (self.savedArrivalAnimationToken == animationToken) {
            self.cardContainer.alpha = 1;
            self.cardContainer.transform = CGAffineTransformIdentity;
        }
        // The controller owns row-mutation completion even if reuse interrupts motion.
        if (completion) completion();
    }];
}

- (void)pp_preparePriceAnimationIncreasing:(BOOL)increasing
{
    // Animate the presentation only; the model and accessibility value update immediately.
    if (!self.window || self.savedForLaterMode ||
        UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    NSString *nextAmount = PPCartIsolatedText([PPChatsFunc formattedCurrency:self.currentItem.lineSubtotal]);
    if ([self.lineTotalLabel.text isEqualToString:nextAmount]) return;

    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    CATransition *transition = [CATransition animation];
    transition.duration = reduceMotion ? 0.12 : 0.22;
    transition.type = reduceMotion ? kCATransitionFade : kCATransitionPush;
    if (!reduceMotion) transition.subtype = increasing ? kCATransitionFromTop : kCATransitionFromBottom;
    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    // Replacing one keyed transition keeps rapid taps responsive without queued animations.
    [self.lineTotalLabel.layer addAnimation:transition forKey:@"PPCartPriceChange"];
}

- (void)pp_animateQuantityChangeWithIncreasing:(BOOL)increasing
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    if ([self.quantityControlView isKindOfClass:[PPCartStepperCapsuleView class]]) {
        [(PPCartStepperCapsuleView *)self.quantityControlView playBreathPulseAnimationWithIncreasing:increasing];
    }

    CATransition *transition = [CATransition animation];
    transition.duration = 0.22;
    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    transition.type = kCATransitionPush;
    transition.subtype = increasing ? kCATransitionFromTop : kCATransitionFromBottom;
    [self.quantityLabel.layer addAnimation:transition forKey:@"PPCartQuantityDrumRoll"];

    self.quantityLabel.transform = CGAffineTransformMakeScale(1.08, 1.08);
    [UIView animateWithDuration:0.24
                          delay:0.0
         usingSpringWithDamping:0.72
          initialSpringVelocity:0.4
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.quantityLabel.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end
