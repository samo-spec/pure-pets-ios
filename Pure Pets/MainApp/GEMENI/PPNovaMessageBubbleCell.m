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
@property (nonatomic, assign) CGFloat lastAppliedMaxWidth;
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
    self.timeLabel.text = nil;
    self.statusImageView.image = nil;
    self.statusImageView.hidden = YES;
    self.configuredMaxWidth = 0.0;
    self.lastAppliedMaxWidth = 0.0;
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

    CGFloat contentWidth = CGRectGetWidth(self.contentView.bounds);
    if (contentWidth > 1.0 && fabs(contentWidth - self.lastAppliedMaxWidth) > 1.0) {
        [self pp_applyAlignmentForAssistant:self.assistantMessage maxWidth:contentWidth];
    }
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
    self.avatarView.layer.masksToBounds = YES;
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
    self.bubbleShadowView.layer.shadowOpacity = 0.06;
    self.bubbleShadowView.layer.shadowRadius = 18.0;
    self.bubbleShadowView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    [self.contentView addSubview:self.bubbleShadowView];

    UIBlurEffectStyle blurStyle = UIBlurEffectStyleRegular;
    if (@available(iOS 13.0, *)) {
        blurStyle = UIBlurEffectStyleSystemUltraThinMaterial;
    }
    self.bubbleMaterialView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:blurStyle]];
    self.bubbleMaterialView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bubbleMaterialView.layer.cornerRadius = 23.0;
    self.bubbleMaterialView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.bubbleMaterialView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:self.bubbleMaterialView];

    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.alignment = UIStackViewAlignmentFill;
    self.contentStack.spacing = 7.0;
    [self.bubbleMaterialView.contentView addSubview:self.contentStack];

    self.messageLabel = [[UILabel alloc] init];
    self.messageLabel.numberOfLines = 0;
    self.messageLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.messageLabel.textAlignment = NSTextAlignmentNatural;
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
    self.actionStack.axis = UILayoutConstraintAxisHorizontal;
    self.actionStack.alignment = UIStackViewAlignmentLeading;
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

    [self.contentStack setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.contentStack setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    self.bubbleWidthConstraint = [self.bubbleShadowView.widthAnchor constraintEqualToConstant:280.0];
    self.bubbleWidthConstraint.priority = UILayoutPriorityRequired;
    self.bubbleWidthConstraint.active = YES;

    NSLayoutConstraint *avatarEdge = [self.avatarView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0];
    NSLayoutConstraint *assistantPrimary = [self.bubbleShadowView.leadingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor constant:8.0];
    NSLayoutConstraint *assistantLimit = [self.bubbleShadowView.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-70.0];
    NSLayoutConstraint *userPrimary = [self.bubbleShadowView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0];
    NSLayoutConstraint *userLimit = [self.bubbleShadowView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.contentView.leadingAnchor constant:70.0];

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

        [self.contentStack.topAnchor constraintEqualToAnchor:self.bubbleMaterialView.contentView.topAnchor constant:12.0],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.bubbleMaterialView.contentView.leadingAnchor constant:15.0],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.bubbleMaterialView.contentView.trailingAnchor constant:-15.0],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.bubbleMaterialView.contentView.bottomAnchor constant:-9.0]
    ]];

    [self pp_applyStyleForAssistant:YES typing:NO];
}

- (NSAttributedString *)pp_attributedStringFromMarkdown:(NSString *)text font:(UIFont *)font textColor:(UIColor *)textColor {
    if (text.length == 0) return [[NSAttributedString alloc] initWithString:@"" attributes:@{}];
    
    UIFontDescriptor *fontDescriptor = [font.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
    UIFont *boldFont = [UIFont fontWithDescriptor:fontDescriptor size:font.pointSize];
    if (!boldFont) {
        boldFont = [UIFont boldSystemFontOfSize:font.pointSize];
    }
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    paragraphStyle.alignment = PPNovaAlignmentForText(text);
    
    NSDictionary *defaultAttributes = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: textColor,
        NSParagraphStyleAttributeName: paragraphStyle
    };
    
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:text attributes:defaultAttributes];
    
    // Parse **bold**
    NSRegularExpression *boldRegex = [NSRegularExpression regularExpressionWithPattern:@"\\*\\*(.*?)\\*\\*" options:0 error:nil];
    NSArray<NSTextCheckingResult *> *matches = [boldRegex matchesInString:attributedString.string options:0 range:NSMakeRange(0, attributedString.length)];
    
    for (NSTextCheckingResult *match in [matches reverseObjectEnumerator]) {
        NSRange matchRange = match.range;
        NSRange contentRange = [match rangeAtIndex:1];
        NSString *content = [attributedString.string substringWithRange:contentRange];
        
        NSMutableAttributedString *boldString = [[NSMutableAttributedString alloc] initWithString:content attributes:defaultAttributes];
        [boldString addAttribute:NSFontAttributeName value:boldFont range:NSMakeRange(0, boldString.length)];
        
        [attributedString replaceCharactersInRange:matchRange withAttributedString:boldString];
    }
    
    // Parse *bold* (Single asterisks for italics or bold, treated as bold here for simplicity)
    NSRegularExpression *singleRegex = [NSRegularExpression regularExpressionWithPattern:@"(?<!\\*)\\*(?!\\*)(.*?)(?<!\\*)\\*(?!\\*)" options:0 error:nil];
    NSArray<NSTextCheckingResult *> *singleMatches = [singleRegex matchesInString:attributedString.string options:0 range:NSMakeRange(0, attributedString.length)];
    
    for (NSTextCheckingResult *match in [singleMatches reverseObjectEnumerator]) {
        NSRange matchRange = match.range;
        NSRange contentRange = [match rangeAtIndex:1];
        NSString *content = [attributedString.string substringWithRange:contentRange];
        
        NSMutableAttributedString *boldString = [[NSMutableAttributedString alloc] initWithString:content attributes:defaultAttributes];
        [boldString addAttribute:NSFontAttributeName value:boldFont range:NSMakeRange(0, boldString.length)];
        
        [attributedString replaceCharactersInRange:matchRange withAttributedString:boldString];
    }
    
    return attributedString;
}

