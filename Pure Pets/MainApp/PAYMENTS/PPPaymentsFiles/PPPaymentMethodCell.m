//
//  PPPaymentMethodCell.m
//  Pure Pets
//

#import "PPPaymentMethodCell.h"

@interface PPPaymentMethodCell ()
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *iconContainerView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIStackView *textStack;
@property (nonatomic, strong) UIView *selectionView;
@property (nonatomic, strong) UIImageView *selectionImageView;
@property (nonatomic, strong) UIImageView *disclosureView;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *inlineConstraints;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *expandedConstraints;
@property (nonatomic, assign) BOOL expandedTextLayout;
@property (nonatomic, assign) BOOL addNewStyle;
@property (nonatomic, assign) BOOL currentSelectionState;
@end

@implementation PPPaymentMethodCell

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self pp_buildUI];
    }
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.indexPath = nil;
    self.instrument = nil;
    self.method = nil;
    self.addNewStyle = NO;
    self.currentSelectionState = NO;
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.iconView.image = nil;
    self.disclosureView.hidden = YES;
    self.selectionView.hidden = NO;
    self.accessibilityLabel = nil;
    self.accessibilityValue = nil;
    self.accessibilityHint = nil;
    self.accessibilityIdentifier = nil;
    [self updateSelectionState:NO animated:NO];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self pp_applyTypographyForTraits:self.traitCollection];
    [self updateSelectionState:self.currentSelectionState animated:NO];
}

#pragma mark - Layout

