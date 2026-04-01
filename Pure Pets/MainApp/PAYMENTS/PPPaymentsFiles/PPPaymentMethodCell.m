//
//  PPPaymentMethodCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 03/02/2026.
//

#import "PPPaymentMethodCell.h"
@interface PPPaymentMethodCell ()

@property (nonatomic, strong) UIButton *glassButton;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UIImageView *bgImage;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIStackView *qibBrandStack;
@property (nonatomic, strong) NSArray<UIImageView *> *qibBrandImageViews;
@property (nonatomic, strong) UITapGestureRecognizer *tap;
@end

@implementation PPPaymentMethodCell


#pragma mark - Reuse Handling

- (void)prepareForReuse {
    [super prepareForReuse];
    
    // Reset image & text
    self.bgImage.image = nil;
    self.iconView.image = nil;
    self.titleLabel.text = @"";
    self.subtitleLabel.text = @"";
    self.iconView.hidden = NO;
    self.titleLabel.hidden = NO;
    self.subtitleLabel.hidden = NO;
    self.qibBrandStack.hidden = YES;
    for (UIImageView *brandView in self.qibBrandImageViews) {
        brandView.image = nil;
        brandView.hidden = YES;
    }
    [self.glassButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    
   
    // Reset config if needed
    if (@available(iOS 18.0, *)) {
        UIButtonConfiguration *cfg = self.glassButton.configuration;
        cfg.image = nil;
        cfg.attributedTitle = nil;
        [self.glassButton setConfiguration:cfg];
        [self.glassButton updateConfiguration];
    }
    [self updateSelectionState:NO animated:NO];
    
    // Remove old actions
    

    // Rebind menu and default tap
    [self setupMenu];
    
    // Reset state
    self.instrument = nil;
    self.method = nil;
    
    
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupUI];
    }
    return self;
}
- (void)setupMenu
{
#pragma mark - Setup UI
    UIMenu *menu = [UIMenu menuWithTitle:@"" children:@[
        [UIAction actionWithTitle:kLang(@"edit")
                            image:[UIImage systemImageNamed:@"pencil"]
                       identifier:nil
                          handler:^(__kindof UIAction * _Nonnull action) {
            if ([self.delegate respondsToSelector:@selector(paymentMethodCellDidRequestEdit:instrument:method:)])
                [self.delegate paymentMethodCellDidRequestEdit:self instrument:self.instrument method:self.method];
        }],
        [UIAction actionWithTitle:kLang(@"Delete")
                            image:[UIImage systemImageNamed:@"trash"]
                       identifier:nil
                          handler:^(__kindof UIAction * _Nonnull action) {
            if ([self.delegate respondsToSelector:@selector(paymentMethodCellDidRequestDelete:instrument:method:)])
                [self.delegate paymentMethodCellDidRequestDelete:self instrument:self.instrument method:self.method];
        }],
        [UIAction actionWithTitle:kLang(@"DefaultMethodLabel")
                            image:[UIImage systemImageNamed:@"checkmark.circle"]
                       identifier:nil
                          handler:^(__kindof UIAction * _Nonnull action) {
            if ([self.delegate respondsToSelector:@selector(paymentMethodCellDidRequestDefault:instrument:method:)])
                [self.delegate paymentMethodCellDidRequestDefault:self instrument:self.instrument method:self.method];
        }]
    ]];
    
    self.glassButton.menu = menu;
    self.glassButton.showsMenuAsPrimaryAction = NO;
    
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

- (void)pp_configureQIBBrandImages
{
    NSArray<NSString *> *brandNames = [self pp_qibBrandImageNames];
    NSInteger index = 0;
    for (UIImageView *brandView in self.qibBrandImageViews) {
        if (index < (NSInteger)brandNames.count) {
            brandView.image = [UIImage imageNamed:brandNames[index]];
            brandView.hidden = NO;
        } else {
            brandView.image = nil;
            brandView.hidden = YES;
        }
        index++;
    }
}

- (void)pp_setQIBBrandRowVisible:(BOOL)visible
{
    self.qibBrandStack.hidden = !visible;
    self.iconView.hidden = visible;
}

#pragma mark - Selection State Handling

- (void)updateSelectionState:(BOOL)isSelected animated:(BOOL)animated {
    _defaultSelected = isSelected;
    self.checkmarkView.hidden = !isSelected;
    
    UIButtonConfiguration *config = self.glassButton.configuration;
    if (!config) return;
    
    // 🎨 Update background and border to indicate default selection
    if (isSelected) {
        config.background.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.15];
        config.background.strokeColor = AppPrimaryClr;
        config.baseForegroundColor = AppPrimaryClr;
    } else {
        config.background.backgroundColor = [UIColor systemBackgroundColor];
        config.background.strokeColor = [UIColor clearColor];
        config.baseForegroundColor = UIColor.labelColor;
    }
    
    // Update button instantly
    [self.glassButton setConfiguration:config];
    [self.glassButton updateConfiguration];
    
    if (animated) {
        /*[UIView animateWithDuration:0.25
                              delay:0
             usingSpringWithDamping:0.8
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            self.glassButton.transform = isSelected ? CGAffineTransformMakeScale(0.97, 0.97) : CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.2 animations:^{
                self.glassButton.transform = CGAffineTransformIdentity;
            }];
        }]; */
    }
    
    
}



