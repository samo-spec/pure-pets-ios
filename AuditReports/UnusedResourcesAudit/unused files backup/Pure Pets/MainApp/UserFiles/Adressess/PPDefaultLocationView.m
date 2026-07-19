#import "PPDefaultLocationView.h"

static CGFloat const kViewHeight = 60.0;

@interface PPDefaultLocationView ()
@property (nonatomic, strong) UIImageView *deliverIcon;
@property (nonatomic, strong) UIButton *changeButton;
@property (nonatomic, strong, readwrite) PPInsetLabel *locationLabel;
@property (nonatomic, strong) UIStackView *locationStack;
@property (nonatomic, strong) UIStackView *userStack;
@property (nonatomic, strong) UIView *separator;
@property (nonatomic, strong) UIImageView *pinIcon;

@property (nonatomic, strong) NSLayoutConstraint *collapsedWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *collapsedHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *expandedHeightConstraint;


@end

@implementation PPDefaultLocationView

#pragma mark - Init

#pragma mark - Public
- (void)setLocationText:(NSString *)text {
    self.locationLabel.text = text ?: @"";
}


- (instancetype)initWithPPLocatioViewKind:(PPLocatioViewKind)kind
                                    width:(CGFloat)width
                            ChangeHandler:(PPDefaultLocationChangeBlock)onChange
{
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.locatioViewKind = kind;
    self.viewWidth = width;
    self.onChangeTapped = onChange;
    self.isExpanded = YES;

    [self setupView];
    [self setExpanded:NO];

    if (kind == PPLocatioViewKindLocation) {
        [self addTarget:self
                 action:@selector(toggleExpandCollapse)
       forControlEvents:UIControlEventTouchUpInside];
    }

    return self;
}

#pragma mark - Setup

- (void)setupView
{
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(12, 12, 12, 12);
        cfg.background.cornerRadius = 28;
        self.configuration = cfg;
    } else {
        self.layer.cornerRadius = 22;
        [self pp_setShadowColor:[AppShadowClr colorWithAlphaComponent:0.4]];
        self.layer.shadowOpacity = 0.12;
        self.layer.shadowOffset = CGSizeMake(0, 2);
        self.layer.shadowRadius = 8;

        UIVisualEffectView *blur =
        [[UIVisualEffectView alloc] initWithEffect:
         [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
        blur.translatesAutoresizingMaskIntoConstraints = NO;
        blur.userInteractionEnabled = NO;
        blur.layer.cornerRadius = 22;
        blur.clipsToBounds = YES;
        [self insertSubview:blur atIndex:0];

        [NSLayoutConstraint activateConstraints:@[
            [blur.topAnchor constraintEqualToAnchor:self.topAnchor],
            [blur.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [blur.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [blur.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        ]];
    }

    [self buildContent];
    
    
    self.collapsedWidthConstraint =
        [self.widthAnchor constraintEqualToConstant:48];

    self.collapsedHeightConstraint =
        [self.heightAnchor constraintEqualToConstant:48];

    self.expandedHeightConstraint =
        [self.heightAnchor constraintEqualToConstant:kViewHeight];

    self.expandedHeightConstraint.active = YES;
}

#pragma mark - Content

- (void)handleLocationStackTap
{
    // Only expand on stack tap
     
        [GM triggerHapticFeedback];
        [self setExpanded:!self.isExpanded];
    
}

- (void)buildContent
{
    // Icon
    self.deliverIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"fast-delivery"]];
    self.deliverIcon.translatesAutoresizingMaskIntoConstraints = NO;
    self.deliverIcon.tintColor = UIColor.systemGrayColor;
    [self.deliverIcon.widthAnchor constraintEqualToConstant:40].active = YES;
    [self.deliverIcon.heightAnchor constraintEqualToConstant:40].active = YES;
    self.deliverIcon.userInteractionEnabled = YES;

    UITapGestureRecognizer *tapdeliverIcon = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleExpandCollapse)];
    [self.deliverIcon addGestureRecognizer:tapdeliverIcon];
    // Label
    self.locationLabel = [[PPInsetLabel alloc] init];
    self.locationLabel.font = [GM MidFontWithSize:15];
    self.locationLabel.textColor = UIColor.labelColor;
    self.locationLabel.numberOfLines = 2;
    self.locationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationLabel.preferredMaxLayoutWidth = UIScreen.mainScreen.bounds.size.width - 120;
    self.locationLabel.userInteractionEnabled = YES;
    
   
    
    
    // Button
    self.changeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.changeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.changeButton addTarget:self
                          action:@selector(handleChangeTap)
                forControlEvents:UIControlEventTouchUpInside];
    [self.changeButton.widthAnchor constraintEqualToConstant:48].active = YES;
    [self.changeButton.heightAnchor constraintEqualToConstant:48].active = YES;

    // Stack
    self.locationStack =
    [[UIStackView alloc] initWithArrangedSubviews:@[
        self.deliverIcon,
        self.locationLabel,
        self.changeButton
    ]];
    self.locationStack.axis = UILayoutConstraintAxisHorizontal;
    self.locationStack.spacing = 12;
    self.locationStack.alignment = UIStackViewAlignmentCenter;
    self.locationStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationStack.userInteractionEnabled = YES;
    [self addSubview:self.locationStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.locationStack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.locationStack.leadingAnchor constraintEqualToAnchor:self.layoutMarginsGuide.leadingAnchor constant:12],
        [self.locationStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.layoutMarginsGuide.trailingAnchor],
    ]];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleExpandCollapse)];
    [self.locationStack addGestureRecognizer:tap];
    [self updateLocationUI];
}