- (void)pp_buildUI
{
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;

    self.surfaceView = [UIView new];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.surfaceView, PPCornerCard);
    [self.contentView addSubview:self.surfaceView];

    // Payment marks keep their own colors on a quiet, neutral plate.
    self.iconContainerView = [UIView new];
    self.iconContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconContainerView.backgroundColor = UIColor.tertiarySystemBackgroundColor;
    PPApplyContinuousCorners(self.iconContainerView, 12.0);
    [self.surfaceView addSubview:self.iconContainerView];

    self.iconView = [UIImageView new];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.iconContainerView addSubview:self.iconView];

    self.selectionView = [UIView new];
    self.selectionView.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.selectionView, 12.0);
    [self.surfaceView addSubview:self.selectionView];
    UIImageSymbolConfiguration *checkConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:11.0 weight:UIImageSymbolWeightBold];
    self.selectionImageView = [[UIImageView alloc] initWithImage:
        [[UIImage systemImageNamed:@"checkmark"] imageByApplyingSymbolConfiguration:checkConfiguration]];
    self.selectionImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionImageView.contentMode = UIViewContentModeCenter;
    [self.selectionView addSubview:self.selectionImageView];

    self.disclosureView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.forward"]];
    self.disclosureView.translatesAutoresizingMaskIntoConstraints = NO;
    self.disclosureView.contentMode = UIViewContentModeCenter;
    self.disclosureView.tintColor = AppSecondaryTextClr;
    self.disclosureView.hidden = YES;
    [self.surfaceView addSubview:self.disclosureView];

    self.titleLabel = [UILabel new];
    self.titleLabel.textColor = AppPrimaryTextClr;
    self.subtitleLabel = [UILabel new];
    self.subtitleLabel.textColor = AppSecondaryTextClr;
    for (UILabel *label in @[self.titleLabel, self.subtitleLabel]) {
        label.translatesAutoresizingMaskIntoConstraints = NO;
        label.numberOfLines = 0;
        label.lineBreakMode = NSLineBreakByWordWrapping;
        label.adjustsFontForContentSizeCategory = YES;
        label.adjustsFontSizeToFitWidth = NO;
        [label setContentCompressionResistancePriority:UILayoutPriorityRequired
                                              forAxis:UILayoutConstraintAxisVertical];
    }
    self.textStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.titleLabel, self.subtitleLabel]];
    self.textStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.textStack.axis = UILayoutConstraintAxisVertical;
    self.textStack.alignment = UIStackViewAlignmentFill;
    self.textStack.spacing = 6.0;
    [self.surfaceView addSubview:self.textStack];

    [self.surfaceView addGestureRecognizer:[[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(pp_didTapCard)]];
    [NSLayoutConstraint activateConstraints:@[
        [self.surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.surfaceView.heightAnchor constraintGreaterThanOrEqualToConstant:88.0],
        [self.iconContainerView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:16.0],
        [self.iconContainerView.widthAnchor constraintEqualToConstant:52.0],
        [self.iconContainerView.heightAnchor constraintEqualToConstant:44.0],
        [self.iconView.leadingAnchor constraintEqualToAnchor:self.iconContainerView.leadingAnchor constant:8.0],
        [self.iconView.trailingAnchor constraintEqualToAnchor:self.iconContainerView.trailingAnchor constant:-8.0],
        [self.iconView.topAnchor constraintEqualToAnchor:self.iconContainerView.topAnchor constant:8.0],
        [self.iconView.bottomAnchor constraintEqualToAnchor:self.iconContainerView.bottomAnchor constant:-8.0],
        [self.selectionView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-16.0],
        [self.selectionView.centerYAnchor constraintEqualToAnchor:self.iconContainerView.centerYAnchor],
        [self.selectionView.widthAnchor constraintEqualToConstant:24.0],
        [self.selectionView.heightAnchor constraintEqualToConstant:24.0],
        [self.selectionImageView.centerXAnchor constraintEqualToAnchor:self.selectionView.centerXAnchor],
        [self.selectionImageView.centerYAnchor constraintEqualToAnchor:self.selectionView.centerYAnchor],
        [self.disclosureView.centerXAnchor constraintEqualToAnchor:self.selectionView.centerXAnchor],
        [self.disclosureView.centerYAnchor constraintEqualToAnchor:self.selectionView.centerYAnchor],
        [self.textStack.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor constant:-20.0],
    ]];
    self.inlineConstraints = @[
        [self.iconContainerView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.textStack.leadingAnchor constraintEqualToAnchor:self.iconContainerView.trailingAnchor constant:16.0],
        [self.textStack.trailingAnchor constraintEqualToAnchor:self.selectionView.leadingAnchor constant:-12.0],
        [self.textStack.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:20.0],
    ];
    self.expandedConstraints = @[
        [self.iconContainerView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:20.0],
        [self.textStack.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:16.0],
        [self.textStack.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-16.0],
        [self.textStack.topAnchor constraintEqualToAnchor:self.iconContainerView.bottomAnchor constant:16.0],
    ];
    [NSLayoutConstraint activateConstraints:self.inlineConstraints];
    [self pp_applyTypographyForTraits:self.traitCollection];
    [self updateSelectionState:NO animated:NO];
}

- (void)pp_applyTypographyForTraits:(UITraitCollection *)traits
{
    UIFont *titleFont = [GM boldFontWithSize:17.0] ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    UIFont *subtitleFont = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightRegular];
    self.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline]
        scaledFontForFont:titleFont compatibleWithTraitCollection:traits];
    self.subtitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
        scaledFontForFont:subtitleFont compatibleWithTraitCollection:traits];
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.surfaceView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.textStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    BOOL expanded = UIContentSizeCategoryIsAccessibilityCategory(traits.preferredContentSizeCategory);
    if (expanded != self.expandedTextLayout) {
        [NSLayoutConstraint deactivateConstraints:self.expandedTextLayout ? self.expandedConstraints : self.inlineConstraints];
        self.expandedTextLayout = expanded;
        [NSLayoutConstraint activateConstraints:expanded ? self.expandedConstraints : self.inlineConstraints];
    }
}

