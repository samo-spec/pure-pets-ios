//
//  PPNovaFloatingInputBarView.m
//  Pure Pets
//

#import "PPNovaFloatingInputBarView.h"

static UIColor *PPNovaComposerDynamicColor(UIColor *lightColor, UIColor *darkColor) {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
        }];
    }
    return lightColor;
}

static UIColor *PPNovaComposerSurfaceColor(UITraitCollection *traitCollection) {
    BOOL isDark = (@available(iOS 13.0, *) ? traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark : NO);
    UIColor *light = (AppForgroundColr ?: UIColor.secondarySystemBackgroundColor);
    UIColor *dark = [UIColor colorWithWhite:0.10 alpha:0.92];
    return isDark ? dark : [light colorWithAlphaComponent:0.94];
}

static UIColor *PPNovaComposerControlColor(UITraitCollection *traitCollection) {
    BOOL isDark = (@available(iOS 13.0, *) ? traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark : NO);
    return isDark
        ? [UIColor colorWithWhite:1.0 alpha:0.10]
        : [UIColor.labelColor colorWithAlphaComponent:0.075];
}

static UIColor *PPNovaComposerBorderColor(UITraitCollection *traitCollection) {
    BOOL isDark = (@available(iOS 13.0, *) ? traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark : NO);
    return isDark
        ? [UIColor colorWithWhite:1.0 alpha:0.13]
        : [UIColor.separatorColor colorWithAlphaComponent:0.18];
}

static UIFont *PPNovaComposerBodyFont(void) {
    UIFont *baseFont = [GM MidFontWithSize:PPFontBody] ?: [UIFont systemFontOfSize:PPFontBody weight:UIFontWeightRegular];
    if (@available(iOS 11.0, *)) {
        return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:baseFont];
    }
    return baseFont;
}

static UIBlurEffectStyle PPNovaComposerBlurStyle(void) {
    if (@available(iOS 13.0, *)) {
        return UIBlurEffectStyleSystemUltraThinMaterial;
    }
    return UIBlurEffectStyleRegular;
}

 static const CGFloat PPNovaComposerMinTextHeight = 40.0;
static const CGFloat PPNovaComposerMaxTextHeight = 128.0;
static const CGFloat PPNovaComposerFocusRingWidth = 0.5;
static const CGFloat PPNovaComposerButtonImageSize = 20.0;
static const CGFloat PPNovaComposerSpinnerLineWidth = 2.0;

static UIImage *PPNovaComposerImageNamed(NSString *systemName, CGFloat pointSize, UIImageSymbolWeight weight) {
    if (@available(iOS 13.0, *)) {
        UIImage *image = [UIImage systemImageNamed:systemName];
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:pointSize
                                                                                                    weight:weight
                                                                                                     scale:UIImageSymbolScaleMedium];
        return [image imageWithConfiguration:configuration];
    }
    return nil;
}

@interface PPNovaFloatingInputBarView () <UITextViewDelegate>

@property (nonatomic, strong) UIView *shadowView;
@property (nonatomic, strong) UIButton *materialView;
@property (nonatomic, strong) UIView *focusRingView;
@property (nonatomic, strong) UIStackView *rowStack;
@property (nonatomic, strong) UIButton *attachmentButton;
@property (nonatomic, strong) UIButton *suggestionsButton;
@property (nonatomic, strong) UIButton *microphoneButton;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (nonatomic, strong) UILabel *attachmentBadgeLabel;
@property (nonatomic, strong) CAShapeLayer *sendSpinnerLayer;
@property (nonatomic, strong) NSLayoutConstraint *textViewHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *placeholderLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *placeholderTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *attachmentBadgeWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *textViewMinimumWidthConstraint;
@property (nonatomic, assign) CGFloat lastReportedHeight;

@end

@implementation PPNovaFloatingInputBarView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
        [self pp_installNotifications];
        [self pp_applyColors];
        [self pp_updateStateAnimated:NO];
        self.alpha = 0.0;
        self.transform = CGAffineTransformMakeTranslation(0.0, PPSpaceSM);
    }
    return self;
}

