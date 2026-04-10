//
//  PPPaymentMethodCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 03/02/2026.
//

#import "PPPaymentMethodCell.h"

@interface PPPaymentMethodCell ()

@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *iconContainerView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIStackView *brandStack;
@property (nonatomic, strong) NSArray<UIImageView *> *brandImageViews;
@property (nonatomic, strong) UIButton *menuButton;
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

    self.titleLabel.text = @"";
    self.subtitleLabel.text = @"";
    self.statusLabel.text = @"";
    self.iconView.image = nil;
    self.menuButton.hidden = YES;
    self.menuButton.menu = nil;
    self.brandStack.hidden = YES;
    self.disclosureView.hidden = YES;
    self.selectionView.hidden = NO;

    for (UIImageView *brandView in self.brandImageViews) {
        brandView.image = nil;
        brandView.hidden = YES;
    }

    [self updateSelectionState:NO animated:NO];
    [self pp_applyDashedBorderVisible:NO];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.surfaceView.frame
                                                          cornerRadius:self.surfaceView.layer.cornerRadius];
    self.layer.shadowPath = shadowPath.CGPath;

    if (!self.dashedBorderLayer.hidden) {
        self.dashedBorderLayer.frame = self.surfaceView.bounds;
        self.dashedBorderLayer.path = [UIBezierPath bezierPathWithRoundedRect:self.surfaceView.bounds
                                                                  cornerRadius:self.surfaceView.layer.cornerRadius].CGPath;
    }
}

#pragma mark - UI

