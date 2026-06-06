//
//  PPPaymentMethodCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 03/02/2026.
//

#import "PPPaymentMethodCell.h"

static CGFloat const kPPPaymentCellCornerRadius = 24.0;
static CGFloat const kPPPaymentCellInnerInset = 14.0;
static CGFloat const kPPPaymentCellIconSize = 38.0;
static CGFloat const kPPPaymentCellActionSize = 30.0;

@interface PPPaymentMethodCell ()

@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *iconContainerView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIStackView *brandStack;
@property (nonatomic, strong) NSArray<UIImageView *> *brandImageViews;
 @property (nonatomic, strong) UIView *selectionView;
@property (nonatomic, strong) UIImageView *selectionImageView;
@property (nonatomic, strong) UIImageView *disclosureView;
@property (nonatomic, strong) UITapGestureRecognizer *tapGesture;
@property (nonatomic, strong) CAShapeLayer *dashedBorderLayer;
@property (nonatomic, strong) NSLayoutConstraint *statusTrailingToMenuConstraint;
@property (nonatomic, strong) NSLayoutConstraint *statusTrailingToSurfaceConstraint;
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
    self.iconView.image = nil;
     
    self.brandStack.hidden = YES;
    self.disclosureView.hidden = YES;
    self.selectionView.hidden = NO;
    self.accessibilityLabel = nil;
    [self pp_updateStatusTrailingForMenuVisible:NO];

    for (UIImageView *brandView in self.brandImageViews) {
        brandView.image = nil;
        brandView.hidden = YES;
    }

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

#pragma mark - UI

