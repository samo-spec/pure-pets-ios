//
//  PPCartBranchBannerView.m
//  Pure Pets
//
//  Apple-grade, real-time fulfillment branch change notice banner for CartViewController.
//

#import "PPCartBranchBannerView.h"
#import "Language.h"

@interface PPCartBranchBannerView ()

@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIImageView *storeIconView;
@property (nonatomic, strong) UILabel *storeBadgeLabel;
@property (nonatomic, strong) UIView *storeBadgeView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIStackView *actionStackView;
@property (nonatomic, strong) UIButton *removeUnavailableButton;
@property (nonatomic, strong) UIButton *saveUnavailableButton;
@property (nonatomic, strong) UIButton *dismissButton;

@property (nonatomic, copy) NSString *currentBranchName;
@property (nonatomic, assign) NSInteger currentOutOfStockCount;
@property (nonatomic, assign) NSInteger currentClampedCount;

@end

@implementation PPCartBranchBannerView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self pp_setupUI];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self pp_setupUI];
    }
    return self;
}

- (void)pp_setupUI {
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = YES;
    
    // Outer card container
    _containerView = [[UIView alloc] init];
    _containerView.translatesAutoresizingMaskIntoConstraints = NO;
    _containerView.layer.cornerRadius = 18.0;
    _containerView.layer.cornerCurve = kCACornerCurveContinuous;
    _containerView.layer.borderWidth = 1.0;
    _containerView.layer.borderColor = [UIColor.systemGray4Color colorWithAlphaComponent:0.4].CGColor;
    _containerView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) {
        return trait.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0.14 green:0.14 blue:0.16 alpha:0.95]
            : [UIColor colorWithRed:0.98 green:0.98 blue:0.99 alpha:0.98];
    }];
    
    // Add subtle shadow
    _containerView.layer.shadowColor = UIColor.blackColor.CGColor;
    _containerView.layer.shadowOpacity = 0.06;
    _containerView.layer.shadowOffset = CGSizeMake(0, 3);
    _containerView.layer.shadowRadius = 8.0;
    
    [self addSubview:_containerView];
    
    // Store badge (pill)
    _storeBadgeView = [[UIView alloc] init];
    _storeBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    _storeBadgeView.layer.cornerRadius = 12.0;
    _storeBadgeView.layer.cornerCurve = kCACornerCurveContinuous;
    _storeBadgeView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.12];
    [_containerView addSubview:_storeBadgeView];
    
    _storeIconView = [[UIImageView alloc] init];
    _storeIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _storeIconView.contentMode = UIViewContentModeScaleAspectFit;
    _storeIconView.tintColor = AppPrimaryClr;
    if (@available(iOS 13.0, *)) {
        _storeIconView.image = [UIImage systemImageNamed:@"building.2.crop.circle.fill"];
    }
    [_storeBadgeView addSubview:_storeIconView];
    
    _storeBadgeLabel = [[UILabel alloc] init];
    _storeBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _storeBadgeLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    _storeBadgeLabel.textColor = AppPrimaryClr;
    [_storeBadgeView addSubview:_storeBadgeLabel];
    
    // Dismiss button
    _dismissButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _dismissButton.translatesAutoresizingMaskIntoConstraints = NO;
    _dismissButton.tintColor = UIColor.tertiaryLabelColor;
    if (@available(iOS 13.0, *)) {
        [_dismissButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    } else {
        [_dismissButton setTitle:@"✕" forState:UIControlStateNormal];
    }
    [_dismissButton addTarget:self action:@selector(pp_dismissTapped) forControlEvents:UIControlEventTouchUpInside];
    [_containerView addSubview:_dismissButton];
    
    // Title
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    _titleLabel.textColor = UIColor.labelColor;
    _titleLabel.numberOfLines = 1;
    [_containerView addSubview:_titleLabel];
    
    // Subtitle
    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    _subtitleLabel.textColor = UIColor.secondaryLabelColor;
    _subtitleLabel.numberOfLines = 0;
    [_containerView addSubview:_subtitleLabel];
    
    // Actions stack
    _actionStackView = [[UIStackView alloc] init];
    _actionStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _actionStackView.axis = UILayoutConstraintAxisHorizontal;
    _actionStackView.spacing = 8.0;
    _actionStackView.distribution = UIStackViewDistributionFillProportionally;
    _actionStackView.alignment = UIStackViewAlignmentCenter;
    [_containerView addSubview:_actionStackView];
    
    // Remove Unavailable Button
    _removeUnavailableButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _removeUnavailableButton.translatesAutoresizingMaskIntoConstraints = NO;
    _removeUnavailableButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    _removeUnavailableButton.backgroundColor = [UIColor.systemRedColor colorWithAlphaComponent:0.12];
    [_removeUnavailableButton setTitleColor:UIColor.systemRedColor forState:UIControlStateNormal];
    _removeUnavailableButton.layer.cornerRadius = 10.0;
    _removeUnavailableButton.layer.cornerCurve = kCACornerCurveContinuous;
    _removeUnavailableButton.contentEdgeInsets = UIEdgeInsetsMake(8, 12, 8, 12);
    [_removeUnavailableButton addTarget:self action:@selector(pp_removeUnavailableTapped) forControlEvents:UIControlEventTouchUpInside];
    [_actionStackView addArrangedSubview:_removeUnavailableButton];
    
    // Save For Later Button
    _saveUnavailableButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _saveUnavailableButton.translatesAutoresizingMaskIntoConstraints = NO;
    _saveUnavailableButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    _saveUnavailableButton.backgroundColor = [UIColor.systemGray5Color colorWithAlphaComponent:0.5];
    [_saveUnavailableButton setTitleColor:UIColor.secondaryLabelColor forState:UIControlStateNormal];
    _saveUnavailableButton.layer.cornerRadius = 10.0;
    _saveUnavailableButton.layer.cornerCurve = kCACornerCurveContinuous;
    _saveUnavailableButton.contentEdgeInsets = UIEdgeInsetsMake(8, 12, 8, 12);
    [_saveUnavailableButton addTarget:self action:@selector(pp_saveUnavailableTapped) forControlEvents:UIControlEventTouchUpInside];
    [_actionStackView addArrangedSubview:_saveUnavailableButton];
    
    // Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        [_containerView.topAnchor constraintEqualToAnchor:self.topAnchor constant:4.0],
        [_containerView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16.0],
        [_containerView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16.0],
        [_containerView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-8.0],
        
        [_storeBadgeView.topAnchor constraintEqualToAnchor:_containerView.topAnchor constant:12.0],
        [_storeBadgeView.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor constant:14.0],
        [_storeBadgeView.heightAnchor constraintEqualToConstant:26.0],
        
        [_storeIconView.leadingAnchor constraintEqualToAnchor:_storeBadgeView.leadingAnchor constant:8.0],
        [_storeIconView.centerYAnchor constraintEqualToAnchor:_storeBadgeView.centerYAnchor constant:0.0],
        [_storeIconView.widthAnchor constraintEqualToConstant:16.0],
        [_storeIconView.heightAnchor constraintEqualToConstant:16.0],
        
        [_storeBadgeLabel.leadingAnchor constraintEqualToAnchor:_storeIconView.trailingAnchor constant:6.0],
        [_storeBadgeLabel.trailingAnchor constraintEqualToAnchor:_storeBadgeView.trailingAnchor constant:-10.0],
        [_storeBadgeLabel.centerYAnchor constraintEqualToAnchor:_storeBadgeView.centerYAnchor constant:0.0],
        
        [_dismissButton.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor constant:-10.0],
        [_dismissButton.centerYAnchor constraintEqualToAnchor:_storeBadgeView.centerYAnchor constant:0.0],
        [_dismissButton.widthAnchor constraintEqualToConstant:28.0],
        [_dismissButton.heightAnchor constraintEqualToConstant:28.0],
        
        [_titleLabel.topAnchor constraintEqualToAnchor:_storeBadgeView.bottomAnchor constant:10.0],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor constant:14.0],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor constant:-14.0],
        
        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4.0],
        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor constant:14.0],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor constant:-14.0],
        
        [_actionStackView.topAnchor constraintEqualToAnchor:_subtitleLabel.bottomAnchor constant:10.0],
        [_actionStackView.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor constant:14.0],
        [_actionStackView.trailingAnchor constraintLessThanOrEqualToAnchor:_containerView.trailingAnchor constant:-14.0],
        [_actionStackView.bottomAnchor constraintEqualToAnchor:_containerView.bottomAnchor constant:-12.0],
        [_actionStackView.heightAnchor constraintEqualToConstant:32.0]
    ]];
}