- (void)pp_buildUI
{
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.08;
    self.layer.shadowRadius = 18.0;
    self.layer.shadowOffset = CGSizeMake(0.0, 10.0);

    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.surfaceView.backgroundColor = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
    self.surfaceView.layer.cornerRadius = 26.0;
    self.surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    self.surfaceView.layer.borderWidth = 1.0;
    self.surfaceView.layer.borderColor = [UIColor colorWithWhite:0.0 alpha:0.06].CGColor;
    [self.contentView addSubview:self.surfaceView];

    self.dashedBorderLayer = [CAShapeLayer layer];
    self.dashedBorderLayer.lineWidth = 1.5;
    self.dashedBorderLayer.lineDashPattern = @[@8, @6];
    self.dashedBorderLayer.fillColor = UIColor.clearColor.CGColor;
    self.dashedBorderLayer.hidden = YES;
    [self.surfaceView.layer addSublayer:self.dashedBorderLayer];

    self.iconContainerView = [[UIView alloc] init];
    self.iconContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconContainerView.layer.cornerRadius = 20.0;
    self.iconContainerView.layer.cornerCurve = kCACornerCurveContinuous;
    [self.surfaceView addSubview:self.iconContainerView];

    self.iconView = [[UIImageView alloc] init];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.iconContainerView addSubview:self.iconView];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [GM MidFontWithSize:11.0];
    self.statusLabel.textColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    self.statusLabel.numberOfLines = 1;
    [self.surfaceView addSubview:self.statusLabel];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [GM boldFontWithSize:18.0];
    self.titleLabel.textColor = UIColor.labelColor;
    self.titleLabel.numberOfLines = 1;
    [self.surfaceView addSubview:self.titleLabel];

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [GM MidFontWithSize:13.0];
    self.subtitleLabel.textColor = UIColor.secondaryLabelColor;
    self.subtitleLabel.numberOfLines = 2;
    [self.surfaceView addSubview:self.subtitleLabel];

    NSMutableArray<UIImageView *> *brandViews = [NSMutableArray array];
    for (NSInteger index = 0; index < 3; index++) {
        UIImageView *brandView = [[UIImageView alloc] init];
        brandView.translatesAutoresizingMaskIntoConstraints = NO;
        brandView.contentMode = UIViewContentModeScaleAspectFit;
        brandView.layer.cornerRadius = 5.0;
        brandView.clipsToBounds = YES;
        brandView.hidden = YES;
        [NSLayoutConstraint activateConstraints:@[
            [brandView.widthAnchor constraintEqualToConstant:28.0],
            [brandView.heightAnchor constraintEqualToConstant:18.0],
        ]];
        [brandViews addObject:brandView];
    }
    self.brandImageViews = [brandViews copy];

    self.brandStack = [[UIStackView alloc] initWithArrangedSubviews:self.brandImageViews];
    self.brandStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.brandStack.axis = UILayoutConstraintAxisHorizontal;
    self.brandStack.alignment = UIStackViewAlignmentCenter;
    self.brandStack.spacing = 6.0;
    self.brandStack.hidden = YES;
    [self.surfaceView addSubview:self.brandStack];

    self.menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.menuButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.menuButton.tintColor = UIColor.secondaryLabelColor;
    self.menuButton.hidden = YES;
    self.menuButton.showsMenuAsPrimaryAction = YES;
    self.menuButton.backgroundColor = [AppBackgroundClrDarker ?: UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.4];
    self.menuButton.layer.cornerRadius = 16.0;
    self.menuButton.layer.cornerCurve = kCACornerCurveContinuous;
    [self.menuButton setImage:[UIImage systemImageNamed:@"ellipsis"] forState:UIControlStateNormal];
    [self.surfaceView addSubview:self.menuButton];

    self.selectionView = [[UIView alloc] init];
    self.selectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionView.layer.cornerRadius = 14.0;
    self.selectionView.layer.cornerCurve = kCACornerCurveContinuous;
    self.selectionView.layer.borderWidth = 1.0;
    [self.surfaceView addSubview:self.selectionView];

    self.selectionImageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark"]];
    self.selectionImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionImageView.contentMode = UIViewContentModeCenter;
    [self.selectionView addSubview:self.selectionImageView];

    self.disclosureView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:Language.isRTL ? @"chevron.left" : @"chevron.right"]];
    self.disclosureView.translatesAutoresizingMaskIntoConstraints = NO;
    self.disclosureView.tintColor = UIColor.secondaryLabelColor;
    self.disclosureView.hidden = YES;
    [self.surfaceView addSubview:self.disclosureView];

    self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_didTapCard)];
    [self.surfaceView addGestureRecognizer:self.tapGesture];

    [NSLayoutConstraint activateConstraints:@[
        [self.surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:4.0],
        [self.surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-4.0],
        [self.surfaceView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],

        [self.iconContainerView.leadingAnchor constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:18.0],
        [self.iconContainerView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.iconContainerView.widthAnchor constraintEqualToConstant:40.0],
        [self.iconContainerView.heightAnchor constraintEqualToConstant:40.0],

        [self.iconView.centerXAnchor constraintEqualToAnchor:self.iconContainerView.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:self.iconContainerView.centerYAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:22.0],
        [self.iconView.heightAnchor constraintEqualToConstant:22.0],

        [self.menuButton.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:14.0],
        [self.menuButton.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-14.0],
        [self.menuButton.widthAnchor constraintEqualToConstant:32.0],
        [self.menuButton.heightAnchor constraintEqualToConstant:32.0],

        [self.selectionView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-18.0],
        [self.selectionView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.selectionView.widthAnchor constraintEqualToConstant:28.0],
        [self.selectionView.heightAnchor constraintEqualToConstant:28.0],

        [self.selectionImageView.centerXAnchor constraintEqualToAnchor:self.selectionView.centerXAnchor],
        [self.selectionImageView.centerYAnchor constraintEqualToAnchor:self.selectionView.centerYAnchor],

        [self.disclosureView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-18.0],
        [self.disclosureView.centerYAnchor constraintEqualToAnchor:self.surfaceView.centerYAnchor],
        [self.disclosureView.widthAnchor constraintEqualToConstant:14.0],
        [self.disclosureView.heightAnchor constraintEqualToConstant:18.0],

        [self.statusLabel.topAnchor constraintEqualToAnchor:self.surfaceView.topAnchor constant:18.0],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.iconContainerView.trailingAnchor constant:14.0],
        [self.statusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.menuButton.leadingAnchor constant:-12.0],

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:8.0],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.statusLabel.leadingAnchor],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.selectionView.leadingAnchor constant:-16.0],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4.0],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.statusLabel.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.selectionView.leadingAnchor constant:-16.0],

        [self.brandStack.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:10.0],
        [self.brandStack.leadingAnchor constraintEqualToAnchor:self.statusLabel.leadingAnchor],
        [self.brandStack.bottomAnchor constraintLessThanOrEqualToAnchor:self.surfaceView.bottomAnchor constant:-18.0],
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
    self.iconContainerView.backgroundColor = [accentColor colorWithAlphaComponent:0.12];
    self.iconView.tintColor = accentColor;
    self.iconView.image = [self pp_iconForMethod:method];
    self.titleLabel.text = kLang(method.displayName);
    self.subtitleLabel.text = (method.type == PaymentMethodTypeCash)
        ? kLang(method.methodDescription)
        : (instrument.maskedDetails.length > 0 ? instrument.maskedDetails : kLang(method.methodDescription));

    self.statusLabel.textColor = accentColor;
    self.statusLabel.text = [self pp_statusTextForSelection:instrument.isDefault];

    BOOL isQIBMethod = (method.type == PaymentMethodTypeQIB || [method.methodID isEqualToString:@"qib"]);
    [self pp_configureBrandRowForQIB:isQIBMethod];

    BOOL isBuiltIn = [instrument.instrumentID hasPrefix:@"builtin_"];
    self.menuButton.hidden = isBuiltIn;
    [self pp_applyMenuForEditableInstrument:!isBuiltIn];
    self.disclosureView.hidden = YES;
    self.selectionView.hidden = NO;
    [self pp_applyDashedBorderVisible:NO];

    [self updateSelectionState:instrument.isDefault animated:NO];
}

