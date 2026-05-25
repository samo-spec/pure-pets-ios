//
//  PPNovaMessageBubbleCell.m
//  Pure Pets
//

#import "PPNovaMessageBubbleCell.h"
#import <math.h>
#import <QuartzCore/QuartzCore.h>

static UIColor *PPNovaCellDynamicColor(UIColor *lightColor, UIColor *darkColor) {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
        }];
    }
    return lightColor;
}

static BOOL PPNovaTextStartsRTL(NSString *text) {
    if (text.length == 0) return Language.isRTL;
    
    // Check if the string contains *any* Arabic character to decide direction,
    // rather than failing if it starts with an English brand name or punctuation.
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if ((c >= 0x0600 && c <= 0x06FF) ||
            (c >= 0x0750 && c <= 0x077F) ||
            (c >= 0x08A0 && c <= 0x08FF)) {
            return YES;
        }
    }
    return NO;
}

static UISemanticContentAttribute PPNovaSemanticForText(NSString *text) {
    return PPNovaTextStartsRTL(text)
        ? UISemanticContentAttributeForceRightToLeft
        : UISemanticContentAttributeForceLeftToRight;
}

static NSTextAlignment PPNovaAlignmentForText(NSString *text) {
    return PPNovaTextStartsRTL(text) ? NSTextAlignmentRight : NSTextAlignmentLeft;
}

static const CGFloat PPNovaBubbleMinimumWidth = 96.0;
static const CGFloat PPNovaAssistantMinimumReadableWidth = 220.0;
static const CGFloat PPNovaAssistantMaximumReadableFloor = 320.0;
static const CGFloat PPNovaAssistantReadableWidthRatio = 0.62;
static const CGFloat PPNovaAssistantWrappedWidthFloorRatio = 0.78;
static const CGFloat PPNovaAssistantOptionsMinimumWidth = 242.0;
static const CGFloat PPNovaAssistantHorizontalReserve = 96.0;
static const CGFloat PPNovaUserHorizontalReserve = 86.0;
static const CGFloat PPNovaBubbleHorizontalContentInset = 34.0;
static const CGFloat PPNovaBubbleCornerRadius = 26.0;
static const CGFloat PPNovaBubbleWidthSearchStep = 8.0;
static const CGFloat PPNovaTypingAnimationWidth = 58.0;
static const CGFloat PPNovaTypingAnimationHeight = 58.0;
static const CGFloat PPNovaThinkingSignalWidth = 76.0;
static const CGFloat PPNovaThinkingSignalHeight = 34.0;
static const CGFloat PPNovaThinkingDotSize = 6.0;
static const NSUInteger PPNovaMaximumFallbackTextItems = 5;
static NSString * const PPNovaTypingAnimationResourceName = @"NovaTyping";
static NSString * const PPNovaTypingBubbleFillBreathAnimationKey = @"pp_nova_typing_bubble_fill_breath";
static NSString * const PPNovaTypingBubbleColorShiftAnimationKey = @"pp_nova_typing_bubble_color_shift";
static NSString * const PPNovaTypingBubbleAlphaAnimationKey = @"pp_nova_typing_bubble_alpha";

@interface PPNovaMessageBubbleCell ()

@property (nonatomic, strong) UIView *avatarView;
@property (nonatomic, strong) UILabel *avatarLabel;
@property (nonatomic, strong) UIView *bubbleShadowView;
@property (nonatomic, strong) UIVisualEffectView *bubbleMaterialView;
@property (nonatomic, strong) UIView *typingAuraView;
@property (nonatomic, strong) CAGradientLayer *typingAuraGradientLayer;
@property (nonatomic, strong) UIView *typingSignalView;
@property (nonatomic, strong) CAGradientLayer *typingSignalGradientLayer;
@property (nonatomic, copy) NSArray<UIView *> *typingDotViews;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIStackView *metaStack;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UIImageView *statusImageView;
@property (nonatomic, strong) LOTAnimationView *typingAnimationView;
@property (nonatomic, strong) UIStackView *actionStack;

@property (nonatomic, strong) NSLayoutConstraint *bubbleWidthConstraint;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *assistantConstraints;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *userConstraints;
@property (nonatomic, assign) CGFloat configuredMaxWidth;

@property (nonatomic, strong, nullable) ChatMessageModel *messageModel;
@property (nonatomic, assign) BOOL assistantMessage;
@property (nonatomic, assign) BOOL typingMode;
@property (nonatomic, assign) BOOL typingAnimationLoaded;
@property (nonatomic, assign) BOOL typingLiveMotionActive;

@end

@implementation PPNovaMessageBubbleCell

+ (NSString *)reuseIdentifier {
    return @"PPNovaMessageBubbleCell";
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];

    self.messageModel = nil;
    self.typingMode = NO;
    self.messageLabel.text = nil;
    self.messageLabel.attributedText = nil;
    self.timeLabel.text = nil;
    self.statusImageView.image = nil;
    self.statusImageView.hidden = YES;
    self.statusImageView.transform = CGAffineTransformIdentity;
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.messageLabel.hidden = NO;
    self.typingAnimationView.hidden = YES;
    self.typingSignalView.hidden = YES;
    [self setActionTitles:nil];
    [self pp_stopTypingAnimation];
    self.alpha = 1.0;
    self.transform = CGAffineTransformIdentity;
    self.contentView.transform = CGAffineTransformIdentity;
}

- (void)layoutSubviews {
    CGFloat currentWidth = CGRectGetWidth(self.contentView.bounds);
    if (currentWidth > 1.0 && fabs(currentWidth - self.configuredMaxWidth) > 0.5) {
        self.configuredMaxWidth = [self pp_resolvedContainerWidthForCandidate:currentWidth];
        [self pp_applyAlignmentForAssistant:self.assistantMessage maxWidth:self.configuredMaxWidth];
    }

    [super layoutSubviews];

    // Snap layer geometry without implicit CALayer animations. During the keyboard
    // show/hide animation the table reframes and re-lays out its visible cells; if
    // shadowPath / gradient-layer frames animate implicitly with a competing timing,
    // the bubble shadows visibly shake. Disabling actions makes them update instantly.
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.bubbleShadowView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bubbleShadowView.bounds
                                                                        cornerRadius:self.bubbleMaterialView.layer.cornerRadius].CGPath;
    self.typingAuraGradientLayer.frame = self.typingAuraView.bounds;
    self.typingSignalGradientLayer.frame = self.typingSignalView.bounds;
    [CATransaction commit];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];

    if (!self.window) {
        [self.typingAnimationView stop];
        [self pp_stopTypingLiveMotion];
        return;
    }

    if (self.typingMode) {
        [self pp_startTypingAnimation];
    }
}