- (void)pp_buildUI
{
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;

    [self pp_setShadowColor:UIColor.blackColor];
    self.layer.shadowOpacity = 0.07;
    self.layer.shadowRadius = 20.0;
    self.layer.shadowOffset = CGSizeMake(0.0, 12.0);

    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.surfaceView.backgroundColor = [self pp_surfaceColorSelected:NO addNew:NO accentColor:nil];
    self.surfaceView.layer.cornerRadius = kPPPaymentCellCornerRadius;
    self.surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
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
    self.iconContainerView.layer.cornerRadius = 16.0;
    self.iconContainerView.layer.cornerCurve = kCACornerCurveContinuous;
    self.iconContainerView.clipsToBounds = YES;
    [self.surfaceView addSubview:self.iconContainerView];

    self.iconView = [[UIImageView alloc] init];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.iconContainerView addSubview:self.iconView];

    self.selectionView = [[UIView alloc] init];
    self.selectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionView.layer.cornerRadius = 11.0;
    self.selectionView.layer.cornerCurve = kCACornerCurveContinuous;
    self.selectionView.layer.borderWidth = 1.0;
    [self.surfaceView addSubview:self.selectionView];

    UIImageSymbolConfiguration *checkConfig =
    [UIImageSymbolConfiguration configurationWithPointSize:10.0
                                                    weight:UIImageSymbolWeightBold
                                                     scale:UIImageSymbolScaleSmall];
    UIImage *checkImage = [[UIImage systemImageNamed:@"checkmark"] imageByApplyingSymbolConfiguration:checkConfig];
    self.selectionImageView = [[UIImageView alloc] initWithImage:checkImage];
    self.selectionImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionImageView.contentMode = UIViewContentModeCenter;
    [self.selectionView addSubview:self.selectionImageView];
  

    self.disclosureView = [[UIImageView alloc] initWithImage:[self pp_disclosureImage]];
    self.disclosureView.translatesAutoresizingMaskIntoConstraints = NO;
    self.disclosureView.contentMode = UIViewContentModeScaleAspectFit;
    self.disclosureView.tintColor = UIColor.tertiaryLabelColor;
    self.disclosureView.hidden = YES;
    [self.surfaceView addSubview:self.disclosureView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [GM boldFontWithSize:15.0];
    self.titleLabel.textColor = UIColor.labelColor;
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.82;
    self.titleLabel.textAlignment = NSTextAlignmentNatural;
    [self.surfaceView addSubview:self.titleLabel];

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [GM MidFontWithSize:12.5];
    self.subtitleLabel.textColor = UIColor.secondaryLabelColor;
    self.subtitleLabel.numberOfLines = 2;
    self.subtitleLabel.adjustsFontSizeToFitWidth = YES;
    self.subtitleLabel.minimumScaleFactor = 0.82;
    self.subtitleLabel.textAlignment = NSTextAlignmentNatural;
    [self.surfaceView addSubview:self.subtitleLabel];

    NSMutableArray<UIImageView *> *brandViews = [NSMutableArray array];
    for (NSInteger index = 0; index < 3; index++) {
        UIImageView *brandView = [[UIImageView alloc] init];
        brandView.translatesAutoresizingMaskIntoConstraints = NO;
        brandView.contentMode = UIViewContentModeScaleAspectFit;
        brandView.backgroundColor = [UIColor.systemBackgroundColor colorWithAlphaComponent:0.86];
        brandView.layer.cornerRadius = 5.0;
        brandView.layer.cornerCurve = kCACornerCurveContinuous;
        brandView.layer.borderWidth = 0.6;
        [brandView pp_setBorderColor:[UIColor.separatorColor colorWithAlphaComponent:0.18]];
        brandView.clipsToBounds = YES;
        brandView.hidden = YES;
        [NSLayoutConstraint activateConstraints:@[
            [brandView.widthAnchor constraintEqualToConstant:28.0],
            [brandView.heightAnchor constraintEqualToConstant:18.0],
        ]];
        [brandViews addObject:brandView];
    }
    self.brandImageViews = brandViews.copy;

    self.brandStack = [[UIStackView alloc] initWithArrangedSubviews:self.brandImageViews];
    self.brandStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.brandStack.axis = UILayoutConstraintAxisHorizontal;
    self.brandStack.alignment = UIStackViewAlignmentCenter;
    self.brandStack.spacing = 5.0;
    self.brandStack.hidden = YES;
    [self.surfaceView addSubview:self.brandStack];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [GM boldFontWithSize:10.5];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 1;
    self.statusLabel.adjustsFontSizeToFitWidth = YES;
    self.statusLabel.minimumScaleFactor = 0.78;
    self.statusLabel.layer.cornerRadius = 10.0;
    self.statusLabel.layer.cornerCurve = kCACornerCurveContinuous;
    self.statusLabel.layer.masksToBounds = YES;
    [self.statusLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.statusLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.surfaceView addSubview:self.statusLabel];

    self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_didTapCard)];
    [self.surfaceView addGestureRecognizer:self.tapGesture];

    self.statusTrailingToMenuConstraint =
    [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8.0];
    self.statusTrailingToSurfaceConstraint =
    [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-kPPPaymentCellInnerInset];
    self.statusTrailingToSurfaceConstraint.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [self.surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:1.0],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-1.0],
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:1.0],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-1.0],

        [self.iconContainerView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:kPPPaymentCellInnerInset],
        [self.iconContainerView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:kPPPaymentCellInnerInset],
        [self.iconContainerView.widthAnchor constraintEqualToConstant:kPPPaymentCellIconSize],
        [self.iconContainerView.heightAnchor constraintEqualToConstant:kPPPaymentCellIconSize],

        [self.iconView.centerXAnchor constraintEqualToAnchor:self.iconContainerView.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:self.iconContainerView.centerYAnchor],
        [self.iconView.widthAnchor constraintLessThanOrEqualToConstant:22.0],
        [self.iconView.heightAnchor constraintLessThanOrEqualToConstant:22.0],

 

        [self.selectionView.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:16.0],
        [self.selectionView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-16.0],
        [self.selectionView.widthAnchor constraintEqualToConstant:22.0],
        [self.selectionView.heightAnchor constraintEqualToConstant:22.0],

        [self.selectionImageView.centerXAnchor constraintEqualToAnchor:self.selectionView.centerXAnchor],
        [self.selectionImageView.centerYAnchor constraintEqualToAnchor:self.selectionView.centerYAnchor],

        [self.disclosureView.centerYAnchor constraintEqualToAnchor:self.selectionView.centerYAnchor],
        [self.disclosureView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-16.0],
        [self.disclosureView.widthAnchor constraintEqualToConstant:13.0],
        [self.disclosureView.heightAnchor constraintEqualToConstant:16.0],

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.iconContainerView.bottomAnchor constant:12.0],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:kPPPaymentCellInnerInset],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-kPPPaymentCellInnerInset],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:3.0],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],

        [self.brandStack.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:kPPPaymentCellInnerInset],
        [self.brandStack.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor constant:-15.0],
        [self.brandStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.statusLabel.leadingAnchor constant:-8.0],

        [self.statusLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.surfaceView.leadingAnchor constant:kPPPaymentCellInnerInset],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:self.surfaceView.bottomAnchor constant:-15.0],
        [self.statusLabel.heightAnchor constraintEqualToConstant:21.0],
        [self.statusLabel.widthAnchor constraintGreaterThanOrEqualToConstant:58.0],
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
    self.iconView.tintColor = accentColor;
    self.titleLabel.text = kLang(method.displayName);
    self.subtitleLabel.text = [self pp_subtitleForInstrument:instrument method:method];
    self.statusLabel.text = [self pp_statusTextForSelection:instrument.isDefault];
    self.statusLabel.textColor = instrument.isDefault ? UIColor.whiteColor : accentColor;

    BOOL isQIBMethod = (method.type == PaymentMethodTypeQIB || [method.methodID.lowercaseString isEqualToString:@"qib"]);
    [self pp_configureBrandRowForQIB:isQIBMethod];

    //BOOL isBuiltIn = [instrument.instrumentID hasPrefix:@"builtin_"];
    [self pp_updateStatusTrailingForMenuVisible:NO];//  [self pp_updateStatusTrailingForMenuVisible:!isBuiltIn];
    self.disclosureView.hidden = YES;
    self.selectionView.hidden = NO;
 
    [self pp_applyDashedBorderVisible:NO];
    [self updateSelectionState:instrument.isDefault animated:NO];
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
    self.statusLabel.textColor = accentColor;
    self.titleLabel.text = kLang(@"payment_add_method");
    self.subtitleLabel.text = kLang(@"payment_add_method_subtitle");
    self.brandStack.hidden = YES;
 
    [self pp_updateStatusTrailingForMenuVisible:NO];
    self.selectionView.hidden = YES;
    self.disclosureView.image = [self pp_disclosureImage];
    self.disclosureView.hidden = NO;

   
    [self pp_applyDashedBorderVisible:YES];
    [self updateSelectionState:NO animated:NO];
    [self pp_updateAccessibilityText];
}