- (void)configureWithMessage:(ChatMessageModel *)messageModel maxWidth:(CGFloat)maxWidth {
    self.messageModel = messageModel;
    self.typingMode = NO;
    self.assistantMessage = [messageModel.senderID isEqualToString:@"nova_bot_id"] || [messageModel.senderID isEqualToString:@"nova"];
    self.configuredMaxWidth = maxWidth;
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    self.messageLabel.hidden = NO;
    self.typingDotsStack.hidden = YES;
    self.messageLabel.text = messageModel.text ?: @"";
    self.messageLabel.semanticContentAttribute = PPNovaSemanticForText(self.messageLabel.text);
    self.messageLabel.textAlignment = PPNovaAlignmentForText(self.messageLabel.text);
    [self pp_applyStyleForAssistant:self.assistantMessage typing:NO];
    self.timeLabel.text = [self pp_formattedTime:messageModel.timestamp];
    [self pp_stopTypingAnimation];
    [self pp_configureStatusForMessage:messageModel];
    [self pp_applyAlignmentForAssistant:self.assistantMessage maxWidth:maxWidth];
    [self.contentView setNeedsLayout];
    [self.contentView layoutIfNeeded];

    self.accessibilityLabel = self.messageLabel.text;
}

- (void)configureTypingWithMaxWidth:(CGFloat)maxWidth {
    self.messageModel = nil;
    self.typingMode = YES;
    self.assistantMessage = YES;
    self.configuredMaxWidth = maxWidth;
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    self.messageLabel.hidden = YES;
    self.typingDotsStack.hidden = NO;
    self.timeLabel.text = kLang(@"nova_typing");
    self.statusImageView.hidden = YES;
    [self pp_applyStyleForAssistant:YES typing:YES];
    [self pp_applyAlignmentForAssistant:YES maxWidth:maxWidth];
    [self pp_startTypingAnimation];
    [self.contentView setNeedsLayout];
    [self.contentView layoutIfNeeded];

    self.accessibilityLabel = kLang(@"nova_typing");
}