- (void)setupUI {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;
    self.contentView.clipsToBounds = NO;
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIColor *brand = AppPrimaryClr ?: UIColor.systemOrangeColor;
    self.avatarView = [[UIView alloc] init];
    self.avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarView.backgroundColor = PPNovaCellDynamicColor([brand colorWithAlphaComponent:0.16],
                                                            [brand colorWithAlphaComponent:0.22]);
    self.avatarView.layer.cornerRadius = 13.0;
    self.avatarView.layer.masksToBounds = NO;
    self.avatarView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.avatarView.layer.borderColor = [brand colorWithAlphaComponent:0.18].CGColor;
    self.avatarView.layer.shadowColor = brand.CGColor;
    self.avatarView.layer.shadowOpacity = 0.10;
    self.avatarView.layer.shadowRadius = 8.0;
    self.avatarView.layer.shadowOffset = CGSizeMake(0.0, 3.0);
    if (@available(iOS 13.0, *)) {
        self.avatarView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:self.avatarView];

    self.avatarLabel = [[UILabel alloc] init];
    self.avatarLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarLabel.text = @"N";
    self.avatarLabel.textAlignment = NSTextAlignmentCenter;
    self.avatarLabel.font = [GM boldFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold];
    self.avatarLabel.textColor = brand;
    [self.avatarView addSubview:self.avatarLabel];

    self.bubbleShadowView = [[UIView alloc] init];
    self.bubbleShadowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bubbleShadowView.backgroundColor = UIColor.clearColor;
    self.bubbleShadowView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.bubbleShadowView.layer.shadowOpacity = 0.08;
    self.bubbleShadowView.layer.shadowRadius = 20.0;
    self.bubbleShadowView.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    self.bubbleShadowView.layer.shouldRasterize = YES;
    self.bubbleShadowView.layer.rasterizationScale = UIScreen.mainScreen.scale;
    [self.contentView addSubview:self.bubbleShadowView];

    UIBlurEffectStyle blurStyle = UIBlurEffectStyleRegular;
    if (@available(iOS 13.0, *)) {
        blurStyle = UIBlurEffectStyleSystemUltraThinMaterial;
    }
    self.bubbleMaterialView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:blurStyle]];
    self.bubbleMaterialView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bubbleMaterialView.layer.cornerRadius = PPNovaBubbleCornerRadius;
    self.bubbleMaterialView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.bubbleMaterialView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:self.bubbleMaterialView];

    self.typingAuraView = [[UIView alloc] init];
    self.typingAuraView.translatesAutoresizingMaskIntoConstraints = NO;
    self.typingAuraView.userInteractionEnabled = NO;
    self.typingAuraView.hidden = YES;
    self.typingAuraView.alpha = 0.0;
    self.typingAuraView.backgroundColor = UIColor.clearColor;
    [self.bubbleMaterialView.contentView addSubview:self.typingAuraView];

    self.typingAuraGradientLayer = [CAGradientLayer layer];
    self.typingAuraGradientLayer.startPoint = CGPointMake(0.0, 0.5);
    self.typingAuraGradientLayer.endPoint = CGPointMake(1.0, 0.5);
    self.typingAuraGradientLayer.locations = @[@(0.00), @(0.18), @(0.42), @(0.72)];
    [self.typingAuraView.layer addSublayer:self.typingAuraGradientLayer];

    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.alignment = UIStackViewAlignmentLeading;
    self.contentStack.spacing = 7.0;
    [self.bubbleMaterialView.contentView addSubview:self.contentStack];

    self.messageLabel = [[UILabel alloc] init];
    self.messageLabel.numberOfLines = 0;
    self.messageLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.messageLabel.textAlignment = GM.setAligment;
    UIFont *bodyFont = [GM MidFontWithSize:PPFontCallout] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
    self.messageLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:bodyFont];
    self.messageLabel.adjustsFontForContentSizeCategory = YES;
    [self.messageLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self.messageLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.messageLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.contentStack addArrangedSubview:self.messageLabel];

    self.typingSignalView = [[UIView alloc] init];
    self.typingSignalView.translatesAutoresizingMaskIntoConstraints = NO;
    self.typingSignalView.hidden = YES;
    self.typingSignalView.alpha = 0.0;
    self.typingSignalView.clipsToBounds = YES;
    self.typingSignalView.userInteractionEnabled = NO;
    self.typingSignalView.layer.cornerRadius = PPNovaThinkingSignalHeight / 2.0;
    self.typingSignalView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    if (@available(iOS 13.0, *)) {
        self.typingSignalView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentStack addArrangedSubview:self.typingSignalView];
    [NSLayoutConstraint activateConstraints:@[
        [self.typingSignalView.widthAnchor constraintEqualToConstant:PPNovaThinkingSignalWidth],
        [self.typingSignalView.heightAnchor constraintEqualToConstant:PPNovaThinkingSignalHeight]
    ]];

    self.typingSignalGradientLayer = [CAGradientLayer layer];
    self.typingSignalGradientLayer.startPoint = CGPointMake(0.0, 0.5);
    self.typingSignalGradientLayer.endPoint = CGPointMake(1.0, 0.5);
    self.typingSignalGradientLayer.locations = @[@(0.00), @(0.26), @(0.54), @(1.00)];
    [self.typingSignalView.layer addSublayer:self.typingSignalGradientLayer];

    NSMutableArray<UIView *> *dots = [NSMutableArray arrayWithCapacity:3];
    CGFloat firstDotLeading = 21.0;
    CGFloat dotSpacing = 14.0;
    for (NSInteger index = 0; index < 3; index++) {
        UIView *dotView = [[UIView alloc] init];
        dotView.translatesAutoresizingMaskIntoConstraints = NO;
        dotView.userInteractionEnabled = NO;
        dotView.layer.cornerRadius = PPNovaThinkingDotSize / 2.0;
        if (@available(iOS 13.0, *)) {
            dotView.layer.cornerCurve = kCACornerCurveCircular;
        }
        [self.typingSignalView addSubview:dotView];
        [NSLayoutConstraint activateConstraints:@[
            [dotView.widthAnchor constraintEqualToConstant:PPNovaThinkingDotSize],
            [dotView.heightAnchor constraintEqualToConstant:PPNovaThinkingDotSize],
            [dotView.centerYAnchor constraintEqualToAnchor:self.typingSignalView.centerYAnchor],
            [dotView.leadingAnchor constraintEqualToAnchor:self.typingSignalView.leadingAnchor
                                                  constant:firstDotLeading + (dotSpacing * index)]
        ]];
        [dots addObject:dotView];
    }
    self.typingDotViews = dots.copy;

    self.typingAnimationView = [[LOTAnimationView alloc] init];
    self.typingAnimationView.translatesAutoresizingMaskIntoConstraints = NO;
    self.typingAnimationView.contentMode = UIViewContentModeScaleAspectFill;
    self.typingAnimationView.loopAnimation = YES;
    self.typingAnimationView.animationSpeed = 0.72;
    self.typingAnimationView.userInteractionEnabled = NO;
    self.typingAnimationView.backgroundColor = UIColor.clearColor;
    self.typingAnimationView.hidden = YES;
    self.typingAnimationView.alpha = 0.0;
    self.typingAnimationView.clipsToBounds = YES;
    [self.contentStack addArrangedSubview:self.typingAnimationView];
    [NSLayoutConstraint activateConstraints:@[
        [self.typingAnimationView.widthAnchor constraintEqualToConstant:PPNovaTypingAnimationWidth],
        [self.typingAnimationView.heightAnchor constraintEqualToConstant:PPNovaTypingAnimationHeight]
    ]];

    self.actionStack = [[UIStackView alloc] init];
    self.actionStack.axis = UILayoutConstraintAxisVertical;
    self.actionStack.alignment = UIStackViewAlignmentFill;
    self.actionStack.spacing = 8.0;
    self.actionStack.hidden = YES;
    [self.contentStack addArrangedSubview:self.actionStack];

    self.metaStack = [[UIStackView alloc] init];
    self.metaStack.axis = UILayoutConstraintAxisHorizontal;
    self.metaStack.alignment = UIStackViewAlignmentCenter;
    self.metaStack.spacing = 5.0;
    [self.contentStack addArrangedSubview:self.metaStack];

    self.timeLabel = [[UILabel alloc] init];
    self.timeLabel.font = [GM fontWithSize:PPFontCaption2] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightRegular];
    self.timeLabel.adjustsFontForContentSizeCategory = YES;
    [self.metaStack addArrangedSubview:self.timeLabel];

    self.statusImageView = [[UIImageView alloc] init];
    self.statusImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.statusImageView.hidden = YES;
    [self.metaStack addArrangedSubview:self.statusImageView];
    [NSLayoutConstraint activateConstraints:@[
        [self.statusImageView.widthAnchor constraintEqualToConstant:12.0],
        [self.statusImageView.heightAnchor constraintEqualToConstant:12.0]
    ]];

    //[self.contentStack setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    //[self.contentStack setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];

    self.bubbleWidthConstraint = [self.bubbleShadowView.widthAnchor constraintEqualToConstant:PPNovaBubbleMinimumWidth];
    self.bubbleWidthConstraint.priority = UILayoutPriorityRequired;
    self.bubbleWidthConstraint.active = YES;

    NSLayoutConstraint *avatarEdge = [self.avatarView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0];
    NSLayoutConstraint *assistantPrimary = [self.bubbleShadowView.trailingAnchor constraintEqualToAnchor:self.avatarView.leadingAnchor constant:-8.0];
    NSLayoutConstraint *assistantLimit = [self.bubbleShadowView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.contentView.leadingAnchor constant:70.0];
    NSLayoutConstraint *userPrimary = [self.bubbleShadowView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0];
    NSLayoutConstraint *userLimit = [self.bubbleShadowView.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-70.0];
    assistantLimit.priority = UILayoutPriorityDefaultHigh;
    userLimit.priority = UILayoutPriorityDefaultHigh;

    self.assistantConstraints = @[assistantPrimary, assistantLimit];
    self.userConstraints = @[userPrimary, userLimit];

    [NSLayoutConstraint activateConstraints:@[
        avatarEdge,
        [self.avatarView.topAnchor constraintEqualToAnchor:self.bubbleShadowView.topAnchor constant:3.0],
        [self.avatarView.widthAnchor constraintEqualToConstant:26.0],
        [self.avatarView.heightAnchor constraintEqualToConstant:26.0],

        [self.avatarLabel.topAnchor constraintEqualToAnchor:self.avatarView.topAnchor],
        [self.avatarLabel.leadingAnchor constraintEqualToAnchor:self.avatarView.leadingAnchor],
        [self.avatarLabel.trailingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor],
        [self.avatarLabel.bottomAnchor constraintEqualToAnchor:self.avatarView.bottomAnchor],

        [self.bubbleShadowView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5.0],
        [self.bubbleShadowView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5.0],

        [self.bubbleMaterialView.topAnchor constraintEqualToAnchor:self.bubbleShadowView.topAnchor],
        [self.bubbleMaterialView.leadingAnchor constraintEqualToAnchor:self.bubbleShadowView.leadingAnchor],
        [self.bubbleMaterialView.trailingAnchor constraintEqualToAnchor:self.bubbleShadowView.trailingAnchor],
        [self.bubbleMaterialView.bottomAnchor constraintEqualToAnchor:self.bubbleShadowView.bottomAnchor],

        [self.typingAuraView.topAnchor constraintEqualToAnchor:self.bubbleMaterialView.contentView.topAnchor],
        [self.typingAuraView.leadingAnchor constraintEqualToAnchor:self.bubbleMaterialView.contentView.leadingAnchor],
        [self.typingAuraView.trailingAnchor constraintEqualToAnchor:self.bubbleMaterialView.contentView.trailingAnchor],
        [self.typingAuraView.bottomAnchor constraintEqualToAnchor:self.bubbleMaterialView.contentView.bottomAnchor],

        [self.contentStack.topAnchor constraintEqualToAnchor:self.bubbleMaterialView.contentView.topAnchor constant:18.0],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.bubbleMaterialView.contentView.leadingAnchor constant:17.0],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.bubbleMaterialView.contentView.trailingAnchor constant:-17.0],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.bubbleMaterialView.contentView.bottomAnchor constant:-16.0]
    ]];

    [self pp_applyStyleForAssistant:YES typing:NO];
}