- (void)updateSelectionState:(BOOL)isSelected animated:(BOOL)animated
{
    self.currentSelectionState = isSelected;

    if (!self.addNewStyle && !self.instrument && !self.method) {
        self.statusLabel.text = @"";
        self.selectionView.hidden = NO;
        [self pp_applyMethodVisualsWithAccentColor:(AppPrimaryClr ?: UIColor.systemBlueColor) selected:NO addNew:NO];
        return;
    }

    UIColor *accentColor = self.addNewStyle ? (AppPrimaryClr ?: UIColor.systemBlueColor) : [self pp_accentColorForMethod:self.method];
    void (^changes)(void) = ^{
        [self pp_applyMethodVisualsWithAccentColor:accentColor selected:isSelected addNew:self.addNewStyle];
        self.statusLabel.text = [self pp_statusTextForSelection:isSelected];
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
    if (animated) {
        [UIView animateWithDuration:0.20
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            changes();
            self.surfaceView.transform = isSelected ? CGAffineTransformMakeScale(0.985, 0.985) : CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.18
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                self.surfaceView.transform = CGAffineTransformIdentity;
            } completion:nil];
        }];
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

    self.iconContainerView.backgroundColor = addNew
    ? [safeAccent colorWithAlphaComponent:0.12]
    : [safeAccent colorWithAlphaComponent:isSelected ? 0.16 : 0.10];

    self.selectionView.backgroundColor = isSelected ? safeAccent : UIColor.clearColor;
    [self.selectionView pp_setBorderColor:isSelected ? safeAccent : [UIColor.separatorColor colorWithAlphaComponent:0.32]];

    self.statusLabel.backgroundColor = isSelected
    ? safeAccent
    : [safeAccent colorWithAlphaComponent:addNew ? 0.12 : 0.10];

    self.layer.shadowOpacity = isSelected ? 0.10 : 0.06;
    self.layer.shadowRadius = isSelected ? 22.0 : 18.0;
}