- (void)configureWithBranchName:(NSString *)branchName
                outOfStockCount:(NSInteger)outOfStockCount
                   clampedCount:(NSInteger)clampedCount
{
    _currentBranchName = [branchName copy] ?: @"";
    _currentOutOfStockCount = outOfStockCount;
    _currentClampedCount = clampedCount;
    
    NSString *cleanName = branchName.length ? branchName : kLang(@"Default Branch");
    _storeBadgeLabel.text = [NSString stringWithFormat:kLang(@"cart_branch_changed_title"), cleanName];
    
    if (outOfStockCount > 0) {
        _titleLabel.text = kLang(@"cart_branch_unavailable_checkout_blocked_title");
        _titleLabel.textColor = UIColor.systemRedColor;
        _subtitleLabel.text = [NSString stringWithFormat:kLang(@"cart_branch_unavailable_notice"), (long)outOfStockCount];
        
        [_removeUnavailableButton setTitle:[NSString stringWithFormat:@"%@ (%ld)", kLang(@"cart_branch_remove_unavailable_action"), (long)outOfStockCount] forState:UIControlStateNormal];
        _removeUnavailableButton.hidden = NO;
        
        [_saveUnavailableButton setTitle:kLang(@"cart_branch_save_unavailable_action") forState:UIControlStateNormal];
        _saveUnavailableButton.hidden = NO;
        _actionStackView.hidden = NO;
    } else if (clampedCount > 0) {
        _titleLabel.text = kLang(@"cart_branch_changed_title_notice");
        _titleLabel.textColor = AppPrimaryClr;
        _subtitleLabel.text = [NSString stringWithFormat:kLang(@"cart_branch_clamped_notice"), (long)clampedCount];
        _removeUnavailableButton.hidden = YES;
        _saveUnavailableButton.hidden = YES;
        _actionStackView.hidden = YES;
    } else {
        _titleLabel.text = kLang(@"cart_branch_changed_title_notice");
        _titleLabel.textColor = UIColor.labelColor;
        _subtitleLabel.text = [NSString stringWithFormat:kLang(@"cart_branch_all_available"), cleanName];
        _removeUnavailableButton.hidden = YES;
        _saveUnavailableButton.hidden = YES;
        _actionStackView.hidden = YES;
    }
}

- (void)pp_removeUnavailableTapped {
    if (self.onRemoveUnavailable) {
        self.onRemoveUnavailable();
    }
}

- (void)pp_saveUnavailableTapped {
    if (self.onSaveUnavailableToSavedForLater) {
        self.onSaveUnavailableToSavedForLater();
    }
}

- (void)pp_dismissTapped {
    if (self.onDismiss) {
        self.onDismiss();
    }
}

@end