- (UIFont *)pp_scaledFont:(UIFont *)font textStyle:(UIFontTextStyle)textStyle {
    UIFont *safeFont = font ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
    UIFont *baseFont = nil;
    if (safeFont.fontName.length > 0) {
        baseFont = [UIFont fontWithName:safeFont.fontName size:safeFont.pointSize];
    }
    if (!baseFont) {
        UIFontDescriptorSymbolicTraits traits = safeFont.fontDescriptor.symbolicTraits;
        UIFontWeight weight = (traits & UIFontDescriptorTraitBold) ? UIFontWeightBold : UIFontWeightRegular;
        baseFont = [UIFont systemFontOfSize:safeFont.pointSize weight:weight];
    }
    return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:baseFont];
}

- (UIFont *)pp_boldFontFromFont:(UIFont *)font {
    UIFontDescriptor *descriptor = [font.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
    return descriptor ? [UIFont fontWithDescriptor:descriptor size:font.pointSize] : [UIFont boldSystemFontOfSize:font.pointSize];
}

- (UIFont *)pp_semiboldFontFromFont:(UIFont *)font {
    UIFontDescriptor *descriptor = [font.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
    return descriptor ? [UIFont fontWithDescriptor:descriptor size:font.pointSize] : [UIFont systemFontOfSize:font.pointSize weight:UIFontWeightSemibold];
}

- (NSMutableParagraphStyle *)pp_paragraphStyleForText:(NSString *)text
                                             lineKind:(NSString *)lineKind
                                                  rtl:(BOOL)rtl {
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineBreakMode = NSLineBreakByWordWrapping;
    style.alignment = rtl ? NSTextAlignmentRight : NSTextAlignmentLeft;
    style.baseWritingDirection = rtl ? NSWritingDirectionRightToLeft : NSWritingDirectionLeftToRight;
    style.lineSpacing = 3.0;
    style.paragraphSpacing = 6.0;
    style.paragraphSpacingBefore = 0.0;

    if ([lineKind isEqualToString:@"header"]) {
        style.lineSpacing = 3.5;
        style.paragraphSpacing = 10.0;
    } else if ([lineKind isEqualToString:@"section"]) {
        style.lineSpacing = 3.0;
        style.paragraphSpacing = 8.0;
        style.paragraphSpacingBefore = 3.0;
    } else if ([lineKind isEqualToString:@"item"] || [lineKind isEqualToString:@"meta"]) {
        style.lineSpacing = 2.5;
        style.paragraphSpacing = 7.0;
        style.headIndent = 17.0;
        style.firstLineHeadIndent = 0.0;
        if (rtl) {
            style.tailIndent = -17.0;
        }
    }
    return style;
}

- (NSDictionary<NSAttributedStringKey, id> *)pp_attributesWithFont:(UIFont *)font
                                                             color:(UIColor *)color
                                                         paragraph:(NSParagraphStyle *)paragraph {
    return @{
        NSFontAttributeName: font ?: [UIFont systemFontOfSize:16.0],
        NSForegroundColorAttributeName: color ?: UIColor.labelColor,
        NSParagraphStyleAttributeName: paragraph ?: [NSParagraphStyle defaultParagraphStyle]
    };
}

- (NSString *)pp_textByNormalizingNovaAnswerSpacing:(NSString *)text {
    if (text.length == 0) return @"";

    NSMutableString *result = [NSMutableString stringWithCapacity:text.length];
    NSCharacterSet *decimalSet = [NSCharacterSet decimalDigitCharacterSet];
    for (NSUInteger idx = 0; idx < text.length; idx++) {
        unichar current = [text characterAtIndex:idx];
        if (idx > 0) {
            unichar previous = [text characterAtIndex:idx - 1];
            BOOL previousArabic = ((previous >= 0x0600 && previous <= 0x06FF) ||
                                   (previous >= 0x0750 && previous <= 0x077F) ||
                                   (previous >= 0x08A0 && previous <= 0x08FF));
            BOOL currentArabic = ((current >= 0x0600 && current <= 0x06FF) ||
                                  (current >= 0x0750 && current <= 0x077F) ||
                                  (current >= 0x08A0 && current <= 0x08FF));
            BOOL previousDigit = [decimalSet characterIsMember:previous];
            BOOL currentDigit = [decimalSet characterIsMember:current];
            BOOL previousIsSpace = [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:previous];
            BOOL currentIsSpace = [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:current];
            if (!previousIsSpace && !currentIsSpace &&
                ((previousArabic && currentDigit) || (previousDigit && currentArabic))) {
                [result appendString:@" "];
            }
        }
        [result appendFormat:@"%C", current];
    }

    NSArray<NSArray<NSString *> *> *replacements = @[
        @[@"بسعر\\s*(\\d)", @"بسعر $1"],
        @[@"السعر:\\s*(\\d)", @"السعر: $1"],
        @[@"الموقع:\\s*(\\S)", @"الموقع: $1"],
        @[@"النوع:\\s*(\\S)", @"النوع: $1"],
        @[@"Price:\\s*(\\d)", @"Price: $1"],
        @[@"Location:\\s*(\\S)", @"Location: $1"],
        @[@"Type:\\s*(\\S)", @"Type: $1"]
    ];
    NSString *normalized = result.copy;
    for (NSArray<NSString *> *pair in replacements) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pair.firstObject
                                                                               options:NSRegularExpressionCaseInsensitive
                                                                                 error:nil];
        if (!regex) continue;
        normalized = [regex stringByReplacingMatchesInString:normalized
                                                     options:0
                                                       range:NSMakeRange(0, normalized.length)
                                                withTemplate:pair.lastObject];
    }
    return normalized;
}

- (BOOL)pp_textContainsMarkdownSyntax:(NSString *)text {
    if (text.length == 0) return NO;
    NSArray<NSString *> *patterns = @[@"\\*\\*[^\\n]+\\*\\*", @"(^|\\n)\\s*#{2,3}\\s+", @"(^|\\n)\\s*[-•*]\\s+", @"(^|\\n)\\s*\\d+[\\.)]\\s+"];
    for (NSString *pattern in patterns) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
        if ([regex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)]) {
            return YES;
        }
    }
    return NO;
}

- (NSString *)pp_trimmedLine:(NSString *)line {
    return [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
}

- (BOOL)pp_line:(NSString *)line matchesPattern:(NSString *)pattern {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:nil];
    return [regex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)] != nil;
}

- (NSString *)pp_lineByRemovingPrefixWithPattern:(NSString *)pattern fromLine:(NSString *)line {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
    if (!match || match.numberOfRanges < 2) return line;
    return [line substringWithRange:[match rangeAtIndex:1]];
}

- (BOOL)pp_bodyLooksLikeGenericServiceOnly:(NSString *)body rtl:(BOOL)rtl {
    NSString *normalized = body.lowercaseString ?: @"";
    BOOL hasPrice = ([normalized rangeOfString:@"بسعر"].location != NSNotFound ||
                     [normalized rangeOfString:@"السعر"].location != NSNotFound ||
                     [normalized rangeOfString:@"price"].location != NSNotFound);
    if (!hasPrice) return NO;
    if (rtl) {
        return [self pp_line:normalized matchesPattern:@"^خدمة\\s*(?:بسعر|السعر|[:：])"];
    }
    return [self pp_line:normalized matchesPattern:@"^service\\s*(?:for|price|[:：])"];
}

- (BOOL)pp_bodyLooksLikeGenericProductOnly:(NSString *)body rtl:(BOOL)rtl {
    NSString *normalized = body.lowercaseString ?: @"";
    BOOL hasPrice = ([normalized rangeOfString:@"بسعر"].location != NSNotFound ||
                     [normalized rangeOfString:@"السعر"].location != NSNotFound ||
                     [normalized rangeOfString:@"price"].location != NSNotFound);
    if (!hasPrice) return NO;
    if (rtl) {
        return [self pp_line:normalized matchesPattern:@"^(?:منتج|عنصر)\\s*(?:بسعر|السعر|[:：])"];
    }
    return [self pp_line:normalized matchesPattern:@"^(?:product|item)\\s*(?:for|price|[:：])"];
}

- (NSString *)pp_priceValueFromBody:(NSString *)body {
    NSArray<NSString *> *patterns = @[
        @"(?:بسعر|السعر\\s*[:：]?)\\s*([^،,\\n]+)",
        @"(?:price\\s*[:：]?|for)\\s*([^,\\n]+)"
    ];
    for (NSString *pattern in patterns) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                               options:NSRegularExpressionCaseInsensitive
                                                                                 error:nil];
        NSTextCheckingResult *match = [regex firstMatchInString:body options:0 range:NSMakeRange(0, body.length)];
        if (match && match.numberOfRanges > 1) {
            return [[body substringWithRange:[match rangeAtIndex:1]] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        }
    }
    return @"";
}

- (NSString *)pp_titleCandidateBeforeMetadataInBody:(NSString *)body {
    NSArray<NSString *> *markers = @[@"بسعر", @"السعر", @"الموقع", @"النوع", @"الحالة", @"price", @"location", @"type", @"status", @"availability"];
    NSUInteger firstMarker = NSNotFound;
    NSString *lower = body.lowercaseString ?: @"";
    for (NSString *marker in markers) {
        NSRange range = [lower rangeOfString:marker.lowercaseString];
        if (range.location != NSNotFound) {
            firstMarker = firstMarker == NSNotFound ? range.location : MIN(firstMarker, range.location);
        }
    }
    if (firstMarker == NSNotFound || firstMarker == 0) return @"";
    NSString *title = [body substringToIndex:firstMarker];
    title = [title stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" -–—،,:：\t\n"]];
    return title ?: @"";
}