- (void)configureAsAddNewIndexPath:(NSIndexPath *)indexPath
{
    self.indexPath = indexPath;
    self.instrument = nil;
    self.method = nil;
    self.addNewStyle = YES;

    UIColor *accentColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    self.iconContainerView.backgroundColor = [accentColor colorWithAlphaComponent:0.12];
    self.iconView.tintColor = accentColor;
    self.iconView.image = [UIImage systemImageNamed:@"plus"];
    self.statusLabel.textColor = accentColor;
    self.statusLabel.text = kLang(@"payment_add_method_badge");
    self.titleLabel.text = kLang(@"payment_add_method");
    self.subtitleLabel.text = kLang(@"payment_add_method_subtitle");
    self.menuButton.hidden = YES;
    self.brandStack.hidden = YES;
    self.selectionView.hidden = YES;
    self.disclosureView.hidden = NO;
    self.surfaceView.backgroundColor = [AppForgroundColr ?: UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.9];
    [self pp_applyMenuForEditableInstrument:NO];
    [self pp_applyDashedBorderVisible:YES];
    [self updateSelectionState:NO animated:NO];
}

- (void)updateSelectionState:(BOOL)isSelected animated:(BOOL)animated
{
    self.currentSelectionState = isSelected;
    if (self.addNewStyle) {
        self.surfaceView.layer.borderColor = [UIColor colorWithWhite:0.0 alpha:0.05].CGColor;
        self.selectionView.hidden = YES;
        return;
    }

    UIColor *accentColor = [self pp_accentColorForMethod:self.method];
    void (^changes)(void) = ^{
        self.selectionView.backgroundColor = isSelected ? accentColor : UIColor.clearColor;
        self.selectionView.layer.borderColor = (isSelected ? accentColor : [UIColor colorWithWhite:0.0 alpha:0.12]).CGColor;
        self.selectionImageView.tintColor = isSelected ? AppForgroundColr : UIColor.clearColor;
        self.surfaceView.layer.borderColor = (isSelected ? [accentColor colorWithAlphaComponent:0.45] : [UIColor colorWithWhite:0.0 alpha:0.06]).CGColor;
        self.surfaceView.backgroundColor = isSelected
            ? [accentColor colorWithAlphaComponent:0.08]
            : (AppForgroundColr ?: UIColor.secondarySystemBackgroundColor);
        self.statusLabel.text = [self pp_statusTextForSelection:isSelected];
    };

    if (animated) {
        [UIView animateWithDuration:0.22
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            changes();
            self.surfaceView.transform = isSelected ? CGAffineTransformMakeScale(0.985, 0.985) : CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.16 animations:^{
                self.surfaceView.transform = CGAffineTransformIdentity;
            }];
        }];
    } else {
        changes();
        self.surfaceView.transform = CGAffineTransformIdentity;
    }
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