- (void)setupUI {
    self.layer.cornerRadius = 16;
    self.clipsToBounds = NO;
    self.layer.maskedCorners = NO;
    self.backgroundColor = UIColor.clearColor;
    
    self.bgImage = [[UIImageView alloc] init];
    self.bgImage.translatesAutoresizingMaskIntoConstraints = NO;
    self.bgImage.tintColor = AppPrimaryClr;
    self.bgImage.contentMode = UIViewContentModeScaleAspectFit;
    self.bgImage.alpha = 0.5;
    [self.contentView addSubview:self.bgImage];
    
    // ✅ Selection border
    self.selectionBorder = [CALayer layer];
    self.selectionBorder.borderColor = [AppPrimaryClr colorWithAlphaComponent:0.9].CGColor;
    self.selectionBorder.borderWidth = 0;
    self.selectionBorder.cornerRadius = 16;
    self.selectionBorder.frame = self.contentView.bounds;
    self.selectionBorder.masksToBounds = YES;
    [self.contentView.layer addSublayer:self.selectionBorder];
    
    
    
     
    self.glassButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.glassButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.glassButton.userInteractionEnabled = YES;
    self.glassButton.clipsToBounds = YES;
    [self.contentView addSubview:self.glassButton];

    // 🧊 Create glass-style container button
    if (@available(iOS 18.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration filledButtonConfiguration];
        if (@available(iOS 26.0, *))  cfg = [UIButtonConfiguration glassButtonConfiguration];
        
        cfg.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        cfg.background.cornerRadius = 22;
        self.glassButton.layer.cornerRadius = 22;
        
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(12, 12, 12, 12);
        self.glassButton.configuration = cfg;
        [self.glassButton updateConfiguration];
    } else {
        // 🌫️ Fallback for older iOS (manual blur)
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialLight];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.translatesAutoresizingMaskIntoConstraints = NO;
        blurView.layer.cornerRadius = 16;
        blurView.clipsToBounds = YES;
        blurView.userInteractionEnabled = NO; // Let button handle taps
        [self.contentView insertSubview:blurView belowSubview:self.glassButton];
        
        [NSLayoutConstraint activateConstraints:@[
            [blurView.topAnchor constraintEqualToAnchor:self.glassButton.topAnchor],
            [blurView.bottomAnchor constraintEqualToAnchor:self.glassButton.bottomAnchor],
            [blurView.leadingAnchor constraintEqualToAnchor:self.glassButton.leadingAnchor],
            [blurView.trailingAnchor constraintEqualToAnchor:self.glassButton.trailingAnchor]
        ]];
        
        self.glassButton.layer.cornerRadius = 16;
        self.glassButton.backgroundColor = [UIColor clearColor];
    }
    
    // 🔹 Icon & Labels
    self.iconView = [[UIImageView alloc] init];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.tintColor = AppPrimaryClr;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [GM boldFontWithSize:16];
    self.titleLabel.textColor = UIColor.labelColor;
    
    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [GM MidFontWithSize:13];
    self.subtitleLabel.textColor = UIColor.secondaryLabelColor;
    self.subtitleLabel.numberOfLines = 2;

    NSMutableArray<UIImageView *> *brandViews = [NSMutableArray array];
    for (NSInteger i = 0; i < 3; i++) {
        UIImageView *brandView = [[UIImageView alloc] init];
        brandView.translatesAutoresizingMaskIntoConstraints = NO;
        brandView.contentMode = UIViewContentModeScaleAspectFit;
        brandView.hidden = YES;
        brandView.layer.cornerRadius = 4.0;
        brandView.clipsToBounds = YES;
        [NSLayoutConstraint activateConstraints:@[
            [brandView.widthAnchor constraintEqualToConstant:30.0],
            [brandView.heightAnchor constraintEqualToConstant:20.0]
        ]];
        [brandViews addObject:brandView];
    }
    self.qibBrandImageViews = [brandViews copy];
    self.qibBrandStack = [[UIStackView alloc] initWithArrangedSubviews:self.qibBrandImageViews];
    self.qibBrandStack.axis = UILayoutConstraintAxisHorizontal;
    self.qibBrandStack.spacing = 6.0;
    self.qibBrandStack.alignment = UIStackViewAlignmentCenter;
    self.qibBrandStack.distribution = UIStackViewDistributionEqualSpacing;
    self.qibBrandStack.hidden = YES;
    
    // 🔹 Stack content
    self.contentStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.qibBrandStack, self.iconView, self.titleLabel, self.subtitleLabel]];
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 6;
    self.contentStack.alignment = UIStackViewAlignmentCenter;
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.glassButton addSubview:self.contentStack];
    [self setupMenu];
    // 🔹 Layout
    [NSLayoutConstraint activateConstraints:@[
        [self.bgImage.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.bgImage.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        [self.bgImage.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.bgImage.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        
        
        [self.glassButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.glassButton.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        [self.glassButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.glassButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        
        [self.contentStack.centerXAnchor constraintEqualToAnchor:self.glassButton.centerXAnchor],
        [self.contentStack.centerYAnchor constraintEqualToAnchor:self.glassButton.centerYAnchor],
        [self.contentStack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.glassButton.leadingAnchor constant:8],
        [self.contentStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.glassButton.trailingAnchor constant:-8]
    ]];
    
    self.selectionBorder.frame = self.contentView.bounds;
    
    /* self.defaultBadge = [[UILabel alloc] init];
    self.defaultBadge.text = kLang(@"Default");
    self.defaultBadge.font = [GM boldFontWithSize:11];
    self.defaultBadge.textColor = UIColor.whiteColor;
    self.defaultBadge.backgroundColor = AppPrimaryClr;
    self.defaultBadge.textAlignment = NSTextAlignmentCenter;
    self.defaultBadge.layer.cornerRadius = 8;
    self.defaultBadge.clipsToBounds = YES;
    self.defaultBadge.translatesAutoresizingMaskIntoConstraints = NO;
    self.defaultBadge.hidden = YES;
    [self.glassButton addSubview:self.defaultBadge];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.defaultBadge.topAnchor constraintEqualToAnchor:self.glassButton.topAnchor constant:6],
        [self.defaultBadge.trailingAnchor constraintEqualToAnchor:self.glassButton.trailingAnchor constant:-8],
        [self.defaultBadge.heightAnchor constraintEqualToConstant:16],
        [self.defaultBadge.widthAnchor constraintGreaterThanOrEqualToConstant:46]
    ]];
     // Tap gesture for both “Add New” and selection
     self.tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
     self.tap.cancelsTouchesInView = NO;
     [self.contentView addGestureRecognizer:self.tap];
     #pragma mark - Gesture Actions

     - (void)handleTap:(UITapGestureRecognizer *)gesture {
         if (gesture.state == UIGestureRecognizerStateEnded) {
             [PPFunc triggerLightHaptic];

             if ([self.titleLabel.text containsString:kLang(@"PaymentFormTitle")] ||
                 [self.titleLabel.text containsString:@"Add"]) {
                 [self addNewPaymentsMethod];
             } else {
                 [self toggleSelected];
             }
         }
     }

     - (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
         if (gesture.state == UIGestureRecognizerStateBegan) {
             [PPFunc triggerLightHaptic];
             if (self.glassButton.menu) {
                 [self.glassButton sendActionsForControlEvents:UIControlEventPrimaryActionTriggered];
             }
         }
     }
*/
    
    // ✅ Checkmark (hidden by default)
    self.checkmarkView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.circle.fill"]];
    self.checkmarkView.translatesAutoresizingMaskIntoConstraints = NO;
    self.checkmarkView.tintColor = UIColor.systemMintColor; //[AppPrimaryClr colorWithAlphaComponent:1.3];
    self.checkmarkView.hidden = YES;
    self.checkmarkView.layer.cornerRadius = 11;
    self.checkmarkView.clipsToBounds = YES;
    self.checkmarkView.backgroundColor = AppForgroundColr;
    [self.contentView addSubview:self.checkmarkView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.checkmarkView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.checkmarkView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.checkmarkView.widthAnchor constraintEqualToConstant:22],
        [self.checkmarkView.heightAnchor constraintEqualToConstant:22]
    ]];
    
    self.tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleSelected)];
    self.tap.cancelsTouchesInView = YES;
    [self.glassButton addGestureRecognizer:_tap];
 
}