- (NSMutableAttributedString *)pp_inlineAttributedText:(NSString *)rawText
                                            attributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
                                              boldFont:(UIFont *)boldFont {
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
    NSString *text = rawText ?: @"";
    NSUInteger index = 0;
    while (index < text.length) {
        NSRange markerRange = [text rangeOfString:@"**" options:0 range:NSMakeRange(index, text.length - index)];
        if (markerRange.location == NSNotFound) {
            NSString *tail = [text substringFromIndex:index];
            if (tail.length > 0) {
                [result appendAttributedString:[[NSAttributedString alloc] initWithString:tail attributes:attributes]];
            }
            break;
        }

        if (markerRange.location > index) {
            NSString *prefix = [text substringWithRange:NSMakeRange(index, markerRange.location - index)];
            [result appendAttributedString:[[NSAttributedString alloc] initWithString:prefix attributes:attributes]];
        }

        NSUInteger contentStart = NSMaxRange(markerRange);
        NSRange closeRange = [text rangeOfString:@"**" options:0 range:NSMakeRange(contentStart, text.length - contentStart)];
        if (closeRange.location == NSNotFound) {
            NSString *rest = [text substringFromIndex:markerRange.location];
            [result appendAttributedString:[[NSAttributedString alloc] initWithString:rest attributes:attributes]];
            break;
        }

        NSString *boldText = [text substringWithRange:NSMakeRange(contentStart, closeRange.location - contentStart)];
        NSMutableDictionary *boldAttributes = attributes.mutableCopy;
        boldAttributes[NSFontAttributeName] = boldFont ?: attributes[NSFontAttributeName];
        [result appendAttributedString:[[NSAttributedString alloc] initWithString:boldText attributes:boldAttributes]];
        index = NSMaxRange(closeRange);
    }
    return result;
}

- (void)pp_applyBrandColorToAttributedString:(NSMutableAttributedString *)string
                                    fullRange:(NSRange)fullRange {
    if (fullRange.location == NSNotFound || NSMaxRange(fullRange) > string.length) return;
    UIColor *brandColor = AppPrimaryClr;
    if (!brandColor) return;
    NSArray<NSString *> *brandSpellings = @[
        @"بيور بتس",
        @"بيور بيتس",
        @"بيوربتس",
        @"بيوربيتس",
        @"PurePets",
        @"Pure Pets",
        @"purepets",
    ];
    NSString *substring = [string.string substringWithRange:fullRange];
    for (NSString *brand in brandSpellings) {
        NSRange searchRange = NSMakeRange(0, substring.length);
        while (searchRange.location < substring.length) {
            NSRange found = [substring rangeOfString:brand
                                             options:NSCaseInsensitiveSearch
                                               range:searchRange];
            if (found.location == NSNotFound) break;
            NSRange absolute = NSMakeRange(fullRange.location + found.location, found.length);
            [string addAttribute:NSForegroundColorAttributeName value:brandColor range:absolute];
            NSUInteger next = NSMaxRange(found);
            searchRange = NSMakeRange(next, substring.length - next);
        }
    }
}

- (void)pp_applyLabelStylingToAttributedString:(NSMutableAttributedString *)string
                                    fullRange:(NSRange)fullRange
                                     labelFont:(UIFont *)labelFont
                                    labelColor:(UIColor *)labelColor {
    if (fullRange.location == NSNotFound || NSMaxRange(fullRange) > string.length) return;
    NSArray<NSString *> *labels = @[
        @"السعر:", @"الموقع:", @"النوع:", @"الحالة:", @"المدينة:", @"المنطقة:", @"التوفر:",
        @"Price:", @"Location:", @"Type:", @"Status:", @"City:", @"Area:", @"Availability:"
    ];
    NSString *substring = [string.string substringWithRange:fullRange];
    for (NSString *label in labels) {
        NSRange searchRange = NSMakeRange(0, substring.length);
        while (searchRange.location < substring.length) {
            NSRange found = [substring rangeOfString:label options:NSCaseInsensitiveSearch range:searchRange];
            if (found.location == NSNotFound) break;
            NSRange absolute = NSMakeRange(fullRange.location + found.location, found.length);
            [string addAttribute:NSFontAttributeName value:labelFont range:absolute];
            [string addAttribute:NSForegroundColorAttributeName value:labelColor range:absolute];
            NSUInteger next = NSMaxRange(found);
            searchRange = NSMakeRange(next, substring.length - next);
        }
    }
}

