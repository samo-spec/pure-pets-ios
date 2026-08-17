//
//  PPPaymentMethodCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 03/02/2026.
//

#import "PPPaymentMethodCell.h"

static CGFloat const kPPPaymentCellCornerRadius = PPCornerCard;

@interface PPPaymentMethodCell ()

@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *iconContainerView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) PPInsetLabel *statusLabel;
@property (nonatomic, strong) UIStackView *titleHeaderStack;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIStackView *textStack;
@property (nonatomic, strong) UIView *selectionView;
@property (nonatomic, strong) UIImageView *selectionImageView;
@property (nonatomic, strong) UIImageView *disclosureView;
@property (nonatomic, strong) UITapGestureRecognizer *tapGesture;
@property (nonatomic, strong) CAShapeLayer *dashedBorderLayer;
@property (nonatomic, assign) BOOL addNewStyle;
@property (nonatomic, assign) BOOL currentSelectionState;

@end

@implementation PPPaymentMethodCell

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
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

    self.titleLabel.text = @"";
    self.subtitleLabel.text = @"";
    self.statusLabel.text = @"";
    self.statusLabel.hidden = YES;
    self.iconView.image = nil;
     
    self.disclosureView.hidden = YES;
    self.selectionView.hidden = NO;
    self.accessibilityLabel = nil;
    self.accessibilityValue = nil;
    self.accessibilityIdentifier = nil;

    [self pp_applyDashedBorderVisible:NO];
    [self updateSelectionState:NO animated:NO];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    self.layer.shadowPath =
    [UIBezierPath bezierPathWithRoundedRect:self.surfaceView.frame
                               cornerRadius:self.surfaceView.layer.cornerRadius].CGPath;

    if (!self.dashedBorderLayer.hidden) {
        self.dashedBorderLayer.frame = self.surfaceView.bounds;
        self.dashedBorderLayer.path =
        [UIBezierPath bezierPathWithRoundedRect:self.surfaceView.bounds
                                   cornerRadius:self.surfaceView.layer.cornerRadius].CGPath;
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (!previousTraitCollection ||
        [self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self updateSelectionState:self.currentSelectionState animated:NO];
    }
}

#pragma mark - UI

