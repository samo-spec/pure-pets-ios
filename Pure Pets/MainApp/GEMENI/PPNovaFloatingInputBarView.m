//
//  PPNovaFloatingInputBarView.m
//  Pure Pets
//

#import "PPNovaFloatingInputBarView.h"

static UIColor *PPNovaInputDynamicColor(UIColor *lightColor, UIColor *darkColor) {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
        }];
    }
    return lightColor;
}

@interface PPNovaFloatingInputBarView () <UITextViewDelegate>

@property (nonatomic, strong) UIView *shadowView;
@property (nonatomic, strong) UIVisualEffectView *materialView;
@property (nonatomic, strong) UIView *ambientTintView;
@property (nonatomic, strong) UIStackView *rowStack;
@property (nonatomic, strong) UIButton *suggestionsButton;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (nonatomic, strong) NSLayoutConstraint *textViewHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *placeholderLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *placeholderTrailingConstraint;
@property (nonatomic, assign) CGFloat lastReportedHeight;

@end

@implementation PPNovaFloatingInputBarView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
        [self pp_applyColors];
        [self pp_updateStateAnimated:NO];
    }
    return self;
}

-(void)setText:(NSString *)txt
{
    self.textView.text = txt ?: @"";
    [self pp_updateTextHeightIfNeeded];
    [self pp_updateStateAnimated:YES];
    if ([self.delegate respondsToSelector:@selector(novaInputBar:didChangeText:)]) {
        [self.delegate novaInputBar:self didChangeText:self.textView.text ?: @""];
    }
}