- (void)pp_appendAttributedLine:(NSAttributedString *)line
                       toResult:(NSMutableAttributedString *)result {
    if (line.length == 0) return;
    if (result.length > 0) {
        [result appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
    }
    [result appendAttributedString:line];
}

- (void)pp_appendItemBody:(NSString *)body
                  ordinal:(nullable NSString *)ordinal
                   result:(NSMutableAttributedString *)result
                      rtl:(BOOL)rtl
                 bodyFont:(UIFont *)bodyFont
                 boldFont:(UIFont *)boldFont
                 metaFont:(UIFont *)metaFont
                textColor:(UIColor *)textColor
           secondaryColor:(UIColor *)secondaryColor
              accentColor:(UIColor *)accentColor
          fallbackContext:(NSString *)fallbackContext {
    NSString *cleanBody = [self pp_textByNormalizingNovaAnswerSpacing:[self pp_trimmedLine:body]];
    if (cleanBody.length == 0) return;

    BOOL genericService = [self pp_bodyLooksLikeGenericServiceOnly:cleanBody rtl:rtl];
    BOOL genericProduct = [self pp_bodyLooksLikeGenericProductOnly:cleanBody rtl:rtl];
    BOOL mentionsBirds = [fallbackContext rangeOfString:@"طيور"].location != NSNotFound ||
                         [fallbackContext.lowercaseString rangeOfString:@"bird"].location != NSNotFound;
    NSString *fallbackTitle = nil;
    if (genericService) {
        fallbackTitle = mentionsBirds ? kLang(@"nova_render_fallback_bird_service") : kLang(@"nova_render_fallback_service");
    } else if (genericProduct) {
        fallbackTitle = kLang(@"nova_render_fallback_product");
    }

    NSString *prefix = ordinal.length > 0 ? [NSString stringWithFormat:@"%@ ", ordinal] : @"• ";
    NSMutableParagraphStyle *itemParagraph = [self pp_paragraphStyleForText:cleanBody lineKind:@"item" rtl:rtl];
    NSDictionary *itemAttributes = [self pp_attributesWithFont:bodyFont color:textColor paragraph:itemParagraph];
    NSMutableDictionary *itemBoldAttributes = itemAttributes.mutableCopy;
    itemBoldAttributes[NSFontAttributeName] = boldFont;

    NSString *titleCandidate = fallbackTitle ?: [self pp_titleCandidateBeforeMetadataInBody:cleanBody];
    NSString *priceValue = [self pp_priceValueFromBody:cleanBody];
    if (titleCandidate.length > 0) {
        NSMutableAttributedString *titleLine = [[NSMutableAttributedString alloc] initWithString:prefix attributes:itemAttributes];
        [titleLine appendAttributedString:[[NSAttributedString alloc] initWithString:titleCandidate attributes:itemBoldAttributes]];
        [self pp_appendAttributedLine:titleLine toResult:result];

        if (priceValue.length > 0) {
            NSString *priceLineText = [NSString stringWithFormat:@"%@ %@", kLang(@"nova_render_price_label"), priceValue];
            NSMutableParagraphStyle *metaParagraph = [self pp_paragraphStyleForText:priceLineText lineKind:@"meta" rtl:rtl];
            NSDictionary *metaAttributes = [self pp_attributesWithFont:metaFont color:secondaryColor paragraph:metaParagraph];
            NSMutableAttributedString *metaLine = [[NSMutableAttributedString alloc] initWithString:priceLineText attributes:metaAttributes];
            [self pp_applyLabelStylingToAttributedString:metaLine
                                                fullRange:NSMakeRange(0, metaLine.length)
                                                labelFont:[self pp_semiboldFontFromFont:metaFont]
                                               labelColor:accentColor];
            [self pp_appendAttributedLine:metaLine toResult:result];
        }
        if (fallbackTitle.length > 0) {
            NSMutableParagraphStyle *metaParagraph = [self pp_paragraphStyleForText:kLang(@"nova_render_limited_details") lineKind:@"meta" rtl:rtl];
            NSDictionary *metaAttributes = [self pp_attributesWithFont:metaFont color:secondaryColor paragraph:metaParagraph];
            [self pp_appendAttributedLine:[[NSAttributedString alloc] initWithString:kLang(@"nova_render_limited_details") attributes:metaAttributes]
                                 toResult:result];
        }
        return;
    }

    NSMutableAttributedString *line = [[NSMutableAttributedString alloc] initWithString:prefix attributes:itemAttributes];
    [line appendAttributedString:[self pp_inlineAttributedText:cleanBody attributes:itemBoldAttributes boldFont:boldFont]];
    [self pp_applyLabelStylingToAttributedString:line
                                        fullRange:NSMakeRange(0, line.length)
                                        labelFont:[self pp_semiboldFontFromFont:metaFont]
                                       labelColor:accentColor];
    [self pp_applyBrandColorToAttributedString:line fullRange:NSMakeRange(0, line.length)];
    [self pp_appendAttributedLine:line toResult:result];
}

- (NSAttributedString *)pp_attributedStringFromNovaText:(NSString *)text
                                             baseFont:(UIFont *)font
                                            textColor:(UIColor *)textColor
                                       secondaryColor:(UIColor *)secondaryColor
                                          accentColor:(UIColor *)accentColor
                                     containsMarkdown:(BOOL *)containsMarkdown
                                      fallbackItemCount:(NSUInteger *)fallbackItemCount
                                                success:(BOOL *)success {
    NSString *normalizedText = [self pp_textByNormalizingNovaAnswerSpacing:text ?: @""];
    BOOL rtl = PPNovaTextStartsRTL(normalizedText);
    BOOL markdown = [self pp_textContainsMarkdownSyntax:normalizedText];
    if (containsMarkdown) *containsMarkdown = markdown;
    if (fallbackItemCount) *fallbackItemCount = 0;
    if (success) *success = NO;
    if (normalizedText.length == 0) {
        if (success) *success = YES;
        return [[NSAttributedString alloc] initWithString:@"" attributes:@{}];
    }

    UIFont *bodyFont = [self pp_scaledFont:(font ?: ([GM MidFontWithSize:PPFontCallout] ?: [UIFont systemFontOfSize:16.0]))
                                  textStyle:UIFontTextStyleBody];
    UIFont *headerFont = [self pp_scaledFont:([GM boldFontWithSize:PPFontTitle3] ?: [UIFont systemFontOfSize:20.0 weight:UIFontWeightBold])
                                   textStyle:UIFontTextStyleHeadline];
    UIFont *sectionFont = [self pp_scaledFont:([GM boldFontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold])
                                    textStyle:UIFontTextStyleSubheadline];
    UIFont *itemFont = [self pp_scaledFont:([GM boldFontWithSize:PPFontCallout] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold])
                                 textStyle:UIFontTextStyleBody];
    UIFont *metaFont = [self pp_scaledFont:([GM MidFontWithSize:PPFontFootnote] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightRegular])
                                 textStyle:UIFontTextStyleFootnote];

    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
    NSArray<NSString *> *rawLines = [normalizedText componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (NSString *rawLine in rawLines) {
        NSString *line = [self pp_trimmedLine:rawLine];
        if (line.length > 0) {
            [lines addObject:line];
        }
    }

    NSUInteger itemCount = 0;
    NSUInteger skippedItemCount = 0;
    BOOL hasList = NO;
    for (NSString *line in lines) {
        if ([self pp_line:line matchesPattern:@"^\\s*(?:[-•*]\\s+|\\d+[\\.)]\\s+)"]) {
            hasList = YES;
            break;
        }
    }

    for (NSUInteger idx = 0; idx < lines.count; idx++) {
        NSString *line = lines[idx];
        NSString *kind = @"body";
        NSString *renderText = line;
        NSString *ordinal = nil;

        if ([line hasPrefix:@"### "]) {
            kind = @"section";
            renderText = [self pp_trimmedLine:[line substringFromIndex:4]];
        } else if ([line hasPrefix:@"## "]) {
            kind = @"header";
            renderText = [self pp_trimmedLine:[line substringFromIndex:3]];
        } else if ([self pp_line:line matchesPattern:@"^\\s*[-•*]\\s+(.+)$"]) {
            kind = @"item";
            renderText = [self pp_lineByRemovingPrefixWithPattern:@"^\\s*[-•*]\\s+(.+)$" fromLine:line];
        } else if ([self pp_line:line matchesPattern:@"^\\s*(\\d+[\\.)])\\s+(.+)$"]) {
            kind = @"item";
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^\\s*(\\d+[\\.)])\\s+(.+)$"
                                                                                   options:0
                                                                                     error:nil];
            NSTextCheckingResult *match = [regex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
            if (match.numberOfRanges > 2) {
                ordinal = [line substringWithRange:[match rangeAtIndex:1]];
                renderText = [line substringWithRange:[match rangeAtIndex:2]];
            }
        } else if (idx == 0 && hasList && line.length <= 96) {
            kind = @"header";
        }

        if ([kind isEqualToString:@"item"]) {
            itemCount++;
            if (itemCount > PPNovaMaximumFallbackTextItems) {
                skippedItemCount++;
                continue;
            }
            [self pp_appendItemBody:renderText
                            ordinal:ordinal
                             result:result
                                rtl:rtl
                           bodyFont:bodyFont
                           boldFont:itemFont
                           metaFont:metaFont
                          textColor:textColor
                     secondaryColor:secondaryColor
                        accentColor:accentColor
                    fallbackContext:normalizedText];
            continue;
        }

        UIFont *lineFont = bodyFont;
        UIColor *lineColor = textColor;
        if ([kind isEqualToString:@"header"]) {
            lineFont = headerFont;
        } else if ([kind isEqualToString:@"section"]) {
            lineFont = sectionFont;
        } else if ([self pp_line:line matchesPattern:@"(?i)(تحذير|تنبيه|مهم|warning|safety|important)"]) {
            lineFont = [self pp_semiboldFontFromFont:bodyFont];
            lineColor = textColor;
        }

        NSMutableParagraphStyle *paragraph = [self pp_paragraphStyleForText:renderText lineKind:kind rtl:rtl];
        NSDictionary *attributes = [self pp_attributesWithFont:lineFont color:lineColor paragraph:paragraph];
        NSMutableAttributedString *lineString = [self pp_inlineAttributedText:renderText
                                                                   attributes:attributes
                                                                     boldFont:[self pp_boldFontFromFont:lineFont]];
        [self pp_applyLabelStylingToAttributedString:lineString
                                            fullRange:NSMakeRange(0, lineString.length)
                                            labelFont:[self pp_semiboldFontFromFont:metaFont]
                                           labelColor:accentColor];
        [self pp_applyBrandColorToAttributedString:lineString fullRange:NSMakeRange(0, lineString.length)];
        [self pp_appendAttributedLine:lineString toResult:result];
    }

    if (skippedItemCount > 0) {
        NSString *hint = kLang(@"nova_render_more_results_hint");
        NSMutableParagraphStyle *paragraph = [self pp_paragraphStyleForText:hint lineKind:@"meta" rtl:rtl];
        NSDictionary *attributes = [self pp_attributesWithFont:metaFont color:secondaryColor paragraph:paragraph];
        [self pp_appendAttributedLine:[[NSAttributedString alloc] initWithString:hint attributes:attributes] toResult:result];
    }

    if (fallbackItemCount) *fallbackItemCount = itemCount;
    if (success) *success = result.length > 0;
    return result.length > 0 ? result : [[NSAttributedString alloc] initWithString:normalizedText
                                                                        attributes:[self pp_attributesWithFont:bodyFont
                                                                                                          color:textColor
                                                                                                      paragraph:[self pp_paragraphStyleForText:normalizedText lineKind:@"body" rtl:rtl]]];
}

- (NSString *)pp_currentPlainMessageText {
    if (self.messageLabel.attributedText.string.length > 0) {
        return self.messageLabel.attributedText.string;
    }
    return self.messageLabel.text ?: @"";
}

- (void)configureWithMessage:(ChatMessageModel *)messageModel maxWidth:(CGFloat)maxWidth {
    self.messageModel = messageModel;
    self.typingMode = NO;
    self.assistantMessage = [messageModel.senderID isEqualToString:@"nova_bot_id"];
    CGFloat resolvedMaxWidth = [self pp_resolvedContainerWidthForCandidate:maxWidth];
    self.configuredMaxWidth = resolvedMaxWidth;
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.contentView.bounds = CGRectMake(0.0, 0.0, resolvedMaxWidth, CGRectGetHeight(self.contentView.bounds));

    self.messageLabel.hidden = NO;
    self.typingAnimationView.hidden = YES;
    self.typingSignalView.hidden = YES;
    self.messageLabel.attributedText = nil;
    self.messageLabel.text = self.assistantMessage ? nil : (messageModel.text ?: @"");
    [self pp_applyStyleForAssistant:self.assistantMessage typing:NO];
    [self setActionTitles:[self pp_actionTitlesFromMessage:messageModel]];
    self.timeLabel.text = [self pp_formattedTime:messageModel.timestamp];
    [self pp_stopTypingAnimation];
    [self pp_configureStatusForMessage:messageModel];
    [self pp_applyAlignmentForAssistant:self.assistantMessage maxWidth:resolvedMaxWidth];
    [self setNeedsLayout];
    [self layoutIfNeeded];

    self.accessibilityLabel = [self pp_currentPlainMessageText];
}