- (void)pp_applyMenuForEditableInstrument:(BOOL)editable
{
    if (!editable || !self.instrument || !self.method) {
        self.menuButton.menu = nil;
        return;
    }

    __weak typeof(self) weakSelf = self;
    UIAction *editAction = [UIAction actionWithTitle:kLang(@"edit")
                                               image:[UIImage systemImageNamed:@"pencil"]
                                          identifier:nil
                                             handler:^(__kindof UIAction * _Nonnull action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if ([strongSelf.delegate respondsToSelector:@selector(paymentMethodCellDidRequestEdit:instrument:method:)]) {
            [strongSelf.delegate paymentMethodCellDidRequestEdit:strongSelf instrument:strongSelf.instrument method:strongSelf.method];
        }
    }];

    UIAction *defaultAction = [UIAction actionWithTitle:kLang(@"DefaultMethodLabel")
                                                  image:[UIImage systemImageNamed:@"checkmark.circle"]
                                             identifier:nil
                                                handler:^(__kindof UIAction * _Nonnull action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if ([strongSelf.delegate respondsToSelector:@selector(paymentMethodCellDidRequestDefault:instrument:method:)]) {
            [strongSelf.delegate paymentMethodCellDidRequestDefault:strongSelf instrument:strongSelf.instrument method:strongSelf.method];
        }
    }];

    UIAction *deleteAction = [UIAction actionWithTitle:kLang(@"Delete")
                                                 image:[UIImage systemImageNamed:@"trash"]
                                            identifier:nil
                                               handler:^(__kindof UIAction * _Nonnull action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if ([strongSelf.delegate respondsToSelector:@selector(paymentMethodCellDidRequestDelete:instrument:method:)]) {
            [strongSelf.delegate paymentMethodCellDidRequestDelete:strongSelf instrument:strongSelf.instrument method:strongSelf.method];
        }
    }];
    deleteAction.attributes = UIMenuElementAttributesDestructive;

    self.menuButton.menu = [UIMenu menuWithTitle:@"" children:@[editAction, defaultAction, deleteAction]];
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
        return assetImage;
    }

    NSString *normalizedMethodID = method.methodID.lowercaseString ?: @"";
    NSString *symbolName = @"creditcard.fill";
    if ([normalizedMethodID isEqualToString:@"cash"] || method.type == PaymentMethodTypeCash) {
        symbolName = @"shippingbox.fill";
    } else if ([normalizedMethodID isEqualToString:@"qib"]) {
        symbolName = @"lock.shield.fill";
    }
    return [UIImage systemImageNamed:symbolName];
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

    UIColor *dashColor = [AppPrimaryClr ?: UIColor.systemBlueColor colorWithAlphaComponent:0.3];
    self.dashedBorderLayer.strokeColor = dashColor.CGColor;
    self.dashedBorderLayer.frame = self.surfaceView.bounds;
    self.dashedBorderLayer.path = [UIBezierPath bezierPathWithRoundedRect:self.surfaceView.bounds
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

@end
