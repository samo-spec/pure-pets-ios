//
//  PPNovaMessageBubbleCell.m
//  Pure Pets
//

#import "PPNovaMessageBubbleCell.h"

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

static const CGFloat PPNovaBubbleMinimumWidth = 90.0;
static const CGFloat PPNovaAssistantMinimumReadableWidth = 184.0;
static const CGFloat PPNovaAssistantMaximumReadableFloor = 260.0;
static const CGFloat PPNovaAssistantReadableWidthRatio = 0.52;
static const CGFloat PPNovaAssistantHorizontalReserve = 120.0;
static const CGFloat PPNovaUserHorizontalReserve = 86.0;
static const CGFloat PPNovaBubbleHorizontalContentInset = 30.0;
static const CGFloat PPNovaBubbleCornerRadius = 24.0;
static const NSUInteger PPNovaMaximumFallbackTextItems = 5;

@interface PPNovaMessageBubbleCell ()

@property (nonatomic, strong) UIView *avatarView;
@property (nonatomic, strong) UILabel *avatarLabel;
@property (nonatomic, strong) UIView *bubbleShadowView;
@property (nonatomic, strong) UIVisualEffectView *bubbleMaterialView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIStackView *metaStack;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UIImageView *statusImageView;
@property (nonatomic, strong) UIStackView *typingDotsStack;
@property (nonatomic, copy) NSArray<UIView *> *typingDots;
@property (nonatomic, strong) UIStackView *actionStack;

@property (nonatomic, strong) NSLayoutConstraint *bubbleWidthConstraint;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *assistantConstraints;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *userConstraints;
@property (nonatomic, assign) CGFloat configuredMaxWidth;

@property (nonatomic, strong, nullable) ChatMessageModel *messageModel;
@property (nonatomic, assign) BOOL assistantMessage;
@property (nonatomic, assign) BOOL typingMode;

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
    self.configuredMaxWidth = 0.0;
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.messageLabel.hidden = NO;
    self.typingDotsStack.hidden = YES;
    [self setActionTitles:nil];
    [self pp_stopTypingAnimation];
    self.alpha = 1.0;
    self.transform = CGAffineTransformIdentity;
    self.contentView.transform = CGAffineTransformIdentity;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.bubbleShadowView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bubbleShadowView.bounds
                                                                        cornerRadius:self.bubbleMaterialView.layer.cornerRadius].CGPath;
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
    [self.messageLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.messageLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.contentStack addArrangedSubview:self.messageLabel];

    self.typingDotsStack = [[UIStackView alloc] init];
    self.typingDotsStack.axis = UILayoutConstraintAxisHorizontal;
    self.typingDotsStack.alignment = UIStackViewAlignmentCenter;
    self.typingDotsStack.spacing = 5.0;
    self.typingDotsStack.hidden = YES;
    [self.contentStack addArrangedSubview:self.typingDotsStack];

    NSMutableArray<UIView *> *dots = [NSMutableArray arrayWithCapacity:3];
    for (NSInteger i = 0; i < 3; i++) {
        UIView *dot = [[UIView alloc] init];
        dot.translatesAutoresizingMaskIntoConstraints = NO;
        dot.backgroundColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
        dot.layer.cornerRadius = 3.5;
        [self.typingDotsStack addArrangedSubview:dot];
        [NSLayoutConstraint activateConstraints:@[
            [dot.widthAnchor constraintEqualToConstant:7.0],
            [dot.heightAnchor constraintEqualToConstant:7.0]
        ]];
        [dots addObject:dot];
    }
    self.typingDots = [dots copy];

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
    self.bubbleWidthConstraint.active = YES;

    NSLayoutConstraint *avatarEdge = [self.avatarView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0];
    NSLayoutConstraint *assistantPrimary = [self.bubbleShadowView.trailingAnchor constraintEqualToAnchor:self.avatarView.leadingAnchor constant:-8.0];
    NSLayoutConstraint *assistantLimit = [self.bubbleShadowView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.contentView.leadingAnchor constant:70.0];
    NSLayoutConstraint *userPrimary = [self.bubbleShadowView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0];
    NSLayoutConstraint *userLimit = [self.bubbleShadowView.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-70.0];

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

        [self.contentStack.topAnchor constraintEqualToAnchor:self.bubbleMaterialView.contentView.topAnchor constant:20.0],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.bubbleMaterialView.contentView.leadingAnchor constant:15.0],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.bubbleMaterialView.contentView.trailingAnchor constant:-15.0],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.bubbleMaterialView.contentView.bottomAnchor constant:-18.0]
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
    self.typingDotsStack.hidden = YES;
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