#pragma mark - Selection / Default State

- (void)toggleSelected {
    NSLog(@"toggleSelected %ld",_indexPath.item);

    // Add-new cell has no bound instrument/method.
    if (!self.instrument || !self.method) {
        NSLog(@"showPaymentSheetFull %ld",_indexPath.item);
        [self.delegate showPaymentSheetFull:NO];
    } else {
        // Let the controller own selection state; avoid local toggling drift.
        [self.delegate paymentMethodCellDidRequestDefault:self instrument:self.instrument method:self.method];
    }
}

- (void)setIsDefault:(BOOL)isDefault {
    _isDefault = isDefault;
    [self updateSelectionState:isDefault animated:NO];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.selectionBorder.frame = self.contentView.bounds;
    
}

/*
 - (void)updateSelectionState:(BOOL)selected animated:(BOOL)animated {
 CGFloat targetAlpha = selected ? 1.0 : 0.0;
 CGFloat borderWidth = selected ? 2.5 : 0.0;
 CGColorRef borderColor = selected ? [AppPrimaryClr colorWithAlphaComponent:0.9].CGColor : UIColor.clearColor.CGColor;
 
 void (^changes)(void) = ^{
 self.checkmarkView.alpha = targetAlpha;
 self.selectionBorder.borderWidth = borderWidth;
 self.selectionBorder.borderColor = borderColor;
 self.selectionBorder.frame = self.contentView.bounds;
 };
 
 if (animated) {
 [UIView animateWithDuration:0.25 animations:^{
 changes();
 }];
 } else {
 changes();
 }
 }
 */