- (void)setupUI {
    self.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    self.shadowView = [[UIView alloc] init];
    self.shadowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.shadowView.backgroundColor = UIColor.clearColor;
    self.shadowView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.shadowView.layer.shadowOpacity = 0.12;
    self.shadowView.layer.shadowRadius = 24.0;
    self.shadowView.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    [self addSubview:self.shadowView];

    UIBlurEffectStyle blurStyle = UIBlurEffectStyleRegular;
    if (@available(iOS 13.0, *)) {
        blurStyle = UIBlurEffectStyleSystemUltraThinMaterial;
    }
    self.materialView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:blurStyle]];
    self.materialView.translatesAutoresizingMaskIntoConstraints = NO;
    self.materialView.layer.cornerRadius = 28.0;
    self.materialView.layer.masksToBounds = YES;
    self.materialView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.materialView.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.18].CGColor;
    if (@available(iOS 13.0, *)) {
        self.materialView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.shadowView addSubview:self.materialView];
    self.materialView.contentView.clipsToBounds = YES;

    self.ambientTintView = [[UIView alloc] init];
    self.ambientTintView.translatesAutoresizingMaskIntoConstraints = NO;
    self.ambientTintView.userInteractionEnabled = NO;
    self.ambientTintView.alpha = 0.18;
    [self.materialView.contentView addSubview:self.ambientTintView];

    self.rowStack = [[UIStackView alloc] init];
    self.rowStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.rowStack.axis = UILayoutConstraintAxisHorizontal;
    self.rowStack.alignment = UIStackViewAlignmentBottom;
    self.rowStack.spacing = 7.0;
    self.rowStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.materialView.contentView addSubview:self.rowStack];

    self.suggestionsButton = [self pp_makeIconButtonNamed:@"sparkles" accessibilityKey:@"nova_input_suggestions_accessibility"];
    [self.suggestionsButton addTarget:self action:@selector(pp_suggestionsTapped) forControlEvents:UIControlEventTouchUpInside];
    self.suggestionsButton.hidden = YES;
    self.suggestionsButton.alpha = 0;
    //[self.rowStack addArrangedSubview:self.suggestionsButton];

    self.textView = [[UITextView alloc] init];
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.delegate = self;
    self.textView.backgroundColor = UIColor.clearColor;
    self.textView.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    self.textView.tintColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    self.textView.font = [GM fontWithSize:PPFontBody] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
    self.textView.adjustsFontForContentSizeCategory = YES;
    self.textView.scrollEnabled = NO;
    self.textView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.textView.textAlignment = Language.alignmentForCurrentLanguage;
    self.textView.textContainerInset = UIEdgeInsetsMake(8.0, 0.0, 8.0, 0.0);
    self.textView.textContainer.lineFragmentPadding = 0.0;
    self.textView.returnKeyType = UIReturnKeyDefault;
    self.textView.enablesReturnKeyAutomatically = NO;
    [self.rowStack addArrangedSubview:self.textView];

    self.placeholderLabel = [[UILabel alloc] init];
    self.placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.placeholderLabel.text = kLang(@"nova_input_placeholder");
    self.placeholderLabel.textColor = PPNovaInputDynamicColor([UIColor colorWithWhite:0.25 alpha:0.38],
                                                             [UIColor colorWithWhite:1.0 alpha:0.38]);
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

    self.sendButton = [self pp_makeIconButtonNamed:@"arrow.up" accessibilityKey:@"nova_input_send_accessibility"];
    [self.sendButton addTarget:self action:@selector(pp_sendTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.rowStack addArrangedSubview:self.sendButton];

    self.textViewHeightConstraint = [self.textView.heightAnchor constraintEqualToConstant:40.0];
    self.textViewHeightConstraint.priority = UILayoutPriorityRequired;

    [NSLayoutConstraint activateConstraints:@[
        [self.shadowView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.shadowView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.shadowView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.shadowView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [self.materialView.topAnchor constraintEqualToAnchor:self.shadowView.topAnchor],
        [self.materialView.leadingAnchor constraintEqualToAnchor:self.shadowView.leadingAnchor],
        [self.materialView.trailingAnchor constraintEqualToAnchor:self.shadowView.trailingAnchor],
        [self.materialView.bottomAnchor constraintEqualToAnchor:self.shadowView.bottomAnchor],

        [self.rowStack.topAnchor constraintEqualToAnchor:self.materialView.contentView.topAnchor constant:7.0],
        [self.ambientTintView.topAnchor constraintEqualToAnchor:self.materialView.contentView.topAnchor],
        [self.ambientTintView.leadingAnchor constraintEqualToAnchor:self.materialView.contentView.leadingAnchor],
        [self.ambientTintView.trailingAnchor constraintEqualToAnchor:self.materialView.contentView.trailingAnchor],
        [self.ambientTintView.bottomAnchor constraintEqualToAnchor:self.materialView.contentView.bottomAnchor],

        [self.rowStack.leadingAnchor constraintEqualToAnchor:self.materialView.contentView.leadingAnchor constant:12.0],
        [self.rowStack.trailingAnchor constraintEqualToAnchor:self.materialView.contentView.trailingAnchor constant:-7.0],
        [self.rowStack.bottomAnchor constraintEqualToAnchor:self.materialView.contentView.bottomAnchor constant:-7.0],

        //[self.suggestionsButton.widthAnchor constraintEqualToConstant:0.0],
        //[self.suggestionsButton.heightAnchor constraintEqualToConstant:0.0],
        [self.sendButton.widthAnchor constraintEqualToConstant:38.0],
        [self.sendButton.heightAnchor constraintEqualToConstant:38.0],
        self.textViewHeightConstraint,

        // Placeholder tracks the first text line instead of the text view center,
        // so it stays stable when Dynamic Type or multiline height changes.
        [self.placeholderLabel.topAnchor constraintEqualToAnchor:self.textView.topAnchor constant:self.textView.textContainerInset.top],
        [self.placeholderLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.textView.leadingAnchor],
        [self.placeholderLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.textView.trailingAnchor]
    ]];

    self.placeholderLeadingConstraint = [self.placeholderLabel.leadingAnchor constraintEqualToAnchor:self.textView.leadingAnchor];
    self.placeholderTrailingConstraint = [self.placeholderLabel.trailingAnchor constraintEqualToAnchor:self.textView.trailingAnchor];
    self.placeholderLeadingConstraint.active = YES;
    self.placeholderTrailingConstraint.active = YES;
    [self pp_applyTextDirection];
}

- (UIButton *)pp_makeIconButtonNamed:(NSString *)systemName accessibilityKey:(NSString *)accessibilityKey {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = AppPrimaryTextClr ?: UIColor.labelColor;
    button.backgroundColor = PPNovaInputDynamicColor([UIColor colorWithWhite:1.0 alpha:0.82],
                                                    [UIColor colorWithWhite:1.0 alpha:0.10]);
    button.layer.cornerRadius = 19.0;
    button.layer.masksToBounds = YES;
    button.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    button.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.14].CGColor;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    UIImage *image = [UIImage systemImageNamed:systemName];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightSemibold];
        image = [image imageWithConfiguration:configuration];
    }
    [button setImage:image forState:UIControlStateNormal];
    button.accessibilityLabel = kLang(accessibilityKey);
    [button addTarget:self action:@selector(pp_pressDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(pp_pressUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
    return button;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self pp_updateTextHeightIfNeeded];
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(UIViewNoIntrinsicMetric, self.textViewHeightConstraint.constant + 14.0);
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
    [self pp_pressFeedback];
    if ([self.delegate respondsToSelector:@selector(novaInputBarDidTapSuggestions:)]) {
        [self.delegate novaInputBarDidTapSuggestions:self];
    }
}

- (void)pp_sendTapped {
    NSString *trimmedText = [self.textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmedText.length == 0) {
        [self pp_pressFeedback];
        return;
    }

    if ([self.delegate respondsToSelector:@selector(novaInputBar:didSendText:)]) {
        [self.delegate novaInputBar:self didSendText:trimmedText];
    }
    [self clearText];
}

- (void)pp_updateTextHeightIfNeeded {
    CGFloat targetWidth = MAX(self.textView.bounds.size.width, 1.0);
    CGSize fittingSize = [self.textView sizeThatFits:CGSizeMake(targetWidth, CGFLOAT_MAX)];
    CGFloat maxHeight = 112.0;
    CGFloat nextHeight = MIN(MAX(ceil(fittingSize.height), 40.0), maxHeight);
    BOOL shouldScroll = fittingSize.height > maxHeight;

    if (fabs(self.textViewHeightConstraint.constant - nextHeight) > 0.5) {
        self.textViewHeightConstraint.constant = nextHeight;
        [self invalidateIntrinsicContentSize];
        if ([self.delegate respondsToSelector:@selector(novaInputBar:didChangeHeight:)]) {
            CGFloat totalHeight = nextHeight + 14.0;
            if (fabs(self.lastReportedHeight - totalHeight) > 0.5) {
                self.lastReportedHeight = totalHeight;
                [self.delegate novaInputBar:self didChangeHeight:totalHeight];
            }
        }
    }
    self.textView.scrollEnabled = shouldScroll;
}

- (void)pp_applyTextDirection {
    BOOL rtl = Language.isRTL;
    UISemanticContentAttribute semantic = rtl
        ? UISemanticContentAttributeForceRightToLeft
        : UISemanticContentAttributeForceLeftToRight;
    NSTextAlignment alignment = rtl ? NSTextAlignmentRight : NSTextAlignmentLeft;
    self.semanticContentAttribute = semantic;
    self.materialView.contentView.semanticContentAttribute = semantic;
    self.rowStack.semanticContentAttribute = semantic;
    self.textView.semanticContentAttribute = semantic;
    self.textView.textAlignment = alignment;
    self.placeholderLabel.semanticContentAttribute = semantic;
    self.placeholderLabel.textAlignment = alignment;
    self.placeholderLeadingConstraint.active = !rtl;
    self.placeholderTrailingConstraint.active = rtl;
}

- (void)pp_updateStateAnimated:(BOOL)animated {
    BOOL hasText = [self.textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0;
    UIColor *brand = AppPrimaryClr ?: UIColor.systemOrangeColor;
    UIColor *activeFill = brand;
    UIColor *idleFill = [brand colorWithAlphaComponent:0.32];
    UIColor *iconTint = UIColor.whiteColor;
    UIColor *idleBorder = [UIColor.separatorColor colorWithAlphaComponent:0.18];
    UIColor *activeBorder = [brand colorWithAlphaComponent:0.25];

    UIImage *image = [UIImage systemImageNamed:@"arrow.up"];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:18.0 weight:UIImageSymbolWeightSemibold];
        image = [image imageWithConfiguration:configuration];
    }

    void (^changes)(void) = ^{
        [self pp_applyTextDirection];
        self.placeholderLabel.alpha = hasText ? 0.0 : 1.0;
        self.sendButton.backgroundColor = hasText ? activeFill : idleFill;
        self.sendButton.tintColor = iconTint;
        [self.sendButton setImage:image forState:UIControlStateNormal];
        self.materialView.layer.borderColor = (hasText ? activeBorder : idleBorder).CGColor;
        self.shadowView.layer.shadowOpacity = hasText ? 0.17 : 0.12;
        self.ambientTintView.alpha = hasText ? 0.25 : 0.18;
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        changes();
        return;
    }

    [UIView transitionWithView:self.sendButton
                      duration:0.18
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction
                    animations:changes
                    completion:nil];
}