- (void)setNovaStarred:(BOOL)starred {
    if (!starred) {
        self.statusImageView.image = nil;
        self.statusImageView.hidden = YES;
        self.statusImageView.transform = CGAffineTransformIdentity;
        return;
    }

    UIImage *starImage = nil;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:10.5
                                                                                                    weight:UIImageSymbolWeightSemibold];
        starImage = [UIImage systemImageNamed:@"star.fill" withConfiguration:configuration];
    }
    self.statusImageView.image = starImage;
    self.statusImageView.tintColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    self.statusImageView.hidden = (starImage == nil);

    if (!UIAccessibilityIsReduceMotionEnabled() && starImage) {
        self.statusImageView.transform = CGAffineTransformMakeScale(0.72, 0.72);
        [UIView animateWithDuration:0.28
                              delay:0.0
             usingSpringWithDamping:0.76
              initialSpringVelocity:0.16
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.statusImageView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

- (void)configureTypingWithMaxWidth:(CGFloat)maxWidth {
    self.messageModel = nil;
    self.typingMode = YES;
    self.assistantMessage = YES;
    CGFloat resolvedMaxWidth = [self pp_resolvedContainerWidthForCandidate:maxWidth];
    self.configuredMaxWidth = resolvedMaxWidth;
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.contentView.bounds = CGRectMake(0.0, 0.0, resolvedMaxWidth, CGRectGetHeight(self.contentView.bounds));

    self.messageLabel.hidden = YES;
    self.typingAnimationView.hidden = NO;
    self.typingSignalView.hidden = YES;
    self.timeLabel.text = kLang(@"nova_typing");
    self.statusImageView.hidden = YES;
    [self pp_applyStyleForAssistant:YES typing:YES];
    [self pp_applyAlignmentForAssistant:YES maxWidth:resolvedMaxWidth];
    [self pp_startTypingAnimation];
    [self.contentView setNeedsLayout];
    [self.contentView layoutIfNeeded];

    self.accessibilityLabel = kLang(@"nova_typing");
}

- (NSArray<NSString *> *)pp_actionTitlesFromMessage:(ChatMessageModel *)messageModel {
    if (!self.assistantMessage || ![messageModel.novaOptions isKindOfClass:NSArray.class]) {
        return nil;
    }
    NSMutableArray<NSString *> *titles = [NSMutableArray array];
    for (NSDictionary<NSString *, id> *option in messageModel.novaOptions) {
        if (![option isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSString *title = [option[@"title"] isKindOfClass:NSString.class] ? option[@"title"] : @"";
        title = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSString *subtitle = [option[@"subtitle"] isKindOfClass:NSString.class] ? option[@"subtitle"] : @"";
        subtitle = [subtitle stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (title.length > 0) {
            [titles addObject:subtitle.length > 0
                ? [NSString stringWithFormat:@"%@\n%@", title, subtitle]
                : title];
        }
    }
    return titles.count > 0 ? [titles copy] : nil;
}

- (void)setActionTitles:(nullable NSArray<NSString *> *)actionTitles {
    for (UIView *view in self.actionStack.arrangedSubviews) {
        [self.actionStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    if (actionTitles.count == 0) {
        self.actionStack.hidden = YES;
        if (self.configuredMaxWidth > 1.0) {
            [self pp_applyAlignmentForAssistant:self.assistantMessage maxWidth:self.configuredMaxWidth];
        }
        return;
    }

    self.actionStack.hidden = NO;
    [actionTitles enumerateObjectsUsingBlock:^(NSString *title, NSUInteger idx, __unused BOOL *stop) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = (NSInteger)idx;
        button.titleLabel.font = [GM boldFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
        button.titleLabel.numberOfLines = 2;
        button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        button.titleLabel.textAlignment = PPNovaAlignmentForText(title);
        button.semanticContentAttribute = PPNovaSemanticForText(title);
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
        button.contentEdgeInsets = UIEdgeInsetsMake(7.0, 11.0, 7.0, 11.0);
        button.layer.cornerRadius = 14.0;
        button.layer.masksToBounds = YES;
        if (@available(iOS 13.0, *)) {
            button.layer.cornerCurve = kCACornerCurveContinuous;
        }
        [button setTitle:title forState:UIControlStateNormal];
        [button addTarget:self action:@selector(pp_actionButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [button addTarget:self action:@selector(pp_pressDown:) forControlEvents:UIControlEventTouchDown];
        [button addTarget:self action:@selector(pp_pressUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
        [self.actionStack addArrangedSubview:button];
    }];
    [self pp_applyStyleForAssistant:self.assistantMessage typing:self.typingMode];
    if (self.configuredMaxWidth > 1.0) {
        [self pp_applyAlignmentForAssistant:self.assistantMessage maxWidth:self.configuredMaxWidth];
    }
}

- (void)pp_applyAlignmentForAssistant:(BOOL)assistant maxWidth:(CGFloat)maxWidth {
    CGFloat resolvedMaxWidth = [self pp_resolvedContainerWidthForCandidate:maxWidth];
    NSString *plainText = [self pp_currentPlainMessageText];
    self.messageLabel.semanticContentAttribute = PPNovaSemanticForText(plainText);
    self.messageLabel.textAlignment = PPNovaAlignmentForText(plainText);
    self.bubbleWidthConstraint.constant = [self pp_targetBubbleWidthForAssistant:assistant maxWidth:resolvedMaxWidth];
    self.messageLabel.preferredMaxLayoutWidth = MAX(self.bubbleWidthConstraint.constant - PPNovaBubbleHorizontalContentInset, 1.0);

    [NSLayoutConstraint deactivateConstraints:self.assistantConstraints];
    [NSLayoutConstraint deactivateConstraints:self.userConstraints];
    [NSLayoutConstraint activateConstraints:(assistant ? self.assistantConstraints : self.userConstraints)];

    self.avatarView.hidden = !assistant;
    self.metaStack.alignment = assistant ? UIStackViewAlignmentTrailing : UIStackViewAlignmentLeading;
    self.contentStack.alignment = UIStackViewAlignmentFill;
}

- (CGFloat)pp_resolvedContainerWidthForCandidate:(CGFloat)candidateWidth {
    CGFloat width = candidateWidth;
    if (width <= 1.0 && self.configuredMaxWidth > 1.0) {
        width = self.configuredMaxWidth;
    }
    if (width <= 1.0) {
        width = CGRectGetWidth(self.contentView.bounds);
    }
    if (width <= 1.0) {
        width = UIScreen.mainScreen.bounds.size.width;
    }
    return floor(MAX(width, 1.0));
}

- (CGFloat)pp_targetBubbleWidthForAssistant:(BOOL)assistant maxWidth:(CGFloat)maxWidth {
    CGFloat containerWidth = [self pp_resolvedContainerWidthForCandidate:maxWidth];
    CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width;
    // Screen width is always a safe lower bound for assistant bubbles — the table view
    // can never be wider than the screen. This prevents collapsed bubbles when the cell
    // is first configured before the table view has completed its initial layout pass.
    if (assistant && screenWidth > 1.0) {
        containerWidth = MAX(containerWidth, screenWidth);
    }

    CGFloat reserve = assistant ? PPNovaAssistantHorizontalReserve : PPNovaUserHorizontalReserve;
    CGFloat availableWidth = floor(containerWidth - reserve);
    if (availableWidth < PPNovaBubbleMinimumWidth) {
        availableWidth = MAX(PPNovaBubbleMinimumWidth, floor(containerWidth - 32.0));
    }

    CGFloat measuredWidth = [self pp_measuredBubbleWidthForAvailableWidth:availableWidth];
    CGFloat minimumWidth = PPNovaBubbleMinimumWidth;
    if (assistant && !self.typingMode) {
        CGFloat readableFloor = floor(containerWidth * PPNovaAssistantReadableWidthRatio);
        readableFloor = MIN(PPNovaAssistantMaximumReadableFloor, MAX(PPNovaAssistantMinimumReadableWidth, readableFloor));
        minimumWidth = MIN(availableWidth, MAX(PPNovaBubbleMinimumWidth, readableFloor));
    }

    CGFloat targetWidth = MIN(availableWidth, MAX(minimumWidth, measuredWidth));
    if (assistant && !self.typingMode) {
        CGFloat comfortableWidth = floor(containerWidth * 0.58);
        comfortableWidth = MIN(PPNovaAssistantMaximumReadableFloor, MAX(PPNovaAssistantMinimumReadableWidth, comfortableWidth));
        targetWidth = MAX(targetWidth, MIN(availableWidth, comfortableWidth));
    }
    if (self.typingMode) {
        targetWidth = MAX(targetWidth, 86.0);
    }

    return ceil(targetWidth);
}

- (CGFloat)pp_measuredBubbleWidthForAvailableWidth:(CGFloat)availableWidth {
    CGFloat maxLabelWidth = MAX(availableWidth - PPNovaBubbleHorizontalContentInset, 1.0);
    CGFloat targetContentWidth = 0.0;

    if (!self.messageLabel.hidden && (self.messageLabel.attributedText.length > 0 || self.messageLabel.text.length > 0)) {
        CGSize singleLineSize = [self.messageLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
        CGFloat singleLineWidth = ceil(singleLineSize.width);
        NSString *plainText = self.messageLabel.attributedText.string.length > 0
            ? self.messageLabel.attributedText.string
            : (self.messageLabel.text ?: @"");
        BOOL hasExplicitLineBreak = [plainText rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location != NSNotFound;

        if (singleLineWidth <= maxLabelWidth && !hasExplicitLineBreak) {
            targetContentWidth = MAX(targetContentWidth, [self pp_singleLineContentWidthForMeasuredWidth:singleLineWidth
                                                                                            maxLabelWidth:maxLabelWidth]);
        } else {
            targetContentWidth = MAX(targetContentWidth, [self pp_balancedWrappedContentWidthForMaxLabelWidth:maxLabelWidth]);
        }
    }

    if (!self.typingAnimationView.hidden) {
        targetContentWidth = MAX(targetContentWidth, PPNovaTypingAnimationWidth);
    }

    if (self.timeLabel.text.length > 0) {
        CGSize timeSize = [self.timeLabel sizeThatFits:CGSizeMake(maxLabelWidth, CGFLOAT_MAX)];
        targetContentWidth = MAX(targetContentWidth, ceil(timeSize.width));
    }

    if (!self.actionStack.hidden) {
        CGSize actionSize = [self.actionStack systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
        CGFloat optionsReadableWidth = MIN(maxLabelWidth, MAX(PPNovaAssistantOptionsMinimumWidth - PPNovaBubbleHorizontalContentInset,
                                                              floor(maxLabelWidth * PPNovaAssistantWrappedWidthFloorRatio)));
        targetContentWidth = MAX(targetContentWidth, MAX(ceil(actionSize.width), optionsReadableWidth));
    }

    return targetContentWidth + PPNovaBubbleHorizontalContentInset;
}

- (CGFloat)pp_singleLineContentWidthForMeasuredWidth:(CGFloat)measuredWidth
                                       maxLabelWidth:(CGFloat)maxLabelWidth {
    CGFloat readableWidth = MIN(maxLabelWidth, MAX(measuredWidth, PPNovaBubbleMinimumWidth - PPNovaBubbleHorizontalContentInset));
    if (self.assistantMessage && !self.typingMode) {
        CGFloat assistantFloor = MIN(maxLabelWidth, MAX(PPNovaAssistantMinimumReadableWidth - PPNovaBubbleHorizontalContentInset,
                                                        floor(maxLabelWidth * 0.68)));
        readableWidth = MAX(readableWidth, assistantFloor);
    }
    return ceil(readableWidth);
}

- (CGFloat)pp_balancedWrappedContentWidthForMaxLabelWidth:(CGFloat)maxLabelWidth {
    CGFloat minimumLabelWidth = MIN(maxLabelWidth, MAX(PPNovaAssistantMinimumReadableWidth - PPNovaBubbleHorizontalContentInset,
                                                       floor(maxLabelWidth * PPNovaAssistantWrappedWidthFloorRatio)));
    if (!self.assistantMessage || self.typingMode) {
        minimumLabelWidth = MIN(maxLabelWidth, MAX(PPNovaBubbleMinimumWidth - PPNovaBubbleHorizontalContentInset,
                                                   floor(maxLabelWidth * 0.64)));
    }

    CGSize widestSize = [self.messageLabel sizeThatFits:CGSizeMake(maxLabelWidth, CGFLOAT_MAX)];
    CGFloat widestHeight = ceil(widestSize.height);
    CGFloat lineHeight = ceil(self.messageLabel.font.lineHeight ?: 18.0);
    CGFloat toleratedHeight = widestHeight + MAX(6.0, lineHeight * 0.55);

    CGFloat candidate = minimumLabelWidth;
    while (candidate < maxLabelWidth) {
        CGSize candidateSize = [self.messageLabel sizeThatFits:CGSizeMake(candidate, CGFLOAT_MAX)];
        if (ceil(candidateSize.height) <= toleratedHeight) {
            return ceil(candidate);
        }
        candidate += PPNovaBubbleWidthSearchStep;
    }
    return ceil(maxLabelWidth);
}

- (CGSize)systemLayoutSizeFittingSize:(CGSize)targetSize
        withHorizontalFittingPriority:(UILayoutPriority)horizontalFittingPriority
              verticalFittingPriority:(UILayoutPriority)verticalFittingPriority {
    CGFloat fittingWidth = targetSize.width > 1.0 ? targetSize.width : self.configuredMaxWidth;
    if (self.configuredMaxWidth > 1.0 && fittingWidth < self.configuredMaxWidth) {
        fittingWidth = self.configuredMaxWidth;
    }
    fittingWidth = [self pp_resolvedContainerWidthForCandidate:fittingWidth];
    if (fittingWidth > 1.0) {
        self.contentView.bounds = CGRectMake(0.0, 0.0, fittingWidth, CGRectGetHeight(self.contentView.bounds));
        [self pp_applyAlignmentForAssistant:self.assistantMessage maxWidth:fittingWidth];
    }

    [self.contentView setNeedsLayout];
    [self.contentView layoutIfNeeded];

    CGSize size = [self.contentView systemLayoutSizeFittingSize:CGSizeMake(fittingWidth, UILayoutFittingCompressedSize.height)
                                  withHorizontalFittingPriority:UILayoutPriorityRequired
                                        verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    return CGSizeMake(fittingWidth, ceil(size.height));
}

- (void)pp_applyStyleForAssistant:(BOOL)assistant typing:(BOOL)typing {
    UIColor *brand = AppPrimaryClr ?: UIColor.systemOrangeColor;
    UIColor *assistantFill = PPNovaCellDynamicColor([UIColor colorWithWhite:1.0 alpha:0.97],
                                                   [UIColor colorWithWhite:1.0 alpha:0.14]);
    UIColor *assistantText = PPNovaCellDynamicColor(AppPrimaryTextClr ?: UIColor.blackColor,
                                                   UIColor.whiteColor);
    UIColor *assistantMeta = PPNovaCellDynamicColor([UIColor colorWithWhite:0.16 alpha:0.46],
                                                   [UIColor colorWithWhite:1.0 alpha:0.46]);
    UIColor *assistantBorder = PPNovaCellDynamicColor([brand colorWithAlphaComponent:0.16],
                                                     [UIColor.whiteColor colorWithAlphaComponent:0.12]);
    UIColor *userFill = PPNovaCellDynamicColor([brand colorWithAlphaComponent:0.86],
                                              [brand colorWithAlphaComponent:0.78]);
    UIColor *userText = UIColor.whiteColor;
    UIColor *userMeta = [UIColor.whiteColor colorWithAlphaComponent:0.72];
    UIColor *userBorder = PPNovaCellDynamicColor([UIColor.whiteColor colorWithAlphaComponent:0.34],
                                                [UIColor.whiteColor colorWithAlphaComponent:0.18]);

    UIVisualEffect *assistantEffect = nil;
    if (assistant) {
        UIBlurEffectStyle blurStyle = UIBlurEffectStyleRegular;
        if (@available(iOS 13.0, *)) {
            blurStyle = UIBlurEffectStyleSystemUltraThinMaterial;
        }
        assistantEffect = [UIBlurEffect effectWithStyle:blurStyle];
    }
    self.bubbleMaterialView.effect = assistantEffect;
    self.bubbleMaterialView.contentView.backgroundColor = assistant ? assistantFill : userFill;
    self.bubbleMaterialView.layer.cornerRadius = typing ? 21.0 : PPNovaBubbleCornerRadius;
    self.bubbleMaterialView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.bubbleMaterialView.layer.borderColor = (assistant ? assistantBorder : userBorder).CGColor;

    UIColor *shadowColor = assistant ? UIColor.blackColor : brand;
    UIColor *avatarShadowColor = brand;
    if (@available(iOS 13.0, *)) {
        shadowColor = [shadowColor resolvedColorWithTraitCollection:self.traitCollection];
        avatarShadowColor = [avatarShadowColor resolvedColorWithTraitCollection:self.traitCollection];
    }
    BOOL darkMode = NO;
    if (@available(iOS 13.0, *)) {
        darkMode = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    self.bubbleShadowView.layer.shadowColor = shadowColor.CGColor;
    self.bubbleShadowView.layer.shadowOpacity = assistant ? (darkMode ? 0.20 : 0.09) : (darkMode ? 0.22 : 0.15);
    self.bubbleShadowView.layer.shadowRadius = assistant ? 20.0 : 18.0;
    self.bubbleShadowView.layer.shadowOffset = CGSizeMake(0.0, assistant ? 9.0 : 10.0);

    self.avatarView.backgroundColor = PPNovaCellDynamicColor([brand colorWithAlphaComponent:0.11],
                                                            [brand colorWithAlphaComponent:0.18]);
    self.avatarView.layer.borderColor = PPNovaCellDynamicColor([brand colorWithAlphaComponent:0.18],
                                                              [UIColor.whiteColor colorWithAlphaComponent:0.10]).CGColor;
    self.avatarView.layer.shadowColor = avatarShadowColor.CGColor;
    self.avatarView.layer.shadowOpacity = darkMode ? 0.18 : 0.12;

    self.messageLabel.textColor = assistant ? assistantText : userText;

    if (!typing && self.messageModel.text.length > 0) {
        if (assistant) {
            BOOL containsMarkdown = NO;
            NSUInteger fallbackItemCount = 0;
            BOOL attributedSuccess = NO;
            NSUInteger resultCardCount = self.messageModel.novaProducts.count;
            NSAttributedString *renderedText =
                [self pp_attributedStringFromNovaText:self.messageModel.text
                                             baseFont:nil
                                            textColor:assistantText
                                       secondaryColor:assistantMeta
                                          accentColor:brand
                                     containsMarkdown:&containsMarkdown
                                    fallbackItemCount:&fallbackItemCount
                                              success:&attributedSuccess];
            self.messageLabel.text = nil;
            self.messageLabel.attributedText = renderedText;
            BOOL detectedRTL = PPNovaTextStartsRTL(renderedText.string ?: self.messageModel.text);
            NSLog(@"[PPNovaChat][AnswerRender] message_id=%@ contains_markdown=%@ detected_rtl=%@ result_card_count=%lu fallback_text_item_count=%lu attributed_success=%@",
                  self.messageModel.ID ?: @"",
                  containsMarkdown ? @"YES" : @"NO",
                  detectedRTL ? @"YES" : @"NO",
                  (unsigned long)resultCardCount,
                  (unsigned long)fallbackItemCount,
                  attributedSuccess ? @"YES" : @"NO");
        } else {
            self.messageLabel.attributedText = nil;
            self.messageLabel.text = self.messageModel.text ?: @"";
        }
    }
    
    self.timeLabel.textColor = assistant ? assistantMeta : userMeta;
    self.statusImageView.tintColor = userMeta;

    self.typingAnimationView.alpha = typing ? 1.0 : 0.0;
    self.typingSignalView.alpha = 0.0;
    self.typingSignalView.hidden = YES;
    [self pp_updateTypingAuraForBrand:brand darkMode:darkMode typing:typing];

    for (UIButton *button in self.actionStack.arrangedSubviews) {
        if (![button isKindOfClass:UIButton.class]) continue;
        button.backgroundColor = assistant ? [brand colorWithAlphaComponent:0.10] : [UIColor.whiteColor colorWithAlphaComponent:0.15];
        button.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        button.layer.borderColor = (assistant ? [brand colorWithAlphaComponent:0.14] : [UIColor.whiteColor colorWithAlphaComponent:0.22]).CGColor;
        [button setTitleColor:(assistant ? brand : UIColor.whiteColor) forState:UIControlStateNormal];
    }
}

- (void)pp_configureStatusForMessage:(ChatMessageModel *)messageModel {
    (void)messageModel;
    self.statusImageView.image = nil;
    self.statusImageView.hidden = YES;
}

- (NSString *)pp_formattedTime:(NSDate *)date {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterNoStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
    });
    formatter.locale = NSLocale.currentLocale;
    return [formatter stringFromDate:date ?: NSDate.date];
}

- (UIColor *)pp_typingBubbleFillColorForBrand:(UIColor *)brand
                                     darkMode:(BOOL)darkMode
                                  highlighted:(BOOL)highlighted {
    UIColor *resolvedBrand = brand ?: (AppPrimaryClr ?: UIColor.systemOrangeColor);
    if (@available(iOS 13.0, *)) {
        resolvedBrand = [resolvedBrand resolvedColorWithTraitCollection:self.traitCollection];
    }

    CGFloat lightAlpha = highlighted ? 0.145 : 0.085;
    CGFloat darkAlpha = highlighted ? 0.155 : 0.095;
    UIColor *sourceColor = darkMode ? UIColor.whiteColor : resolvedBrand;
    return [sourceColor colorWithAlphaComponent:(darkMode ? darkAlpha : lightAlpha)];
}

- (void)pp_updateTypingAuraForBrand:(UIColor *)brand darkMode:(BOOL)darkMode typing:(BOOL)typing {
    UIColor *resolvedBrand = brand ?: UIColor.systemOrangeColor;
    if (@available(iOS 13.0, *)) {
        resolvedBrand = [resolvedBrand resolvedColorWithTraitCollection:self.traitCollection];
    }

    [self.typingAuraGradientLayer removeAllAnimations];
    self.typingAuraView.hidden = YES;
    self.typingAuraView.alpha = 0.0;

    [self.typingSignalGradientLayer removeAllAnimations];
    self.typingSignalView.hidden = YES;
    self.typingSignalView.alpha = 0.0;
    self.typingSignalView.layer.shadowOpacity = 0.0;

    if (typing) {
        self.bubbleMaterialView.contentView.backgroundColor = [self pp_typingBubbleFillColorForBrand:resolvedBrand
                                                                                             darkMode:darkMode
                                                                                          highlighted:NO];
    }

    for (UIView *dotView in self.typingDotViews) {
        dotView.alpha = 0.0;
        dotView.transform = CGAffineTransformIdentity;
        [dotView.layer removeAllAnimations];
    }
}

- (void)pp_startTypingAnimation {
    [self pp_loadTypingAnimationIfNeeded];
    self.typingSignalView.hidden = YES;
    self.typingSignalView.alpha = 0.0;
    self.typingAnimationView.hidden = NO;
    self.typingAnimationView.alpha = 1.0;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self.typingAnimationView stop];
        self.typingAnimationView.animationProgress = 0.35;
        [self pp_applyReducedTypingLiveMotion];
        return;
    }

    [self.typingAnimationView play];
    [self pp_startTypingLiveMotion];
}

- (void)pp_stopTypingAnimation {
    [self.typingAnimationView stop];
    self.typingAnimationView.animationProgress = 0.0;
    [self pp_stopTypingLiveMotion];
}

- (void)pp_startTypingLiveMotion {
    if (!self.typingMode || self.typingLiveMotionActive || !self.window) {
        return;
    }

    self.typingLiveMotionActive = YES;
    self.typingAuraView.hidden = YES;
    self.typingAuraView.alpha = 0.0;
    self.typingSignalView.hidden = YES;
    self.typingSignalView.alpha = 0.0;

    BOOL darkMode = NO;
    if (@available(iOS 13.0, *)) {
        darkMode = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    // 3 premium colors the bubble cycles through while Nova is thinking
    UIColor *color0 = darkMode
        ? [UIColor colorWithRed:0.36 green:0.20 blue:0.72 alpha:0.18]   // deep violet
        : [UIColor colorWithRed:0.36 green:0.20 blue:0.72 alpha:0.10];
    UIColor *color1 = darkMode
        ? [UIColor colorWithRed:0.10 green:0.52 blue:0.90 alpha:0.18]   // electric blue
        : [UIColor colorWithRed:0.10 green:0.52 blue:0.90 alpha:0.10];
    UIColor *color2 = darkMode
        ? [UIColor colorWithRed:0.18 green:0.72 blue:0.62 alpha:0.18]   // teal
        : [UIColor colorWithRed:0.18 green:0.72 blue:0.62 alpha:0.10];

    self.bubbleMaterialView.contentView.backgroundColor = color0;

    // Color shift: cycle through the 3 premium colors
    CAKeyframeAnimation *colorShift = [CAKeyframeAnimation animationWithKeyPath:@"backgroundColor"];
    colorShift.values = @[
        (__bridge id)color0.CGColor,
        (__bridge id)color1.CGColor,
        (__bridge id)color2.CGColor,
        (__bridge id)color0.CGColor,
    ];
    colorShift.keyTimes = @[@0.0, @0.33, @0.66, @1.0];
    colorShift.duration = 4.8;
    colorShift.repeatCount = HUGE_VALF;
    colorShift.timingFunctions = @[
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
    ];
    colorShift.removedOnCompletion = NO;
    [self.bubbleMaterialView.contentView.layer addAnimation:colorShift
                                                     forKey:PPNovaTypingBubbleColorShiftAnimationKey];

    // Alpha breath: gentle pulse on top of the color shift
    CABasicAnimation *alphaBreath = [CABasicAnimation animationWithKeyPath:@"opacity"];
    alphaBreath.fromValue = @0.72;
    alphaBreath.toValue = @1.0;
    alphaBreath.duration = 1.6;
    alphaBreath.autoreverses = YES;
    alphaBreath.repeatCount = HUGE_VALF;
    alphaBreath.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    alphaBreath.removedOnCompletion = NO;
    [self.bubbleMaterialView.contentView.layer addAnimation:alphaBreath
                                                     forKey:PPNovaTypingBubbleAlphaAnimationKey];
}

- (void)pp_applyReducedTypingLiveMotion {
    self.typingLiveMotionActive = NO;
    self.typingAuraView.hidden = YES;
    self.typingAuraView.alpha = 0.0;
    self.typingSignalView.hidden = YES;
    self.typingSignalView.alpha = 0.0;
    [self.bubbleMaterialView.contentView.layer removeAnimationForKey:PPNovaTypingBubbleFillBreathAnimationKey];
    [self.bubbleMaterialView.contentView.layer removeAnimationForKey:PPNovaTypingBubbleColorShiftAnimationKey];
    [self.bubbleMaterialView.contentView.layer removeAnimationForKey:PPNovaTypingBubbleAlphaAnimationKey];
    for (UIView *dotView in self.typingDotViews) {
        [dotView.layer removeAllAnimations];
        dotView.layer.transform = CATransform3DIdentity;
        dotView.alpha = 0.0;
    }
}

- (void)pp_stopTypingLiveMotion {
    self.typingLiveMotionActive = NO;
    [self.typingAuraGradientLayer removeAllAnimations];
    [self.typingSignalGradientLayer removeAllAnimations];
    [self.bubbleMaterialView.contentView.layer removeAnimationForKey:PPNovaTypingBubbleFillBreathAnimationKey];
    [self.bubbleMaterialView.contentView.layer removeAnimationForKey:PPNovaTypingBubbleColorShiftAnimationKey];
    [self.bubbleMaterialView.contentView.layer removeAnimationForKey:PPNovaTypingBubbleAlphaAnimationKey];
    self.typingAuraView.alpha = 0.0;
    self.typingAuraView.hidden = YES;
    self.typingSignalView.alpha = 0.0;
    self.typingSignalView.hidden = YES;
    for (UIView *dotView in self.typingDotViews) {
        [dotView.layer removeAllAnimations];
        dotView.layer.transform = CATransform3DIdentity;
        dotView.alpha = 0.0;
    }
}

- (void)pp_loadTypingAnimationIfNeeded {
    if (self.typingAnimationLoaded || !self.typingAnimationView) {
        return;
    }
    self.typingAnimationLoaded = YES;

    NSString *path = [[NSBundle mainBundle] pathForResource:PPNovaTypingAnimationResourceName ofType:@"json"];
    NSData *data = path.length > 0 ? [NSData dataWithContentsOfFile:path] : nil;
    if (data.length == 0) {
        return;
    }

    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
    LOTComposition *composition = [json isKindOfClass:NSDictionary.class] ? [LOTComposition animationFromJSON:json] : nil;
    if (!composition) {
        return;
    }

    self.typingAnimationView.loopAnimation = YES;
    self.typingAnimationView.animationSpeed = 0.72;
    [self.typingAnimationView setSceneModel:composition];
}

- (void)pp_actionButtonTapped:(UIButton *)sender {
    if ([self.delegate respondsToSelector:@selector(novaMessageCell:didTapActionAtIndex:title:messageModel:)]) {
        [self.delegate novaMessageCell:self
                   didTapActionAtIndex:sender.tag
                                  title:[sender titleForState:UIControlStateNormal] ?: @""
                           messageModel:self.messageModel];
    }
}

- (void)pp_pressDown:(UIView *)view {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    [UIView animateWithDuration:0.10 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        view.transform = CGAffineTransformMakeScale(0.965, 0.965);
    } completion:nil];
}

- (void)pp_pressUp:(UIView *)view {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    [UIView animateWithDuration:0.20 delay:0.0 usingSpringWithDamping:0.88 initialSpringVelocity:0.2 options:UIViewAnimationOptionCurveEaseOut animations:^{
        view.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self pp_applyStyleForAssistant:self.assistantMessage typing:self.typingMode];
}

@end