- (void)dealloc {
    [self pp_stopSendSpinner];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setText:(NSString *)txt {
    self.textView.text = txt ?: @"";
    [self pp_updateTextHeightIfNeeded];
    [self pp_updateStateAnimated:YES];
    if ([self.delegate respondsToSelector:@selector(novaInputBar:didChangeText:)]) {
        [self.delegate novaInputBar:self didChangeText:self.textView.text ?: @""];
    }
}

- (void)setAttachmentEnabled:(BOOL)attachmentEnabled {
    _attachmentEnabled = attachmentEnabled;
    self.attachmentButton.hidden = !attachmentEnabled;
    [self pp_updateStateAnimated:YES];
}

- (void)setMicrophoneEnabled:(BOOL)microphoneEnabled {
    _microphoneEnabled = microphoneEnabled;
    self.microphoneButton.hidden = !microphoneEnabled;
    [self pp_updateStateAnimated:YES];
}

- (void)setSuggestionsEnabled:(BOOL)suggestionsEnabled {
    _suggestionsEnabled = suggestionsEnabled;
    self.suggestionsButton.hidden = !suggestionsEnabled;
    [self pp_updateStateAnimated:YES];
}

- (void)setAttachmentCount:(NSInteger)attachmentCount {
    _attachmentCount = MAX(0, attachmentCount);
    BOOL hasAttachments = self.attachmentCount > 0;
    self.attachmentBadgeLabel.hidden = !hasAttachments;
    self.attachmentBadgeLabel.text = [NSString stringWithFormat:@"%ld", (long)self.attachmentCount];
    CGFloat width = self.attachmentCount > 9 ? PPSpaceXXL : PPSpaceBase;
    self.attachmentBadgeWidthConstraint.constant = width;
    [self pp_updateStateAnimated:YES];
}

- (void)setTextInputFocused:(BOOL)textInputFocused {
    _textInputFocused = textInputFocused;
    [self pp_updateStateAnimated:YES];
}

- (void)setThinking:(BOOL)thinking {
    [self setThinking:thinking animated:NO];
}

- (void)setThinking:(BOOL)thinking animated:(BOOL)animated {
    if (_thinking == thinking) {
        return;
    }

    _thinking = thinking;
    [self pp_updateStateAnimated:animated];
}

- (void)setupUI {
    self.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    self.shadowView = [[UIView alloc] init];
    self.shadowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.shadowView.backgroundColor = UIColor.clearColor;
    self.shadowView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.shadowView.layer.shadowRadius = PPShadowCardRadius;
    self.shadowView.layer.shadowOffset = CGSizeMake(0.0, PPShadowCardOffsetY);
    self.shadowView.layer.shadowOpacity = PPShadowCardOpacity;
    [self addSubview:self.shadowView];

    self.materialView = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleCapsule];
    self.materialView.translatesAutoresizingMaskIntoConstraints = NO;
    if(!PPIOS26())
        PPApplyContinuousCorners(self.materialView, 26.0);
    self.materialView.layer.masksToBounds = YES;

    self.materialView.layer.borderColor = PPNovaComposerBorderColor(self.traitCollection).CGColor;
   // self.materialView.contentView.clipsToBounds = YES;
    [self.shadowView addSubview:self.materialView];

    self.focusRingView = [[UIView alloc] init];
    self.focusRingView.translatesAutoresizingMaskIntoConstraints = NO;
    self.focusRingView.userInteractionEnabled = NO;
    self.focusRingView.backgroundColor = UIColor.clearColor;
    self.focusRingView.layer.borderWidth = PPNovaComposerFocusRingWidth;
    self.focusRingView.layer.cornerRadius = 28.0;
    self.focusRingView.alpha = 0.0;
    if (@available(iOS 13.0, *)) {
        self.focusRingView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.materialView addSubview:self.focusRingView];

    self.rowStack = [[UIStackView alloc] init];
    self.rowStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.rowStack.axis = UILayoutConstraintAxisHorizontal;
    self.rowStack.alignment = UIStackViewAlignmentCenter;
    self.rowStack.distribution = UIStackViewDistributionFill;
    self.rowStack.spacing = PPSpaceSM;
    self.rowStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.materialView addSubview:self.rowStack];

    self.attachmentButton = [self pp_makeActionButtonNamed:@"paperclip" accessibilityKey:@"nova_input_attach_accessibility"];
    [self.attachmentButton addTarget:self action:@selector(pp_attachmentTapped) forControlEvents:UIControlEventTouchUpInside];
    _attachmentEnabled = NO;
    self.attachmentButton.hidden = YES;
    [self.rowStack addArrangedSubview:self.attachmentButton];

    self.suggestionsButton = [self pp_makeActionButtonNamed:@"sparkles" accessibilityKey:@"nova_input_suggestions_accessibility"];
    [self.suggestionsButton addTarget:self action:@selector(pp_suggestionsTapped) forControlEvents:UIControlEventTouchUpInside];
    _suggestionsEnabled = NO;
    self.suggestionsButton.hidden = YES;
    [self.rowStack addArrangedSubview:self.suggestionsButton];

    self.textView = [[UITextView alloc] init];
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.delegate = self;
    self.textView.backgroundColor = UIColor.clearColor;
    self.textView.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    self.textView.font = PPNovaComposerBodyFont();
    self.textView.adjustsFontForContentSizeCategory = YES;
    self.textView.scrollEnabled = NO;
    self.textView.alwaysBounceVertical = NO;
    self.textView.showsVerticalScrollIndicator = NO;
    self.textView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.textView.textAlignment = Language.alignmentForCurrentLanguage;
    self.textView.keyboardAppearance = (@available(iOS 13.0, *) && self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
    self.textView.textContainerInset = UIEdgeInsetsMake(PPSpaceSM, PPSpaceMD, PPSpaceSM, PPSpaceMD);
    self.textView.textContainer.lineFragmentPadding = 0.0;
    self.textView.returnKeyType = UIReturnKeyDefault;
    self.textView.enablesReturnKeyAutomatically = NO;
    self.textView.accessibilityLabel = kLang(@"nova_input_placeholder");
    [self.textView setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.textView setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [self.textView setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
    [self.textView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self.rowStack addArrangedSubview:self.textView];

    self.placeholderLabel = [[UILabel alloc] init];
    self.placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.placeholderLabel.text = kLang(@"nova_input_placeholder");
    self.placeholderLabel.textColor = PPNovaComposerDynamicColor([UIColor colorWithWhite:0.22 alpha:0.42],
                                                                  [UIColor colorWithWhite:1.0 alpha:0.42]);
    self.placeholderLabel.font = self.textView.font;
    self.placeholderLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.placeholderLabel.adjustsFontForContentSizeCategory = YES;
    self.placeholderLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.placeholderLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.placeholderLabel.numberOfLines = 1;
    self.placeholderLabel.userInteractionEnabled = NO;
    [self.placeholderLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.placeholderLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.textView addSubview:self.placeholderLabel];

    self.microphoneButton = [self pp_makeActionButtonNamed:@"mic.fill" accessibilityKey:@"nova_input_microphone_accessibility"];
    [self.microphoneButton addTarget:self action:@selector(pp_microphoneTapped) forControlEvents:UIControlEventTouchUpInside];
    _microphoneEnabled = NO;
    self.microphoneButton.hidden = YES;
    [self.rowStack addArrangedSubview:self.microphoneButton];

    self.sendButton = [self pp_makeActionButtonNamed:@"arrow.up" accessibilityKey:@"nova_input_send_accessibility"];
    [self.sendButton addTarget:self action:@selector(pp_sendTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.rowStack addArrangedSubview:self.sendButton];

    self.attachmentBadgeLabel = [[UILabel alloc] init];
    self.attachmentBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.attachmentBadgeLabel.font = [GM boldFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:PPFontCaption1 weight:UIFontWeightBold];
    self.attachmentBadgeLabel.textColor = UIColor.whiteColor;
    self.attachmentBadgeLabel.textAlignment = NSTextAlignmentCenter;
    self.attachmentBadgeLabel.adjustsFontForContentSizeCategory = YES;
    self.attachmentBadgeLabel.layer.cornerRadius = PPSpaceBase * 0.5;
    self.attachmentBadgeLabel.layer.masksToBounds = YES;
    self.attachmentBadgeLabel.hidden = YES;
    if (@available(iOS 13.0, *)) {
        self.attachmentBadgeLabel.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.attachmentButton addSubview:self.attachmentBadgeLabel];

    self.textViewHeightConstraint = [self.textView.heightAnchor constraintEqualToConstant:PPNovaComposerMinTextHeight];
    self.textViewHeightConstraint.priority = UILayoutPriorityRequired;

    self.placeholderLeadingConstraint = [self.placeholderLabel.leadingAnchor constraintEqualToAnchor:self.textView.leadingAnchor constant:self.textView.textContainerInset.left];
    self.placeholderTrailingConstraint = [self.placeholderLabel.trailingAnchor constraintEqualToAnchor:self.textView.trailingAnchor constant:-self.textView.textContainerInset.right];
    self.placeholderLeadingConstraint.active = !Language.isRTL;
    self.placeholderTrailingConstraint.active = Language.isRTL;

    self.attachmentBadgeWidthConstraint = [self.attachmentBadgeLabel.widthAnchor constraintEqualToConstant:PPSpaceBase];
    self.textViewMinimumWidthConstraint = [self.textView.widthAnchor constraintGreaterThanOrEqualToConstant:88.0];
    self.textViewMinimumWidthConstraint.priority = UILayoutPriorityDefaultHigh;

    [NSLayoutConstraint activateConstraints:@[
        [self.shadowView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.shadowView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.shadowView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.shadowView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [self.materialView.topAnchor constraintEqualToAnchor:self.shadowView.topAnchor],
        [self.materialView.leadingAnchor constraintEqualToAnchor:self.shadowView.leadingAnchor],
        [self.materialView.trailingAnchor constraintEqualToAnchor:self.shadowView.trailingAnchor],
        [self.materialView.bottomAnchor constraintEqualToAnchor:self.shadowView.bottomAnchor],

        [self.focusRingView.topAnchor constraintEqualToAnchor:self.materialView.topAnchor],
        [self.focusRingView.leadingAnchor constraintEqualToAnchor:self.materialView.leadingAnchor],
        [self.focusRingView.trailingAnchor constraintEqualToAnchor:self.materialView.trailingAnchor],
        [self.focusRingView.bottomAnchor constraintEqualToAnchor:self.materialView.bottomAnchor],

        [self.rowStack.topAnchor constraintEqualToAnchor:self.materialView.topAnchor constant:PPSpaceSM],
        [self.rowStack.leadingAnchor constraintEqualToAnchor:self.materialView.leadingAnchor constant:PPSpaceMD],
        [self.rowStack.trailingAnchor constraintEqualToAnchor:self.materialView.trailingAnchor constant:-PPSpaceMD],
        [self.rowStack.bottomAnchor constraintEqualToAnchor:self.materialView.bottomAnchor constant:-PPSpaceSM],

        [self.attachmentButton.widthAnchor constraintEqualToConstant:PPNovaComposerMinTextHeight],
        [self.attachmentButton.heightAnchor constraintEqualToConstant:PPNovaComposerMinTextHeight],
        [self.suggestionsButton.widthAnchor constraintEqualToConstant:PPNovaComposerMinTextHeight],
        [self.suggestionsButton.heightAnchor constraintEqualToConstant:PPNovaComposerMinTextHeight],
        [self.microphoneButton.widthAnchor constraintEqualToConstant:PPNovaComposerMinTextHeight],
        [self.microphoneButton.heightAnchor constraintEqualToConstant:PPNovaComposerMinTextHeight],
        [self.sendButton.widthAnchor constraintEqualToConstant:PPNovaComposerMinTextHeight],
        [self.sendButton.heightAnchor constraintEqualToConstant:PPNovaComposerMinTextHeight],
        self.textViewHeightConstraint,
        self.textViewMinimumWidthConstraint,

        [self.placeholderLabel.topAnchor constraintEqualToAnchor:self.textView.topAnchor constant:self.textView.textContainerInset.top],
        [self.placeholderLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.textView.leadingAnchor constant:self.textView.textContainerInset.left],
        [self.placeholderLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.textView.trailingAnchor constant:-self.textView.textContainerInset.right],

        [self.attachmentBadgeLabel.trailingAnchor constraintEqualToAnchor:self.attachmentButton.trailingAnchor constant:-PPSpaceXS],
        [self.attachmentBadgeLabel.bottomAnchor constraintEqualToAnchor:self.attachmentButton.bottomAnchor constant:-PPSpaceXS],
        self.attachmentBadgeWidthConstraint,
        [self.attachmentBadgeLabel.heightAnchor constraintEqualToConstant:PPSpaceBase]
    ]];

    [self pp_applyLocalizedContent];
    [self pp_applyTextDirection];
}

- (UIButton *)pp_makeActionButtonNamed:(NSString *)systemName accessibilityKey:(NSString *)accessibilityKey {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    if(PPIOS26())
    {
        UIButtonConfiguration *config = [UIButtonConfiguration glassButtonConfiguration];
        config.baseBackgroundColor = UIColor.clearColor;
        config.background.backgroundColor = UIColor.clearColor;
        
        button.configuration = config;
        button.layer.masksToBounds = YES;
    }
    else
    {
        button.backgroundColor = PPNovaComposerControlColor(self.traitCollection);
        button.layer.cornerRadius = PPNovaComposerMinTextHeight * 0.5;
        button.layer.masksToBounds = YES;
        button.layer.borderWidth = 1.0 / [UIScreen mainScreen].scale;
        button.layer.borderColor = PPNovaComposerBorderColor(self.traitCollection).CGColor;
    }
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = AppPrimaryTextClr ?: UIColor.labelColor;
    
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [button setImage:PPNovaComposerImageNamed(systemName, PPNovaComposerButtonImageSize, UIImageSymbolWeightSemibold) forState:UIControlStateNormal];
    button.accessibilityLabel = kLang(accessibilityKey);
    button.accessibilityTraits = UIAccessibilityTraitButton;
    [button addTarget:self action:@selector(pp_pressDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(pp_pressUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
    return button;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.shadowView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.shadowView.bounds
                                                                   cornerRadius:26.0].CGPath;
    [self pp_layoutSendSpinnerLayer];
    [self pp_updateTextHeightIfNeeded];
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(UIViewNoIntrinsicMetric, self.textViewHeightConstraint.constant + (PPSpaceSM * 2.0));
}

- (void)clearText {
    self.textView.text = @"";
    [self pp_updateTextHeightIfNeeded];
    [self pp_updateStateAnimated:YES];
    if ([self.delegate respondsToSelector:@selector(novaInputBar:didChangeText:)]) {
        [self.delegate novaInputBar:self didChangeText:@""];
    }
}

- (void)focusTextInput {
    [self.textView becomeFirstResponder];
}

- (void)pp_suggestionsTapped {
    if (!self.suggestionsEnabled || self.thinking) return;
    [self pp_pressFeedback];
    if ([self.delegate respondsToSelector:@selector(novaInputBarDidTapSuggestions:)]) {
        [self.delegate novaInputBarDidTapSuggestions:self];
    }
}

- (void)pp_attachmentTapped {
    if (!self.attachmentEnabled || self.thinking) return;
    [self pp_pressFeedback];
    if ([self.delegate respondsToSelector:@selector(novaInputBarDidTapAttachment:)]) {
        [self.delegate novaInputBarDidTapAttachment:self];
    }
}

- (void)pp_microphoneTapped {
    if (!self.microphoneEnabled || self.thinking) return;
    [self pp_pressFeedback];
    if ([self.delegate respondsToSelector:@selector(novaInputBarDidTapMicrophone:)]) {
        [self.delegate novaInputBarDidTapMicrophone:self];
    }
}

- (void)pp_sendTapped {
    NSString *trimmedText = [self.textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmedText.length == 0 || self.thinking) {
        [self pp_pressFeedback];
        return;
    }

    if ([self.delegate respondsToSelector:@selector(novaInputBar:didSendText:)]) {
        [self.delegate novaInputBar:self didSendText:trimmedText];
    }
    [self clearText];
}

- (void)pp_updateTextHeightIfNeeded {
    CGFloat targetWidth = CGRectGetWidth(self.textView.bounds);
    if (targetWidth < 1.0) {
        return;
    }

    CGSize fittingSize = [self.textView sizeThatFits:CGSizeMake(targetWidth, CGFLOAT_MAX)];
    CGFloat minHeight = PPNovaComposerMinTextHeight;
    CGFloat maxHeight = PPNovaComposerMaxTextHeight;
    CGFloat nextHeight = MIN(MAX(ceil(fittingSize.height), minHeight), maxHeight);
    BOOL shouldScroll = fittingSize.height > maxHeight;

    if (fabs(self.textViewHeightConstraint.constant - nextHeight) > 0.5) {
        self.textViewHeightConstraint.constant = nextHeight;
        [self invalidateIntrinsicContentSize];
        if ([self.delegate respondsToSelector:@selector(novaInputBar:didChangeHeight:)]) {
            CGFloat totalHeight = nextHeight + (PPSpaceSM * 2.0);
            if (fabs(self.lastReportedHeight - totalHeight) > 0.5) {
                self.lastReportedHeight = totalHeight;
                [self.delegate novaInputBar:self didChangeHeight:totalHeight];
            }
        }
    }
    self.textView.scrollEnabled = shouldScroll;
    if (shouldScroll && self.textView.selectedRange.location != NSNotFound) {
        [self.textView scrollRangeToVisible:self.textView.selectedRange];
    }
}

- (void)pp_installNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_contentSizeCategoryDidChange:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_languageDidChange:)
                                                 name:PPLanguageDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_reduceMotionDidChange:)
                                                 name:UIAccessibilityReduceMotionStatusDidChangeNotification
                                               object:nil];
}

- (void)pp_contentSizeCategoryDidChange:(NSNotification *)notification {
    UIFont *bodyFont = PPNovaComposerBodyFont();
    self.textView.font = bodyFont;
    self.placeholderLabel.font = bodyFont;
    self.attachmentBadgeLabel.font = [GM boldFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:PPFontCaption1 weight:UIFontWeightBold];
    [self pp_updateTextHeightIfNeeded];
    [self pp_updateStateAnimated:NO];
}

- (void)pp_languageDidChange:(NSNotification *)notification {
    [self pp_applyLocalizedContent];
    [self pp_applyTextDirection];
    [self pp_updateTextHeightIfNeeded];
    [self pp_updateStateAnimated:NO];
}

- (void)pp_reduceMotionDidChange:(NSNotification *)notification {
    if (self.thinking) {
        [self pp_stopSendSpinner];
        [self pp_startSendSpinner];
    }
    [self pp_updateStateAnimated:NO];
}

- (void)pp_applyLocalizedContent {
    self.placeholderLabel.text = kLang(@"nova_input_placeholder");
    self.textView.accessibilityLabel = kLang(@"nova_input_placeholder");
    self.attachmentButton.accessibilityLabel = kLang(@"nova_input_attach_accessibility");
    self.suggestionsButton.accessibilityLabel = kLang(@"nova_input_suggestions_accessibility");
    self.microphoneButton.accessibilityLabel = kLang(@"nova_input_microphone_accessibility");
    self.sendButton.accessibilityLabel = self.thinking ? kLang(@"nova_typing") : kLang(@"nova_input_send_accessibility");
}

- (void)pp_applyTextDirection {
    UISemanticContentAttribute semantic = [Language semanticAttributeForCurrentLanguage];
    NSTextAlignment alignment = Language.alignmentForCurrentLanguage;
    self.semanticContentAttribute = semantic;
    self.materialView.semanticContentAttribute = semantic;
    self.rowStack.semanticContentAttribute = semantic;
    self.textView.semanticContentAttribute = semantic;
    self.textView.textAlignment = alignment;
    self.placeholderLabel.semanticContentAttribute = semantic;
    self.placeholderLabel.textAlignment = alignment;
    self.placeholderLeadingConstraint.active = !Language.isRTL;
    self.placeholderTrailingConstraint.active = Language.isRTL;
}

- (void)pp_applyBaseControlChrome {
    UIColor *neutralControl = PPNovaComposerControlColor(self.traitCollection);
    UIColor *separator = PPNovaComposerBorderColor(self.traitCollection);
    UIColor *controlTextColor = AppPrimaryTextClr ?: UIColor.labelColor;
    NSArray<UIButton *> *buttons = @[self.attachmentButton, self.suggestionsButton, self.microphoneButton, self.sendButton];
    for (UIButton *button in buttons) {
        if (![button isKindOfClass:UIButton.class]) {
            continue;
        }
        button.backgroundColor = neutralControl;
        button.tintColor = controlTextColor;
        button.layer.borderColor = separator.CGColor;
    }
}

- (void)pp_updateStateAnimated:(BOOL)animated {
    [self pp_applyTextDirection];

    BOOL hasText = [self.textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0;
    BOOL canSend = hasText && !self.thinking;
    BOOL sendShowsActivity = self.thinking;
    BOOL sendEmphasized = canSend || sendShowsActivity;
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    UIColor *brand = AppPrimaryClr ?: UIColor.systemOrangeColor;
    UIColor *neutralControl = PPNovaComposerControlColor(self.traitCollection);
    UIColor *separator = PPNovaComposerBorderColor(self.traitCollection);
    UIColor *placeholder = PPNovaComposerDynamicColor([UIColor colorWithWhite:0.22 alpha:0.42],
                                                       [UIColor colorWithWhite:1.0 alpha:0.42]);
    self.sendButton.enabled = canSend;
    self.sendButton.accessibilityLabel = sendShowsActivity ? kLang(@"nova_typing") : kLang(@"nova_input_send_accessibility");
    self.sendButton.accessibilityTraits = canSend ? UIAccessibilityTraitButton : UIAccessibilityTraitButton | UIAccessibilityTraitNotEnabled;
    self.attachmentButton.enabled = self.attachmentEnabled && !self.thinking;
    self.microphoneButton.enabled = self.microphoneEnabled && !self.thinking;
    self.suggestionsButton.enabled = self.suggestionsEnabled && !self.thinking;
    self.attachmentButton.accessibilityTraits = self.attachmentButton.enabled ? UIAccessibilityTraitButton : UIAccessibilityTraitButton | UIAccessibilityTraitNotEnabled;
    self.microphoneButton.accessibilityTraits = self.microphoneButton.enabled ? UIAccessibilityTraitButton : UIAccessibilityTraitButton | UIAccessibilityTraitNotEnabled;
    self.suggestionsButton.accessibilityTraits = self.suggestionsButton.enabled ? UIAccessibilityTraitButton : UIAccessibilityTraitButton | UIAccessibilityTraitNotEnabled;
    self.attachmentButton.accessibilityElementsHidden = self.attachmentButton.hidden;
    self.microphoneButton.accessibilityElementsHidden = self.microphoneButton.hidden;
    self.suggestionsButton.accessibilityElementsHidden = self.suggestionsButton.hidden;
    self.attachmentBadgeLabel.accessibilityElementsHidden = self.attachmentBadgeLabel.hidden;
    self.attachmentButton.accessibilityValue = self.attachmentCount > 0 ? self.attachmentBadgeLabel.text : nil;

    UIColor *activeBorder = [brand colorWithAlphaComponent:self.textInputFocused ? 0.24 : 0.14];
    UIColor *controlTextColor = AppPrimaryTextClr ?: UIColor.labelColor;

    void (^changes)(void) = ^{
        self.placeholderLabel.alpha = hasText ? 0.0 : 1.0;
        self.placeholderLabel.textColor = placeholder;
        self.sendButton.alpha = sendShowsActivity ? 0.94 : 1.0;
        self.sendButton.backgroundColor = sendEmphasized ? brand : neutralControl;
        self.sendButton.tintColor = sendEmphasized ? UIColor.whiteColor : controlTextColor;
        self.sendButton.layer.borderColor = (hasText || self.textInputFocused ? activeBorder : separator).CGColor;
        self.sendButton.imageView.hidden = sendShowsActivity;
        self.attachmentBadgeLabel.backgroundColor = self.attachmentEnabled ? brand : neutralControl;

        self.attachmentButton.backgroundColor = neutralControl;
        self.attachmentButton.tintColor = controlTextColor;
        self.attachmentButton.layer.borderColor = separator.CGColor;
        self.microphoneButton.backgroundColor = neutralControl;
        self.microphoneButton.tintColor = controlTextColor;
        self.microphoneButton.layer.borderColor = separator.CGColor;
        self.suggestionsButton.backgroundColor = self.suggestionsEnabled ? [brand colorWithAlphaComponent:0.12] : neutralControl;
        self.suggestionsButton.tintColor = self.suggestionsEnabled ? brand : controlTextColor;
        self.suggestionsButton.layer.borderColor = (self.suggestionsEnabled ? [brand colorWithAlphaComponent:0.22] : separator).CGColor;

        self.materialView.layer.borderColor = (hasText || self.textInputFocused ? [brand colorWithAlphaComponent:0.28] : separator).CGColor;
        self.shadowView.layer.shadowRadius = hasText || self.textInputFocused ? PPShadowElevatedRadius : PPShadowCardRadius;
        self.shadowView.layer.shadowOffset = CGSizeMake(0.0, hasText || self.textInputFocused ? PPShadowElevatedOffsetY : PPShadowCardOffsetY);
        self.shadowView.layer.shadowOpacity = hasText || self.textInputFocused ? PPShadowElevatedOpacity : PPShadowCardOpacity;
        self.focusRingView.layer.borderColor = [brand colorWithAlphaComponent:self.textInputFocused ? 0.42 : 0.18].CGColor;
        self.focusRingView.alpha = (hasText || self.textInputFocused) ? 1.0 : 0.0;

        self.attachmentButton.alpha = self.attachmentButton.enabled ? 1.0 : 0.0;
        self.microphoneButton.alpha = self.microphoneButton.enabled ? 1.0 : 0.0;
        self.suggestionsButton.alpha = self.suggestionsButton.enabled ? 1.0 : 0.0;
    };

    if (sendShowsActivity) {
        [self pp_startSendSpinner];
    } else {
        [self pp_stopSendSpinner];
        [self.sendButton setImage:PPNovaComposerImageNamed(@"arrow.up", 20.0, UIImageSymbolWeightSemibold) forState:UIControlStateNormal];
        self.sendButton.imageView.hidden = NO;
    }

    if (!animated || reduceMotion) {
        changes();
        return;
    }

    [UIView animateWithDuration:0.22
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:changes
                     completion:nil];
}

- (void)pp_applyColors {
    UIColor *brand = AppPrimaryClr ?: UIColor.systemOrangeColor;
    self.materialView.backgroundColor = PPIOS26() ? UIColor.clearColor : PPNovaComposerSurfaceColor(self.traitCollection);
    self.focusRingView.layer.borderColor = [brand colorWithAlphaComponent:self.textInputFocused ? 0.42 : 0.18].CGColor;
    self.textView.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    self.textView.tintColor = brand;
    self.textView.keyboardAppearance = (@available(iOS 13.0, *) && self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
    [self pp_applyBaseControlChrome];
    [self pp_updateStateAnimated:NO];
}

- (void)pp_startSendSpinner {
    if (self.sendSpinnerLayer) {
        return;
    }

    CAShapeLayer *spinner = [CAShapeLayer layer];
    spinner.fillColor = UIColor.clearColor.CGColor;
    spinner.strokeColor = UIColor.whiteColor.CGColor;
    spinner.lineWidth = PPNovaComposerSpinnerLineWidth;
    spinner.lineCap = kCALineCapRound;
    spinner.strokeStart = 0.10;
    spinner.strokeEnd = 0.82;
    [self.sendButton.layer addSublayer:spinner];
    self.sendSpinnerLayer = spinner;
    [self pp_layoutSendSpinnerLayer];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    CABasicAnimation *spin = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    spin.fromValue = @0.0;
    spin.toValue = @(M_PI * 2.0);
    spin.duration = 0.86;
    spin.repeatCount = HUGE_VALF;
    spin.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    [spinner addAnimation:spin forKey:@"novaComposerSendSpinnerRotation"];
}

- (void)pp_stopSendSpinner {
    [self.sendSpinnerLayer removeAllAnimations];
    [self.sendSpinnerLayer removeFromSuperlayer];
    self.sendSpinnerLayer = nil;
}

- (void)pp_layoutSendSpinnerLayer {
    if (!self.sendSpinnerLayer || CGRectIsEmpty(self.sendButton.bounds)) {
        return;
    }

    CGRect bounds = self.sendButton.bounds;
    CGFloat diameter = MIN(CGRectGetWidth(bounds), CGRectGetHeight(bounds));
    CGFloat radius = MAX((diameter - PPSpaceBase) * 0.5, 8.0);
    CGPoint center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
    UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:center
                                                        radius:radius
                                                    startAngle:-M_PI_2
                                                      endAngle:(M_PI * 1.5)
                                                     clockwise:YES];
    self.sendSpinnerLayer.frame = bounds;
    self.sendSpinnerLayer.path = path.CGPath;
}

- (void)pp_pressFeedback {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [generator prepare];
        [generator impactOccurred];
    }
}

- (void)pp_pressDown:(UIView *)view {
    BOOL disabled = [view isKindOfClass:UIControl.class] ? !((UIControl *)view).enabled : NO;
    if (UIAccessibilityIsReduceMotionEnabled() || disabled) return;
    [UIView animateWithDuration:PPAnimDurationFast
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        view.transform = CGAffineTransformMakeScale(PPTapScaleDown, PPTapScaleDown);
    } completion:nil];
}

- (void)pp_pressUp:(UIView *)view {
    BOOL disabled = [view isKindOfClass:UIControl.class] ? !((UIControl *)view).enabled : NO;
    if (UIAccessibilityIsReduceMotionEnabled() || disabled) return;
    [UIView animateWithDuration:PPAnimDurationNormal
                          delay:0.0
         usingSpringWithDamping:PPAnimSpringDamping
          initialSpringVelocity:PPAnimSpringVelocity
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        view.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidBeginEditing:(UITextView *)textView {
    self.textInputFocused = YES;
    if ([self.delegate respondsToSelector:@selector(novaInputBarDidBeginEditing:)]) {
        [self.delegate novaInputBarDidBeginEditing:self];
    }
}

- (void)textViewDidEndEditing:(UITextView *)textView {
    self.textInputFocused = NO;
}

- (void)textViewDidChange:(UITextView *)textView {
    [self pp_updateTextHeightIfNeeded];
    [self pp_updateStateAnimated:YES];
    if ([self.delegate respondsToSelector:@selector(novaInputBar:didChangeText:)]) {
        [self.delegate novaInputBar:self didChangeText:textView.text ?: @""];
    }
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    return YES;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self pp_applyColors];
    [self pp_updateTextHeightIfNeeded];
    [self pp_updateStateAnimated:NO];
}

@end