#pragma mark - Expand / Collapse
- (void)setExpanded:(BOOL)expanded
{
    if (_isExpanded == expanded) return;
    _isExpanded = expanded;

    // Configuration
    UIButtonConfiguration *cfg = self.configuration;

    if (expanded) {
        cfg.image = nil;
        cfg.title = nil;
    } else {
        cfg.image = [UIImage imageNamed:@"fast-delivery"];
        cfg.imagePadding = 0;
        cfg.title = nil;
    }

    cfg.baseForegroundColor = AppPrimaryClr;
    self.configuration = cfg;

    // ---- Layout authority switch ----
    self.locationStack.hidden = !expanded;

    self.collapsedWidthConstraint.active  = !expanded;
    self.collapsedHeightConstraint.active = !expanded;
    self.expandedHeightConstraint.active  = expanded;

    // Corner radius must match final size
    CGFloat targetRadius = expanded ? 22.0 : 24.0;

    // ---- Animate ONLY visuals ----
    [UIView animateWithDuration:0.3
                          delay:0
         usingSpringWithDamping:0.9
          initialSpringVelocity:0.3
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self.locationStack.alpha = expanded ? 1.0 : 0.0;
        self.locationStack.transform =
            expanded ? CGAffineTransformIdentity
                     : CGAffineTransformMakeScale(0.85, 0.85);

        self.layer.cornerRadius = targetRadius;
        [self.superview layoutIfNeeded];
    } completion:nil];
}

- (void)toggleExpandCollapse
{
    [GM triggerHapticFeedback];
    [self setExpanded:!self.isExpanded];
}

#pragma mark - UI Updates

- (void)setAddresses:(NSMutableArray<PPAddressModel *> *)addresses
{
    _addresses = addresses;
    [self updateLocationUI];
}

- (void)updateLocationUI
{
    NSString *title;
    NSString *icon;

    if (self.addresses.count > 0) {
        title = [NSString stringWithFormat:@"%@: %@",
                 kLang(@"DeliverTo"),
                 self.addresses.firstObject.displayName ?: @""];
        icon = @"pencil.and.outline";
    } else {
        title = kLang(@"No delivery addresses available");
        icon = @"plus.circle";
    }

    [self.locationLabel setLineSpacing:4.0 text:title];

    [self.changeButton setImage:
     [UIImage pp_symbolNamed:icon
                   pointSize:20
                      weight:UIImageSymbolWeightMedium
                       scale:UIImageSymbolScaleLarge
                     palette:@[UIColor.grayColor,AppPrimaryClr]
                 makeTemplate:YES]
                         forState:UIControlStateNormal];
}

#pragma mark - Actions

- (void)handleChangeTap
{
    if (self.addresses.count > 0) {
        if (self.onChangeTapped) self.onChangeTapped();
    } else {
        [self openAddressFormForNew];
    }
}

-(void)openAddressFormForNew
{
    AddressFormVC *vc = [[AddressFormVC alloc] init];
    vc.delegate = self;
    vc.view.backgroundColor = PPIOS26() ? AppClearClr : AppBackgroundClr;
    vc.tableView.backgroundColor = PPIOS26() ? AppClearClr : AppBackgroundClr;
    vc.addressFormPresent = AddressFormPresentSheet;
    
    PPNavigationController *nav = [[PPNavigationController alloc] initWithRootViewController:vc];
    [PPFunc presentSheetFrom:AppMgr.topViewController sheetVC:nav detentStyle:PPSheetDetentStyle70];
}

-(void)addressFormVC:(AddressFormVC *)controller didSaveAddress:(PPAddressModel *)address
{
    [PPADDRESS getAllAddressesWithCompletion:^(NSArray<PPAddressModel *> * _Nonnull addresses, NSError * _Nullable error) {
        NSLog(@"This executes getAllAddressesWithCompletion seconds %@",
              addresses);
        self.addresses = [addresses mutableCopy];
        //[self.locView buildContent];
    }];
}

-(void)addressFormVC:(AddressFormVC *)controller didDeleteAddress:(PPAddressModel *)address
{
    
    [PPADDRESS getAllAddressesWithCompletion:^(NSArray<PPAddressModel *> * _Nonnull addresses, NSError * _Nullable error) {
        NSLog(@"This executes getAllAddressesWithCompletion seconds %@",
              addresses);
        self.addresses = [addresses mutableCopy];
        //[self.locView buildContent];
    }];
}



#pragma mark - Intrinsic Size
- (CGSize)intrinsicContentSize
{
    if (!self.isExpanded) {
        // Collapsed pill = icon-only width
        return CGSizeMake(48, 48);
    }

    return CGSizeMake(UIViewNoIntrinsicMetric, kViewHeight);
}
 

@end