- (void)pp_applyColors {
    UIColor *brand = AppPrimaryClr ?: UIColor.systemOrangeColor;
    UIColor *surface = PPNovaInputDynamicColor([UIColor colorWithWhite:1.0 alpha:0.95],
                                             [UIColor colorWithWhite:0.10 alpha:0.94]);
    self.materialView.contentView.backgroundColor = surface;
    self.ambientTintView.backgroundColor = PPNovaInputDynamicColor([brand colorWithAlphaComponent:0.12],
                                                                   [brand colorWithAlphaComponent:0.18]);
    self.materialView.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.18].CGColor;
    self.textView.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    self.textView.tintColor = brand;
    self.suggestionsButton.tintColor = brand;
    self.suggestionsButton.backgroundColor = PPNovaInputDynamicColor([brand colorWithAlphaComponent:0.10],
                                                                     [brand colorWithAlphaComponent:0.16]);
    self.suggestionsButton.layer.borderColor = [brand colorWithAlphaComponent:0.16].CGColor;
    [self pp_updateStateAnimated:NO];
}

- (void)pp_pressFeedback {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [generator impactOccurred];
    }
}

- (void)pp_pressDown:(UIView *)view {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    [UIView animateWithDuration:0.10 delay:0.0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        view.transform = CGAffineTransformMakeScale(0.94, 0.94);
    } completion:nil];
}

- (void)pp_pressUp:(UIView *)view {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    [UIView animateWithDuration:0.22 delay:0.0 usingSpringWithDamping:0.86 initialSpringVelocity:0.18 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        view.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidBeginEditing:(UITextView *)textView {
    if ([self.delegate respondsToSelector:@selector(novaInputBarDidBeginEditing:)]) {
        [self.delegate novaInputBarDidBeginEditing:self];
    }
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
}

@end