+ (CGFloat)heightForInstrument:(UserPaymentInstrument *)instrument
                       method:(PaymentMethod *)method
                        width:(CGFloat)width
              traitCollection:(UITraitCollection *)traitCollection
{
    // The sizing cell uses the exact same labels, constraints and font traits as a visible row.
    // No category-based height table: long translations and AX5 are allowed their full height.
    PPPaymentMethodCell *sizingCell = [[self alloc] initWithFrame:CGRectMake(0.0, 0.0, width, 88.0)];
    [sizingCell configureWithInstrument:instrument method:method indexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
    [sizingCell pp_applyTypographyForTraits:traitCollection];
    CGSize size = [sizingCell.contentView systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)
                                     withHorizontalFittingPriority:UILayoutPriorityRequired
                                           verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    return ceil(MAX(88.0, size.height));
}

#pragma mark - Configuration

- (void)configureWithInstrument:(UserPaymentInstrument *)instrument
                         method:(PaymentMethod *)method
                      indexPath:(NSIndexPath *)indexPath
{
    self.indexPath = indexPath;
    self.instrument = instrument;
    self.method = method;
    self.addNewStyle = NO;
    [self pp_applyTypographyForTraits:self.traitCollection];
    self.titleLabel.text = kLang(method.displayName);
    self.subtitleLabel.text = [self pp_subtitleForInstrument:instrument method:method];
    self.subtitleLabel.hidden = self.subtitleLabel.text.length == 0;
    self.iconView.image = [self pp_iconForMethod:method];
    self.iconView.tintColor = AppPrimaryTextClr;
    self.disclosureView.hidden = YES;
    self.selectionView.hidden = NO;
    NSString *identity = instrument.instrumentID.length > 0 ? instrument.instrumentID : (method.methodID ?: @"unknown");
    self.accessibilityIdentifier = [NSString stringWithFormat:@"payment.instrument.%@", identity];
    [self updateSelectionState:instrument.isDefault animated:NO];
}

- (void)configureAsAddNewIndexPath:(NSIndexPath *)indexPath
{
    self.indexPath = indexPath;
    self.instrument = nil;
    self.method = nil;
    self.addNewStyle = YES;
    [self pp_applyTypographyForTraits:self.traitCollection];
    self.titleLabel.text = kLang(@"payment_add_method");
    self.subtitleLabel.text = kLang(@"payment_add_method_subtitle");
    self.subtitleLabel.hidden = NO;
    self.iconView.image = [UIImage systemImageNamed:@"plus"];
    self.iconView.tintColor = AppPrimaryClr;
    self.selectionView.hidden = YES;
    self.disclosureView.hidden = NO;
    self.accessibilityIdentifier = @"payment.method.add";
    [self updateSelectionState:NO animated:NO];
}

- (void)updateSelectionState:(BOOL)isSelected animated:(BOOL)animated
{
    self.currentSelectionState = !self.addNewStyle && isSelected;
    UIColor *accent = AppPrimaryClr ?: UIColor.systemBlueColor;
    void (^changes)(void) = ^{
        self.surfaceView.backgroundColor = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
        [self.surfaceView pp_setBorderColor:self.currentSelectionState ? accent : [UIColor ppSurfaceBorder]];
        self.surfaceView.layer.borderWidth = self.currentSelectionState ? 2.0 : (UIAccessibilityDarkerSystemColorsEnabled() ? 1.5 : 1.0);
        self.selectionView.backgroundColor = self.currentSelectionState ? accent : UIColor.clearColor;
        [self.selectionView pp_setBorderColor:self.currentSelectionState ? accent : UIColor.tertiaryLabelColor];
        self.selectionView.layer.borderWidth = self.currentSelectionState ? 0.0 : 1.5;
        self.selectionImageView.tintColor = UIColor.whiteColor;
        self.selectionImageView.alpha = self.currentSelectionState ? 1.0 : 0.0;
    };
    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.18 delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:changes completion:nil];
    } else {
        [self.surfaceView.layer removeAllAnimations];
        [self.selectionView.layer removeAllAnimations];
        [self.selectionImageView.layer removeAllAnimations];
        changes();
    }
    [self pp_updateAccessibilityText];
}