- (void)setActionTitles:(nullable NSArray<NSString *> *)actionTitles {
    for (UIView *view in self.actionStack.arrangedSubviews) {
        [self.actionStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    if (actionTitles.count == 0) {
        self.actionStack.hidden = YES;
        return;
    }

    self.actionStack.hidden = NO;
    [actionTitles enumerateObjectsUsingBlock:^(NSString *title, NSUInteger idx, __unused BOOL *stop) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = (NSInteger)idx;
        button.titleLabel.font = [GM boldFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
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
}

- (void)pp_applyAlignmentForAssistant:(BOOL)assistant maxWidth:(CGFloat)maxWidth {
    CGFloat availableWidth = maxWidth > 1.0 ? maxWidth : self.configuredMaxWidth;
    if (availableWidth <= 1.0) {
        availableWidth = CGRectGetWidth(self.contentView.bounds);
    }
    if (availableWidth <= 1.0) {
        availableWidth = UIScreen.mainScreen.bounds.size.width;
    }
    availableWidth = MAX(availableWidth, 280.0);
    self.lastAppliedMaxWidth = availableWidth;

    CGFloat maxFittingWidth = assistant ? MAX(availableWidth - 120.0, 148.0) : MAX(availableWidth - 86.0, 150.0);
    CGFloat assistantMinimumWidth = MIN(MAX(availableWidth - 152.0, 218.0), maxFittingWidth);
    CGFloat targetWidth = 0.0;

    if (assistant) {
        targetWidth = self.typingMode ? 168.0 : maxFittingWidth;
        targetWidth = MIN(MAX(targetWidth, self.typingMode ? 148.0 : assistantMinimumWidth), 560.0);
    } else {
        NSString *text = self.messageLabel.text ?: @"";
        CGFloat measuredWidth = 0.0;
        if (text.length > 0 && self.messageLabel.attributedText) {
            CGRect rect = [self.messageLabel.attributedText boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)
                                                                         options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                                                         context:nil];
            measuredWidth = ceil(rect.size.width) + 42.0;
        }
        targetWidth = MIN(MAX(measuredWidth, 96.0), MIN(maxFittingWidth, 500.0));
    }

    targetWidth = floor(MIN(targetWidth, maxFittingWidth));
    self.bubbleWidthConstraint.constant = MAX(targetWidth, assistant ? (self.typingMode ? 148.0 : assistantMinimumWidth) : 86.0);
    self.messageLabel.preferredMaxLayoutWidth = MAX(self.bubbleWidthConstraint.constant - 30.0, 86.0);
    self.messageLabel.semanticContentAttribute = PPNovaSemanticForText(self.messageLabel.text ?: @"");
    self.messageLabel.textAlignment = PPNovaAlignmentForText(self.messageLabel.text ?: @"");

    [NSLayoutConstraint deactivateConstraints:self.assistantConstraints];
    [NSLayoutConstraint deactivateConstraints:self.userConstraints];
    [NSLayoutConstraint activateConstraints:(assistant ? self.assistantConstraints : self.userConstraints)];

    self.avatarView.hidden = !assistant;
    self.metaStack.alignment = assistant ? UIStackViewAlignmentLeading : UIStackViewAlignmentTrailing;
    self.contentStack.alignment = UIStackViewAlignmentFill;
}

- (CGSize)systemLayoutSizeFittingSize:(CGSize)targetSize
         withHorizontalFittingPriority:(UILayoutPriority)horizontalFittingPriority
               verticalFittingPriority:(UILayoutPriority)verticalFittingPriority {
    CGFloat width = targetSize.width > 1.0 ? targetSize.width : self.configuredMaxWidth;
    [self pp_applyAlignmentForAssistant:self.assistantMessage maxWidth:width];
    self.contentView.bounds = CGRectMake(0.0, 0.0, width, CGFLOAT_MAX);
    [self.contentView setNeedsLayout];
    [self.contentView layoutIfNeeded];

    CGSize fittingSize = CGSizeMake(width, UILayoutFittingCompressedSize.height);
    CGSize measuredSize = [self.contentView systemLayoutSizeFittingSize:fittingSize
                                           withHorizontalFittingPriority:UILayoutPriorityRequired
                                                 verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    return CGSizeMake(width, ceil(measuredSize.height));
}

- (void)pp_applyStyleForAssistant:(BOOL)assistant typing:(BOOL)typing {
    UIColor *brand = AppPrimaryClr ?: UIColor.systemOrangeColor;
    UIColor *assistantFill = PPNovaCellDynamicColor([UIColor colorWithWhite:1.0 alpha:0.86],
                                                   [UIColor colorWithWhite:1.0 alpha:0.075]);
    UIColor *assistantText = PPNovaCellDynamicColor(AppPrimaryTextClr ?: UIColor.blackColor,
                                                   UIColor.whiteColor);
    UIColor *assistantMeta = PPNovaCellDynamicColor([UIColor colorWithWhite:0.16 alpha:0.52],
                                                   [UIColor colorWithWhite:1.0 alpha:0.50]);
    UIColor *userFill = PPNovaCellDynamicColor([brand colorWithAlphaComponent:0.92],
                                              [brand colorWithAlphaComponent:0.82]);
    UIColor *userText = UIColor.whiteColor;
    UIColor *userMeta = [UIColor.whiteColor colorWithAlphaComponent:0.72];

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
    self.bubbleMaterialView.layer.borderWidth = assistant ? (0.5 / UIScreen.mainScreen.scale) : 0.0;
    self.bubbleMaterialView.layer.borderColor = assistant ? [UIColor.separatorColor colorWithAlphaComponent:0.22].CGColor : UIColor.clearColor.CGColor;
    self.bubbleShadowView.layer.shadowOpacity = assistant ? 0.055 : 0.085;
    self.bubbleShadowView.layer.shadowRadius = assistant ? 16.0 : 14.0;

    self.messageLabel.textColor = assistant ? assistantText : userText;
    
    if (self.messageModel.text) {
        self.messageLabel.attributedText = [self pp_attributedStringFromMarkdown:self.messageModel.text 
                                                                             font:self.messageLabel.font 
                                                                        textColor:self.messageLabel.textColor];
    }
    
    self.timeLabel.textColor = assistant ? assistantMeta : userMeta;
    self.statusImageView.tintColor = userMeta;

    for (UIView *dot in self.typingDots) {
        dot.backgroundColor = [brand colorWithAlphaComponent:typing ? 1.0 : 0.8];
    }

    for (UIButton *button in self.actionStack.arrangedSubviews) {
        if (![button isKindOfClass:UIButton.class]) continue;
        button.backgroundColor = assistant ? [brand colorWithAlphaComponent:0.12] : [UIColor.whiteColor colorWithAlphaComponent:0.16];
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