#pragma mark - Configuration

- (void)configureWithInstrument:(UserPaymentInstrument *)instrument method:(PaymentMethod *)method indexPath:(NSIndexPath *)indexPath {
    
    _indexPath = indexPath;
    _isDefault = instrument.isDefault;
    [self updateSelectionState:_isDefault animated:NO];
    
    self.instrument = instrument;
    self.method = method;
    self.bgImage.image = [UIImage imageNamed:method.iconName];
    self.iconView.image = [UIImage imageNamed:method.iconName];
    self.titleLabel.text = kLang(method.displayName);
    self.titleLabel.hidden = NO;
    self.subtitleLabel.hidden = NO;
    
    
    
    self.subtitleLabel.text = method.type == PaymentMethodTypeCash ?  kLang(method.methodDescription) : instrument.maskedDetails;
    BOOL isQIBMethod = (method.type == PaymentMethodTypeQIB || [method.methodID isEqualToString:@"qib"]);
    [self pp_setQIBBrandRowVisible:isQIBMethod];
    if (isQIBMethod) {
        [self pp_configureQIBBrandImages];
    }
    self.titleLabel.font =[GM boldFontWithSize:14];
    UIButtonConfiguration *config = self.glassButton.configuration;
    //config.background.backgroundColor =  [AppForgroundColr colorWithAlphaComponent:1.0];
    //config.background.strokeColor = [AppBackgroundClr colorWithAlphaComponent:0.5];
     
    [self.glassButton setConfiguration:config];
    [self.glassButton updateConfiguration];
    
    self.bgImage.layer.cornerRadius = self.glassButton.layer.cornerRadius;
    self.bgImage.clipsToBounds = YES;
}

- (void)configureAsAddNewIndexPath:(NSIndexPath *)indexPath {
    
    
    if (@available(iOS 18.0, *)) {
        _indexPath = indexPath;
        [self pp_setQIBBrandRowVisible:NO];
        self.iconView.hidden = YES;
        self.titleLabel.hidden = YES;
        self.subtitleLabel.hidden = YES;
        
        UIButtonConfiguration *config = self.glassButton.configuration;
        config.image = [UIImage systemImageNamed:@"plus"];
        config.attributedTitle = [[NSAttributedString alloc] initWithString:kLang(@"PaymentFormTitle") attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:14],
            NSForegroundColorAttributeName: [AppSecondaryTextClr colorWithAlphaComponent:0.9]
        }];
        
        config.contentInsets = NSDirectionalEdgeInsetsMake(12, 12, 12, 12);
        config.imagePlacement =  NSDirectionalRectEdgeTop;
        config.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;
        config.imagePadding =  12.0;
        config.background.backgroundColor = [AppBackgroundClrDarker colorWithAlphaComponent:0.0];
        config.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithPaletteColors:@[AppForgroundColr,AppPrimaryClrShiner]];
        
        [self.glassButton setConfiguration:config];
        [self.glassButton updateConfiguration];
        self.glassButton.menu = nil;

        //[self.glassButton removeTarget:self action:@selector(toggleSelected) forControlEvents:UIControlEventTouchUpInside];
       
            [self.glassButton addTarget:self action:@selector(addNewPaymentsMethod) forControlEvents:UIControlEventTouchUpInside];
         
    }
    else
    {
        [self pp_setQIBBrandRowVisible:NO];
        self.iconView.image = [UIImage systemImageNamed:@"plus.circle.fill"];
        self.iconView.tintColor = AppPrimaryClr;
        self.titleLabel.text = kLang(@"Add New Payment Method");
        self.subtitleLabel.text = @"";
    }
    
}
- (void)addNewPaymentsMethod
{
    NSLog(@"Add New Payment Method");
    [self.delegate showPaymentSheetFull:NO];
}
@end