- (void)pp_buildUI
{
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;

    PPApplyCardShadow(self);

    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.surfaceView.backgroundColor = [self pp_surfaceColorSelected:NO addNew:NO accentColor:nil];
    PPApplyContinuousCorners(self.surfaceView, kPPPaymentCellCornerRadius);
    self.surfaceView.layer.borderWidth = 1.0;
    [self.surfaceView pp_setBorderColor:[self pp_borderColorSelected:NO addNew:NO accentColor:nil]];
    [self.contentView addSubview:self.surfaceView];

    self.dashedBorderLayer = [CAShapeLayer layer];
    self.dashedBorderLayer.lineWidth = 1.4;
    self.dashedBorderLayer.lineDashPattern = @[@7, @7];
    self.dashedBorderLayer.fillColor = UIColor.clearColor.CGColor;
    self.dashedBorderLayer.hidden = YES;
    [self.surfaceView.layer addSublayer:self.dashedBorderLayer];

    self.iconContainerView = [[UIView alloc] init];
    self.iconContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.iconContainerView, 12.0);
    self.iconContainerView.clipsToBounds = YES;
    [self.surfaceView addSubview:self.iconContainerView];

    self.iconView = [[UIImageView alloc] init];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.isAccessibilityElement = NO;
    [self.iconContainerView addSubview:self.iconView];

    self.selectionView = [[UIView alloc] init];
    self.selectionView.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.selectionView, 12.0);
    self.selectionView.layer.borderWidth = 1.5;
    self.selectionView.isAccessibilityElement = NO;
    [self.surfaceView addSubview:self.selectionView];

    UIImageSymbolConfiguration *checkConfig =
    [UIImageSymbolConfiguration configurationWithPointSize:10.0
                                                    weight:UIImageSymbolWeightBold
                                                     scale:UIImageSymbolScaleSmall];
    UIImage *checkImage = [[UIImage systemImageNamed:@"checkmark"] imageByApplyingSymbolConfiguration:checkConfig];
    self.selectionImageView = [[UIImageView alloc] initWithImage:checkImage];
    self.selectionImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionImageView.contentMode = UIViewContentModeCenter;
    self.selectionImageView.isAccessibilityElement = NO;
    [self.selectionView addSubview:self.selectionImageView];

    self.disclosureView = [[UIImageView alloc] initWithImage:[self pp_disclosureImage]];
    self.disclosureView.translatesAutoresizingMaskIntoConstraints = NO;
    self.disclosureView.contentMode = UIViewContentModeScaleAspectFit;
    self.disclosureView.tintColor = UIColor.tertiaryLabelColor;
    self.disclosureView.hidden = YES;
    [self.surfaceView addSubview:self.disclosureView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *titleBaseFont = [GM boldFontWithSize:15.5]
        ?: [UIFont systemFontOfSize:15.5 weight:UIFontWeightBold];
    self.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline]
        scaledFontForFont:titleBaseFont
        maximumPointSize:24.0];
    self.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.titleLabel.textColor = AppPrimaryTextClr;
    self.titleLabel.numberOfLines = 0;
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.85;
    self.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.titleLabel.textAlignment = NSTextAlignmentNatural;
    [self.titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh
                                                     forAxis:UILayoutConstraintAxisHorizontal];

    self.statusLabel = [[PPInsetLabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *statusBaseFont = [GM boldFontWithSize:11.0]
        ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    self.statusLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption2]
        scaledFontForFont:statusBaseFont
        maximumPointSize:15.0];
    self.statusLabel.adjustsFontForContentSizeCategory = YES;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 1;
    self.statusLabel.adjustsFontSizeToFitWidth = NO;
    self.statusLabel.textInsets = UIEdgeInsetsMake(2.0, 6.0, 2.0, 6.0);
    self.statusLabel.layer.cornerRadius = 7.0;
    self.statusLabel.layer.masksToBounds = YES;
    self.statusLabel.hidden = YES;
    [self.statusLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.statusLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    self.titleHeaderStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.titleLabel,
        self.statusLabel
    ]];
    self.titleHeaderStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleHeaderStack.axis = UILayoutConstraintAxisHorizontal;
    self.titleHeaderStack.alignment = UIStackViewAlignmentCenter;
    self.titleHeaderStack.distribution = UIStackViewDistributionFill;
    self.titleHeaderStack.spacing = 6.0;

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *subtitleBaseFont = [GM MidFontWithSize:12.5]
        ?: [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    self.subtitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
        scaledFontForFont:subtitleBaseFont
        maximumPointSize:18.0];
    self.subtitleLabel.adjustsFontForContentSizeCategory = YES;
    self.subtitleLabel.textColor = AppSecondaryTextClr;
    self.subtitleLabel.numberOfLines = 0;
    self.subtitleLabel.adjustsFontSizeToFitWidth = YES;
    self.subtitleLabel.minimumScaleFactor = 0.85;
    self.subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.subtitleLabel.textAlignment = NSTextAlignmentNatural;

    self.textStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.titleHeaderStack,
        self.subtitleLabel
    ]];
    self.textStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.textStack.axis = UILayoutConstraintAxisVertical;
    self.textStack.alignment = UIStackViewAlignmentFill;
    self.textStack.distribution = UIStackViewDistributionFill;
    self.textStack.spacing = 2.5;
    [self.surfaceView addSubview:self.textStack];

    self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_didTapCard)];
    [self.surfaceView addGestureRecognizer:self.tapGesture];

    [NSLayoutConstraint activateConstraints:@[
        [self.surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:1.0],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-1.0],
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:1.0],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-1.0],

        [self.iconContainerView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:14.0],
        [self.iconContainerView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.iconContainerView.widthAnchor constraintEqualToConstant:44.0],
        [self.iconContainerView.heightAnchor constraintEqualToConstant:44.0],

        [self.iconView.centerXAnchor constraintEqualToAnchor:self.iconContainerView.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:self.iconContainerView.centerYAnchor],
        [self.iconView.widthAnchor constraintLessThanOrEqualToConstant:26.0],
        [self.iconView.heightAnchor constraintLessThanOrEqualToConstant:26.0],

        [self.selectionView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-14.0],
        [self.selectionView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.selectionView.widthAnchor constraintEqualToConstant:24.0],
        [self.selectionView.heightAnchor constraintEqualToConstant:24.0],

        [self.selectionImageView.centerXAnchor constraintEqualToAnchor:self.selectionView.centerXAnchor],
        [self.selectionImageView.centerYAnchor constraintEqualToAnchor:self.selectionView.centerYAnchor],

        [self.disclosureView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-14.0],
        [self.disclosureView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.disclosureView.widthAnchor constraintEqualToConstant:12.0],
        [self.disclosureView.heightAnchor constraintEqualToConstant:14.0],

        [self.textStack.leadingAnchor constraintEqualToAnchor:self.iconContainerView.trailingAnchor constant:12.0],
        [self.textStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.selectionView.leadingAnchor constant:-10.0],
        [self.textStack.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.textStack.topAnchor constraintGreaterThanOrEqualToAnchor:self.surfaceView.topAnchor constant:8.0],
        [self.textStack.bottomAnchor constraintLessThanOrEqualToAnchor:self.surfaceView.bottomAnchor constant:-8.0]
    ]];
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

    UIColor *accentColor = [self pp_accentColorForMethod:method];
    [self pp_applyMethodVisualsWithAccentColor:accentColor selected:instrument.isDefault addNew:NO];

    self.iconView.image = [self pp_iconForMethod:method];
    BOOL isApplePay = [method.methodID.lowercaseString isEqualToString:@"applepay"] ||
        method.type == PaymentMethodTypeApplePay;
    self.iconView.tintColor = isApplePay ? AppPrimaryTextClr : accentColor;
    self.titleLabel.text = kLang(method.displayName);
    self.subtitleLabel.text = [self pp_subtitleForInstrument:instrument method:method];
    
    NSString *statusText = [self pp_statusTextForSelection:instrument.isDefault];
    self.statusLabel.text = statusText;
    self.statusLabel.hidden = (statusText.length == 0);
    self.statusLabel.textColor = instrument.isDefault ? UIColor.whiteColor : accentColor;

    self.disclosureView.hidden = YES;
    self.selectionView.hidden = NO;
 
    [self pp_applyDashedBorderVisible:NO];
    [self updateSelectionState:instrument.isDefault animated:NO];
    NSString *instrumentIdentity = instrument.instrumentID.length > 0
        ? instrument.instrumentID
        : (method.methodID ?: @"unknown");
    self.accessibilityIdentifier = [NSString stringWithFormat:
        @"payment.instrument.%@",
        instrumentIdentity
    ];
    [self pp_updateAccessibilityText];
}