- (void)configureTypingWithMaxWidth:(CGFloat)maxWidth {
    self.messageModel = nil;
    self.typingMode = YES;
    self.assistantMessage = YES;
    CGFloat resolvedMaxWidth = [self pp_resolvedContainerWidthForCandidate:maxWidth];
    self.configuredMaxWidth = resolvedMaxWidth;
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.contentView.bounds = CGRectMake(0.0, 0.0, resolvedMaxWidth, CGRectGetHeight(self.contentView.bounds));

    self.messageLabel.hidden = YES;
    self.typingDotsStack.hidden = NO;
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
    for (NSDictionary<NSString *, NSString *> *option in messageModel.novaOptions) {
        if (![option isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSString *title = [option[@"title"] isKindOfClass:NSString.class] ? option[@"title"] : @"";
        title = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (title.length > 0) {
            [titles addObject:title];
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
    if (self.typingMode) {
        targetWidth = MAX(targetWidth, 86.0);
    }

    return ceil(targetWidth);
}

- (CGFloat)pp_measuredBubbleWidthForAvailableWidth:(CGFloat)availableWidth {
    CGFloat maxLabelWidth = MAX(availableWidth - PPNovaBubbleHorizontalContentInset, 1.0);
    CGFloat targetContentWidth = 0.0;

    if (!self.messageLabel.hidden && (self.messageLabel.attributedText.length > 0 || self.messageLabel.text.length > 0)) {
        // Use the label's own sizing logic to get accurate layout width
        CGSize labelSize = [self.messageLabel sizeThatFits:CGSizeMake(maxLabelWidth, CGFLOAT_MAX)];
        targetContentWidth = ceil(labelSize.width);
        
        // Calculate unconstrained width to check if it fits on a single line
        CGSize singleLineSize = [self.messageLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
        CGFloat singleLineWidth = ceil(singleLineSize.width);
        
        NSString *plainText = self.messageLabel.attributedText.string.length > 0
            ? self.messageLabel.attributedText.string
            : (self.messageLabel.text ?: @"");
        BOOL hasExplicitLineBreak = [plainText rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location != NSNotFound;

        if (singleLineWidth <= maxLabelWidth && !hasExplicitLineBreak) {
            targetContentWidth = MAX(targetContentWidth, singleLineWidth);
        } else {
            // If it exceeds max width or has manual line breaks, it will wrap.
            // Labels sometimes report a small width if the longest wrapped line is short.
            // To prevent "tall and skinny" single-word column bubbles, we enforce full available width.
            targetContentWidth = MAX(targetContentWidth, maxLabelWidth);
        }
    }

    if (!self.typingDotsStack.hidden) {
        targetContentWidth = MAX(targetContentWidth, 42.0);
    }

    if (self.timeLabel.text.length > 0) {
        CGSize timeSize = [self.timeLabel sizeThatFits:CGSizeMake(maxLabelWidth, CGFLOAT_MAX)];
        targetContentWidth = MAX(targetContentWidth, ceil(timeSize.width));
    }

    if (!self.actionStack.hidden) {
        CGSize actionSize = [self.actionStack systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
        targetContentWidth = MAX(targetContentWidth, ceil(actionSize.width));
    }

    return targetContentWidth + PPNovaBubbleHorizontalContentInset;
}

- (CGSize)systemLayoutSizeFittingSize:(CGSize)targetSize
        withHorizontalFittingPriority:(UILayoutPriority)horizontalFittingPriority
              verticalFittingPriority:(UILayoutPriority)verticalFittingPriority {
    CGFloat configuredWidth = [self pp_resolvedContainerWidthForCandidate:self.configuredMaxWidth];
    CGFloat fittingWidth = targetSize.width > 1.0 ? targetSize.width : configuredWidth;
    if (configuredWidth > 1.0 && fittingWidth < configuredWidth) {
        fittingWidth = configuredWidth;
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
    UIColor *assistantFill = PPNovaCellDynamicColor([UIColor colorWithWhite:1.0 alpha:0.93],
                                                   [UIColor colorWithWhite:1.0 alpha:0.105]);
    UIColor *assistantText = PPNovaCellDynamicColor(AppPrimaryTextClr ?: UIColor.blackColor,
                                                   UIColor.whiteColor);
    UIColor *assistantMeta = PPNovaCellDynamicColor([UIColor colorWithWhite:0.16 alpha:0.46],
                                                   [UIColor colorWithWhite:1.0 alpha:0.46]);
    UIColor *assistantBorder = PPNovaCellDynamicColor([brand colorWithAlphaComponent:0.13],
                                                     [UIColor.whiteColor colorWithAlphaComponent:0.09]);
    UIColor *userFill = PPNovaCellDynamicColor([brand colorWithAlphaComponent:0.90],
                                              [brand colorWithAlphaComponent:0.76]);
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
    self.bubbleShadowView.layer.shadowOpacity = assistant ? (darkMode ? 0.18 : 0.075) : (darkMode ? 0.20 : 0.13);
    self.bubbleShadowView.layer.shadowRadius = assistant ? 18.0 : 17.0;
    self.bubbleShadowView.layer.shadowOffset = CGSizeMake(0.0, assistant ? 8.0 : 9.0);

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

    for (UIView *dot in self.typingDots) {
        dot.backgroundColor = [brand colorWithAlphaComponent:typing ? 0.96 : 0.76];
        dot.layer.shadowColor = brand.CGColor;
        dot.layer.shadowOpacity = typing ? 0.16 : 0.0;
        dot.layer.shadowRadius = 3.0;
        dot.layer.shadowOffset = CGSizeZero;
    }

    for (UIButton *button in self.actionStack.arrangedSubviews) {
        if (![button isKindOfClass:UIButton.class]) continue;
        button.backgroundColor = assistant ? [brand colorWithAlphaComponent:0.10] : [UIColor.whiteColor colorWithAlphaComponent:0.15];
        button.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        button.layer.borderColor = (assistant ? [brand colorWithAlphaComponent:0.14] : [UIColor.whiteColor colorWithAlphaComponent:0.22]).CGColor;
        [button setTitleColor:(assistant ? brand : UIColor.whiteColor) forState:UIControlStateNormal];
    }
}

- (void)pp_configureStatusForMessage:(ChatMessageModel *)messageModel {
    if (self.assistantMessage) {
        self.statusImageView.hidden = YES;
        return;
    }

    UIImage *icon = nil;
    switch (messageModel.status) {
        case ChatMessageStatusSending:
            icon = [UIImage systemImageNamed:@"clock"];
            break;
        case ChatMessageStatusSent:
            icon = [UIImage systemImageNamed:@"checkmark"];
            break;
        case ChatMessageStatusDelivered:
        case ChatMessageStatusRead:
            icon = [UIImage systemImageNamed:@"checkmark.circle.fill"];
            break;
        default:
            icon = nil;
            break;
    }
    self.statusImageView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.statusImageView.hidden = (icon == nil);
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

- (void)pp_startTypingAnimation {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        for (UIView *dot in self.typingDots) {
            dot.layer.opacity = 1.0;
            [dot.layer removeAllAnimations];
        }
        return;
    }

    CFTimeInterval baseTime = CACurrentMediaTime();
    [self.typingDots enumerateObjectsUsingBlock:^(UIView *dot, NSUInteger idx, __unused BOOL *stop) {
        [dot.layer removeAllAnimations];
        CAKeyframeAnimation *floatAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.y"];
        floatAnimation.values = @[@0.0, @(-3.5), @0.0];
        floatAnimation.keyTimes = @[@0.0, @0.45, @1.0];
        floatAnimation.duration = 0.92;
        floatAnimation.repeatCount = HUGE_VALF;
        floatAnimation.beginTime = baseTime + (idx * 0.13);
        floatAnimation.timingFunctions = @[
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]
        ];
        [dot.layer addAnimation:floatAnimation forKey:@"pp_novaTypingFloat"];

        CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
        fade.fromValue = @0.45;
        fade.toValue = @1.0;
        fade.duration = 0.92;
        fade.autoreverses = YES;
        fade.repeatCount = HUGE_VALF;
        fade.beginTime = baseTime + (idx * 0.13);
        fade.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [dot.layer addAnimation:fade forKey:@"pp_novaTypingFade"];
    }];
}

- (void)pp_stopTypingAnimation {
    for (UIView *dot in self.typingDots) {
        [dot.layer removeAllAnimations];
        dot.layer.opacity = 1.0;
    }
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