#pragma mark - Actions

- (void)pp_didTapCard
{
    if (self.addNewStyle || !self.instrument || !self.method) {
        if ([self.delegate respondsToSelector:@selector(showPaymentSheetFull:)]) {
            [self.delegate showPaymentSheetFull:NO];
        }
        return;
    }
    if ([self.delegate respondsToSelector:@selector(paymentMethodCellDidRequestDefault:instrument:method:)]) {
        [self.delegate paymentMethodCellDidRequestDefault:self instrument:self.instrument method:self.method];
    }
}

- (BOOL)accessibilityActivate
{
    [self pp_didTapCard];
    return YES;
}

#pragma mark - Content

- (NSString *)pp_subtitleForInstrument:(UserPaymentInstrument *)instrument method:(PaymentMethod *)method
{
    NSString *details = method.type == PaymentMethodTypeCash || instrument.maskedDetails.length == 0
        ? kLang(method.methodDescription) : instrument.maskedDetails;
    if (details.length == 0) { return @""; }
    // Isolate only technical mask/number runs; surrounding Arabic keeps its reading direction.
    static NSRegularExpression *maskExpression;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        maskExpression = [NSRegularExpression regularExpressionWithPattern:@"[\\d*•●][\\d*•● \\-]{2,}[\\d*•●]"
                                                                   options:0 error:nil];
    });
    NSMutableString *result = [details mutableCopy];
    NSArray<NSTextCheckingResult *> *matches = [maskExpression matchesInString:details options:0 range:NSMakeRange(0, details.length)];
    for (NSTextCheckingResult *match in matches.reverseObjectEnumerator) {
        NSString *run = [details substringWithRange:match.range];
        [result replaceCharactersInRange:match.range withString:[NSString stringWithFormat:@"\u2066%@\u2069", run]];
    }
    return result;
}

- (UIImage *)pp_iconForMethod:(PaymentMethod *)method
{
    UIImage *asset = method.iconName.length > 0 ? [UIImage imageNamed:method.iconName] : nil;
    if (asset) { return [asset imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]; }
    NSString *methodID = method.methodID.lowercaseString ?: @"";
    if ([methodID isEqualToString:@"applepay"] || method.type == PaymentMethodTypeApplePay) {
        UIImage *appleLogo = [UIImage imageNamed:@"appleLogo"];
        if (appleLogo) { return [appleLogo imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]; }
    }
    NSString *symbol = method.type == PaymentMethodTypeCash || [methodID isEqualToString:@"cash"]
        ? @"banknote" : @"creditcard";
    return [[UIImage systemImageNamed:symbol] imageByApplyingSymbolConfiguration:
        [UIImageSymbolConfiguration configurationWithPointSize:22.0 weight:UIImageSymbolWeightMedium]];
}

+ (UIColor *)accentColorForMethod:(PaymentMethod *)method
{
    NSString *methodID = method.methodID.lowercaseString ?: @"";
    if ([methodID isEqualToString:@"cash"] || method.type == PaymentMethodTypeCash) {
        return AppSuccessClr;
    }
    return AppPrimaryClr ?: UIColor.systemBlueColor;
}

- (void)pp_updateAccessibilityText
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (self.titleLabel.text.length > 0) { [parts addObject:self.titleLabel.text]; }
    if (self.subtitleLabel.text.length > 0) { [parts addObject:self.subtitleLabel.text]; }
    self.accessibilityLabel = [parts componentsJoinedByString:@", "];
    self.accessibilityValue = nil;
    self.accessibilityHint = self.currentSelectionState || self.addNewStyle ? nil : kLang(@"payment_method_tap_to_choose");
    self.accessibilityTraits = UIAccessibilityTraitButton | (self.currentSelectionState ? UIAccessibilityTraitSelected : 0);
}

@end