- (void)configureAsAddNewIndexPath:(NSIndexPath *)indexPath
{
    self.indexPath = indexPath;
    self.instrument = nil;
    self.method = nil;
    self.addNewStyle = YES;

    UIColor *accentColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    [self pp_applyMethodVisualsWithAccentColor:accentColor selected:NO addNew:YES];

    self.iconView.image = [UIImage systemImageNamed:@"plus"];
    self.iconView.tintColor = accentColor;
    self.statusLabel.text = kLang(@"payment_add_method_badge");
    self.statusLabel.hidden = NO;
    self.statusLabel.textColor = accentColor;
    self.titleLabel.text = kLang(@"payment_add_method");
    self.subtitleLabel.text = kLang(@"payment_add_method_subtitle");

    self.selectionView.hidden = YES;
    self.disclosureView.image = [self pp_disclosureImage];
    self.disclosureView.hidden = NO;

    [self pp_applyDashedBorderVisible:YES];
    [self updateSelectionState:NO animated:NO];
    self.accessibilityIdentifier = @"payment.method.add";
    [self pp_updateAccessibilityText];
}

- (void)updateSelectionState:(BOOL)isSelected animated:(BOOL)animated
{
    self.currentSelectionState = isSelected;

    if (!self.addNewStyle && !self.instrument && !self.method) {
        self.statusLabel.text = @"";
        self.statusLabel.hidden = YES;
        self.selectionView.hidden = NO;
        [self pp_applyMethodVisualsWithAccentColor:(AppPrimaryClr ?: UIColor.systemBlueColor) selected:NO addNew:NO];
        return;
    }

    UIColor *accentColor = self.addNewStyle ? (AppPrimaryClr ?: UIColor.systemBlueColor) : [self pp_accentColorForMethod:self.method];
    void (^changes)(void) = ^{
        [self pp_applyMethodVisualsWithAccentColor:accentColor selected:isSelected addNew:self.addNewStyle];
        NSString *status = [self pp_statusTextForSelection:isSelected];
        self.statusLabel.text = status;
        self.statusLabel.hidden = (status.length == 0);
        self.statusLabel.textColor = isSelected ? UIColor.whiteColor : accentColor;
        self.selectionImageView.alpha = isSelected ? 1.0 : 0.0;
        self.selectionImageView.tintColor = isSelected ? UIColor.whiteColor : UIColor.clearColor;
        self.selectionView.transform = isSelected ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.82, 0.82);
    };

    if (self.addNewStyle) {
        self.selectionView.hidden = YES;
        self.statusLabel.textColor = accentColor;
        changes();
        return;
    }

    self.selectionView.hidden = NO;
    BOOL shouldAnimate = animated && !UIAccessibilityIsReduceMotionEnabled();
    if (shouldAnimate) {
        [UIView animateWithDuration:0.18
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut |
                                    UIViewAnimationOptionBeginFromCurrentState |
                                    UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            changes();
        } completion:nil];
    } else {
        changes();
        self.surfaceView.transform = CGAffineTransformIdentity;
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

#pragma mark - Helpers

- (void)pp_applyMethodVisualsWithAccentColor:(UIColor *)accentColor
                                    selected:(BOOL)isSelected
                                      addNew:(BOOL)addNew
{
    UIColor *safeAccent = accentColor ?: (AppPrimaryClr ?: UIColor.systemBlueColor);
    self.surfaceView.backgroundColor = [self pp_surfaceColorSelected:isSelected addNew:addNew accentColor:safeAccent];
    [self.surfaceView pp_setBorderColor:[self pp_borderColorSelected:isSelected addNew:addNew accentColor:safeAccent]];
    self.surfaceView.layer.borderWidth = UIAccessibilityDarkerSystemColorsEnabled()
        ? (isSelected ? 2.0 : 1.5)
        : (isSelected ? 1.5 : 1.0);

    self.iconContainerView.backgroundColor = addNew
    ? [safeAccent colorWithAlphaComponent:0.12]
    : [safeAccent colorWithAlphaComponent:isSelected ? 0.16 : 0.10];

    self.selectionView.backgroundColor = isSelected ? safeAccent : UIColor.clearColor;
    [self.selectionView pp_setBorderColor:isSelected ? safeAccent : [UIColor.separatorColor colorWithAlphaComponent:0.32]];

    self.statusLabel.backgroundColor = isSelected
    ? safeAccent
    : [safeAccent colorWithAlphaComponent:addNew ? 0.12 : 0.10];

    self.layer.shadowOpacity = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? 0.0
        : (isSelected ? PPShadowElevatedOpacity : PPShadowCardOpacity);
    self.layer.shadowRadius = isSelected ? PPShadowElevatedRadius : PPShadowCardRadius;
}

- (UIColor *)pp_surfaceColorSelected:(BOOL)isSelected
                              addNew:(BOOL)addNew
                         accentColor:(UIColor *)accentColor
{
    UIColor *base = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
    UIColor *safeAccent = accentColor ?: (AppPrimaryClr ?: UIColor.systemBlueColor);
    if (addNew) {
        return [base colorWithAlphaComponent:PPIOS26() ? 0.52 : 0.92];
    }
    if (isSelected) {
        return [safeAccent colorWithAlphaComponent:PPIOS26() ? 0.16 : 0.075];
    }
    return [base colorWithAlphaComponent:PPIOS26() ? 0.58 : 0.98];
}

- (UIColor *)pp_borderColorSelected:(BOOL)isSelected
                             addNew:(BOOL)addNew
                        accentColor:(UIColor *)accentColor
{
    UIColor *safeAccent = accentColor ?: (AppPrimaryClr ?: UIColor.systemBlueColor);
    if (addNew) {
        return [safeAccent colorWithAlphaComponent:0.26];
    }
    if (isSelected) {
        return [safeAccent colorWithAlphaComponent:
            UIAccessibilityDarkerSystemColorsEnabled() ? 0.72 : 0.46];
    }
    return [[UIColor ppSurfaceBorder] colorWithAlphaComponent:
        UIAccessibilityDarkerSystemColorsEnabled() ? 1.0 : 0.72];
}

- (NSString *)pp_subtitleForInstrument:(UserPaymentInstrument *)instrument
                                method:(PaymentMethod *)method
{
    if (method.type == PaymentMethodTypeCash) {
        return kLang(method.methodDescription);
    }
    return instrument.maskedDetails.length > 0
    ? instrument.maskedDetails
    : kLang(method.methodDescription);
}

- (UIImage *)pp_disclosureImage
{
    UIImageSymbolConfiguration *configuration =
    [UIImageSymbolConfiguration configurationWithPointSize:13.0
                                                    weight:UIImageSymbolWeightSemibold
                                                     scale:UIImageSymbolScaleSmall];
    NSString *symbolName = Language.isRTL ? @"chevron.left" : @"chevron.right";
    return [[UIImage systemImageNamed:symbolName] imageByApplyingSymbolConfiguration:configuration];
}

- (UIImage *)pp_iconForMethod:(PaymentMethod *)method
{
    UIImage *assetImage = method.iconName.length > 0 ? [UIImage imageNamed:method.iconName] : nil;
    if (assetImage) {
        return [assetImage imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    }

    NSString *normalizedMethodID = method.methodID.lowercaseString ?: @"";
    if ([normalizedMethodID isEqualToString:@"applepay"] || method.type == PaymentMethodTypeApplePay) {
        UIImage *appleLogo = [UIImage imageNamed:@"appleLogo"];
        if (appleLogo) {
            return [appleLogo imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
    }

    NSString *symbolName = @"creditcard.fill";
    if ([normalizedMethodID isEqualToString:@"cash"] || method.type == PaymentMethodTypeCash) {
        symbolName = @"shippingbox.fill";
    }
    else if ([normalizedMethodID isEqualToString:@"qib"]) {
        symbolName = @"lock.shield.fill";
    }

    UIImageSymbolConfiguration *configuration =
    [UIImageSymbolConfiguration configurationWithPointSize:19.0
                                                    weight:UIImageSymbolWeightSemibold
                                                     scale:UIImageSymbolScaleMedium];
    return [[UIImage systemImageNamed:symbolName] imageByApplyingSymbolConfiguration:configuration];
}

+ (UIColor *)accentColorForMethod:(PaymentMethod *)method
{
    NSString *normalizedMethodID = method.methodID.lowercaseString ?: @"";
    if ([normalizedMethodID isEqualToString:@"cash"] || method.type == PaymentMethodTypeCash) {
        return AppSuccessClr;
    }
    return AppPrimaryClr ?: UIColor.systemBlueColor;
}

- (UIColor *)pp_accentColorForMethod:(PaymentMethod *)method
{
    return [PPPaymentMethodCell accentColorForMethod:method];
}

- (void)pp_applyDashedBorderVisible:(BOOL)visible
{
    self.dashedBorderLayer.hidden = !visible;
    if (!visible) {
        return;
    }

    UIColor *dashColor = [AppPrimaryClr ?: UIColor.systemBlueColor colorWithAlphaComponent:0.28];
    self.dashedBorderLayer.strokeColor = dashColor.CGColor;
    self.dashedBorderLayer.frame = self.surfaceView.bounds;
    self.dashedBorderLayer.path =
    [UIBezierPath bezierPathWithRoundedRect:self.surfaceView.bounds
                               cornerRadius:self.surfaceView.layer.cornerRadius].CGPath;
}

- (NSString *)pp_statusTextForSelection:(BOOL)isSelected
{
    if (self.addNewStyle) {
        return kLang(@"payment_add_method_badge");
    }
    if (isSelected) {
        return kLang(@"payment_method_selected_badge");
    }
    return @"";
}

- (void)pp_updateAccessibilityText
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (self.titleLabel.text.length > 0) {
        [parts addObject:self.titleLabel.text];
    }
    if (self.subtitleLabel.text.length > 0) {
        [parts addObject:self.subtitleLabel.text];
    }
    self.accessibilityLabel = [parts componentsJoinedByString:@", "];
    self.accessibilityValue = self.currentSelectionState
        ? nil
        : self.statusLabel.text;
    self.accessibilityTraits = UIAccessibilityTraitButton |
        (self.currentSelectionState ? UIAccessibilityTraitSelected : 0);
}

@end