- (void)pp_updateStatusTrailingForMenuVisible:(BOOL)isMenuVisible
{
    self.statusTrailingToMenuConstraint.active = isMenuVisible;
    self.statusTrailingToSurfaceConstraint.active = !isMenuVisible;
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
        return [safeAccent colorWithAlphaComponent:0.42];
    }
    return [UIColor.separatorColor colorWithAlphaComponent:0.16];
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



- (void)pp_configureBrandRowForQIB:(BOOL)isVisible
{
    self.brandStack.hidden = !isVisible;
    if (!isVisible) {
        for (UIImageView *brandView in self.brandImageViews) {
            brandView.hidden = YES;
            brandView.image = nil;
        }
        return;
    }

    NSArray<NSString *> *brandNames = [self pp_qibBrandImageNames];
    NSInteger index = 0;
    for (UIImageView *brandView in self.brandImageViews) {
        if (index < (NSInteger)brandNames.count) {
            brandView.image = [UIImage imageNamed:brandNames[index]];
            brandView.hidden = NO;
        } else {
            brandView.hidden = YES;
            brandView.image = nil;
        }
        index++;
    }
}

- (NSArray<NSString *> *)pp_qibBrandImageNames
{
    NSArray<NSString *> *candidates = @[@"master", @"visa", @"credit-card", @"card2", @"card1"];
    NSMutableArray<NSString *> *resolved = [NSMutableArray array];
    for (NSString *name in candidates) {
        if ([UIImage imageNamed:name] != nil) {
            [resolved addObject:name];
        }
        if (resolved.count == 3) {
            break;
        }
    }
    return resolved;
}

- (UIImage *)pp_iconForMethod:(PaymentMethod *)method
{
    UIImage *assetImage = method.iconName.length > 0 ? [UIImage imageNamed:method.iconName] : nil;
    if (assetImage) {
        return [assetImage imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    }

    NSString *normalizedMethodID = method.methodID.lowercaseString ?: @"";
    NSString *symbolName = @"card2";
    if ([normalizedMethodID isEqualToString:@"cash"] || method.type == PaymentMethodTypeCash) {
        symbolName = @"shippingbox.fill";
    }
    else if ([normalizedMethodID isEqualToString:@"applepay"] || method.type == PaymentMethodTypeApplePay) {
        symbolName = @"appleLogo";
    }else if ([normalizedMethodID isEqualToString:@"qib"]) {
        symbolName = @"lock.shield.fill";
    }

    UIImageSymbolConfiguration *configuration =
    [UIImageSymbolConfiguration configurationWithPointSize:19.0
                                                    weight:UIImageSymbolWeightSemibold
                                                     scale:UIImageSymbolScaleMedium];
    return [[UIImage systemImageNamed:symbolName] imageByApplyingSymbolConfiguration:configuration];
}

- (UIColor *)pp_accentColorForMethod:(PaymentMethod *)method
{
    NSString *normalizedMethodID = method.methodID.lowercaseString ?: @"";
    if ([normalizedMethodID isEqualToString:@"cash"] || method.type == PaymentMethodTypeCash) {
        return UIColor.systemGreenColor;
    }
    return AppPrimaryClr ?: UIColor.systemBlueColor;
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
    if ([self.instrument.instrumentID hasPrefix:@"builtin_"]) {
        return kLang(@"payment_method_builtin_badge");
    }
    return kLang(@"payment_method_saved_badge");
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
    if (self.statusLabel.text.length > 0) {
        [parts addObject:self.statusLabel.text];
    }
    self.accessibilityLabel = [parts componentsJoinedByString:@", "];
}

@end
