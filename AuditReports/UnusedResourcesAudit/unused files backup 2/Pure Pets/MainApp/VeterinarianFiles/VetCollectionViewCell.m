//
//  VetCollectionViewCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 15/07/2025.
//

#import "VetCollectionViewCell.h"
#import "VetModel.h"
#import "AppManager.h"
#import "FavoriteButton.h"

@interface VetCollectionViewCell ()
@property (nonatomic, strong) UIButton *editButton;
@property (nonatomic, assign) BOOL isOwnedByUser;
@end

@implementation VetCollectionViewCell {
    UIView *_cardContainer;
    UIVisualEffectView *_infoContainer;
    UIView *_typePillView;
}

static UIColor *PPVetCellAccentColor(void)
{
    return AppPrimaryClr ?: [UIColor colorWithRed:0.922 green:0.208 blue:0.486 alpha:1.0];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self pp_buildUI];
        [self pp_applyThemeColors];
    }
    return self;
}

- (void)pp_buildUI
{
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds = NO;
    self.clipsToBounds = NO;
    
    // 1. Card Container
    _cardContainer = [[UIView alloc] init];
    _cardContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _cardContainer.backgroundColor = AppForgroundColr ?: UIColor.secondarySystemGroupedBackgroundColor;
    _cardContainer.clipsToBounds = YES;
    _cardContainer.layer.cornerRadius = 20.0;
    _cardContainer.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    if (@available(iOS 13.0, *)) {
        _cardContainer.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:_cardContainer];
    
    // 2. Cover/Logo Image View
    _logoImageView = [[UIImageView alloc] init];
    _logoImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _logoImageView.contentMode = UIViewContentModeScaleAspectFill;
    _logoImageView.clipsToBounds = YES;
    [_cardContainer addSubview:_logoImageView];
    
    // 3. Bottom Info Panel (Frosted glassmorphism effect)
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    _infoContainer = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    _infoContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [_cardContainer addSubview:_infoContainer];
    
    // 4. Labels inside Info Panel
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightBold];
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    _titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    _titleLabel.numberOfLines = 1;
    _titleLabel.adjustsFontSizeToFitWidth = YES;
    _titleLabel.minimumScaleFactor = 0.88;
    [_infoContainer.contentView addSubview:_titleLabel];
    
    // 5. Type Pill
    _typePillView = [[UIView alloc] init];
    _typePillView.translatesAutoresizingMaskIntoConstraints = NO;
    _typePillView.layer.cornerRadius = 9.0;
    if (@available(iOS 13.0, *)) {
        _typePillView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_infoContainer.contentView addSubview:_typePillView];
    
    _typeLabel = [[UILabel alloc] init];
    _typeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _typeLabel.font = [GM boldFontWithSize:10.0] ?: [UIFont systemFontOfSize:10.0 weight:UIFontWeightBold];
    _typeLabel.textAlignment = NSTextAlignmentCenter;
    [_typePillView addSubview:_typeLabel];
    
    // 6. Floating Circular Actions (Top corners)
    _favButton = [[FavoriteButton alloc] initWithFrame:CGRectZero];
    _favButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_cardContainer addSubview:_favButton];
    [self pp_styleFloatingButton:_favButton symbol:nil color:nil]; // FavoriteButton manages its own icon & color
    
    _shareButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _shareButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_cardContainer addSubview:_shareButton];
    [self pp_styleFloatingButton:_shareButton symbol:@"square.and.arrow.up" color:UIColor.whiteColor];
    [_shareButton addTarget:self action:@selector(shareTapped) forControlEvents:UIControlEventTouchUpInside];
    [self pp_addButtonTouchAnimations:_shareButton];
    
    _editButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _editButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_cardContainer addSubview:_editButton];
    [self pp_styleFloatingButton:_editButton symbol:@"square.and.pencil" color:UIColor.whiteColor];
    [_editButton addTarget:self action:@selector(editTapped) forControlEvents:UIControlEventTouchUpInside];
    [self pp_addButtonTouchAnimations:_editButton];
    
    _deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _deleteButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_cardContainer addSubview:_deleteButton];
    [self pp_styleFloatingButton:_deleteButton symbol:@"trash" color:PPVetCellAccentColor()];
    [_deleteButton addTarget:self action:@selector(deleteTapped) forControlEvents:UIControlEventTouchUpInside];
    [self pp_addButtonTouchAnimations:_deleteButton];
    
    // 7. Auto Layout Constraints
    [NSLayoutConstraint activateConstraints:@[
        [_cardContainer.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [_cardContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_cardContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_cardContainer.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        
        [_logoImageView.topAnchor constraintEqualToAnchor:_cardContainer.topAnchor],
        [_logoImageView.leadingAnchor constraintEqualToAnchor:_cardContainer.leadingAnchor],
        [_logoImageView.trailingAnchor constraintEqualToAnchor:_cardContainer.trailingAnchor],
        [_logoImageView.bottomAnchor constraintEqualToAnchor:_cardContainer.bottomAnchor],
        
        [_infoContainer.leadingAnchor constraintEqualToAnchor:_cardContainer.leadingAnchor],
        [_infoContainer.trailingAnchor constraintEqualToAnchor:_cardContainer.trailingAnchor],
        [_infoContainer.bottomAnchor constraintEqualToAnchor:_cardContainer.bottomAnchor],
        [_infoContainer.heightAnchor constraintEqualToConstant:62.0],
        
        [_titleLabel.topAnchor constraintEqualToAnchor:_infoContainer.contentView.topAnchor constant:8.0],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_infoContainer.contentView.leadingAnchor constant:12.0],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_infoContainer.contentView.trailingAnchor constant:-12.0],
        
        [_typePillView.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4.0],
        [_typePillView.leadingAnchor constraintEqualToAnchor:_infoContainer.contentView.leadingAnchor constant:12.0],
        [_typePillView.bottomAnchor constraintLessThanOrEqualToAnchor:_infoContainer.contentView.bottomAnchor constant:-8.0],
        
        [_typeLabel.topAnchor constraintEqualToAnchor:_typePillView.topAnchor constant:2.5],
        [_typeLabel.bottomAnchor constraintEqualToAnchor:_typePillView.bottomAnchor constant:-2.5],
        [_typeLabel.leadingAnchor constraintEqualToAnchor:_typePillView.leadingAnchor constant:7.0],
        [_typeLabel.trailingAnchor constraintEqualToAnchor:_typePillView.trailingAnchor constant:-7.0],
        
        // Floating buttons constraints (RTL safe)
        // Leading buttons (Favorite / Edit)
        [_favButton.topAnchor constraintEqualToAnchor:_cardContainer.topAnchor constant:10.0],
        [_favButton.leadingAnchor constraintEqualToAnchor:_cardContainer.leadingAnchor constant:10.0],
        [_favButton.widthAnchor constraintEqualToConstant:32.0],
        [_favButton.heightAnchor constraintEqualToConstant:32.0],
        
        [_editButton.topAnchor constraintEqualToAnchor:_cardContainer.topAnchor constant:10.0],
        [_editButton.leadingAnchor constraintEqualToAnchor:_cardContainer.leadingAnchor constant:10.0],
        [_editButton.widthAnchor constraintEqualToConstant:32.0],
        [_editButton.heightAnchor constraintEqualToConstant:32.0],
        
        // Trailing buttons (Share / Delete)
        [_shareButton.topAnchor constraintEqualToAnchor:_cardContainer.topAnchor constant:10.0],
        [_shareButton.trailingAnchor constraintEqualToAnchor:_cardContainer.trailingAnchor constant:-10.0],
        [_shareButton.widthAnchor constraintEqualToConstant:32.0],
        [_shareButton.heightAnchor constraintEqualToConstant:32.0],
        
        [_deleteButton.topAnchor constraintEqualToAnchor:_cardContainer.topAnchor constant:10.0],
        [_deleteButton.trailingAnchor constraintEqualToAnchor:_cardContainer.trailingAnchor constant:-10.0],
        [_deleteButton.widthAnchor constraintEqualToConstant:32.0],
        [_deleteButton.heightAnchor constraintEqualToConstant:32.0]
    ]];
}

- (void)pp_styleFloatingButton:(UIButton *)button symbol:(NSString *)symbolName color:(nullable UIColor *)tintColor
{
    button.backgroundColor = UIColor.clearColor;
    button.layer.cornerRadius = 16.0;
    button.clipsToBounds = YES;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [UIColor.whiteColor colorWithAlphaComponent:0.20].CGColor;
    
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.userInteractionEnabled = NO;
    [button addSubview:blurView];
    [button sendSubviewToBack:blurView];
    
    [NSLayoutConstraint activateConstraints:@[
        [blurView.topAnchor constraintEqualToAnchor:button.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:button.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:button.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:button.bottomAnchor]
    ]];
    
    if (symbolName) {
        UIImage *image = nil;
        if (@available(iOS 13.0, *)) {
            image = [UIImage systemImageNamed:symbolName
                            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14.0
                                                                                            weight:UIImageSymbolWeightSemibold]];
        } else {
            image = [UIImage imageNamed:symbolName];
        }
        [button setImage:[image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    }
    
    if (tintColor) {
        button.tintColor = tintColor;
    }
}

- (void)pp_addButtonTouchAnimations:(UIButton *)button
{
    [button addTarget:self action:@selector(pp_buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(pp_buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
}

- (void)pp_buttonTouchDown:(UIButton *)sender
{
    [UIView animateWithDuration:0.08 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        sender.transform = CGAffineTransformMakeScale(0.90, 0.90);
    } completion:nil];
}

- (void)pp_buttonTouchUp:(UIButton *)sender
{
    [UIView animateWithDuration:0.25 delay:0.0 usingSpringWithDamping:0.6 initialSpringVelocity:0.4 options:0 animations:^{
        sender.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_applyThemeColors
{
    BOOL darkMode = NO;
    if (@available(iOS 13.0, *)) {
        darkMode = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    
    UIColor *borderColor = darkMode
        ? [UIColor.whiteColor colorWithAlphaComponent:0.15]
        : [UIColor.blackColor colorWithAlphaComponent:0.08];
        
    _cardContainer.layer.borderColor = borderColor.CGColor;
    
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = darkMode ? 0.22f : 0.08f;
    self.layer.shadowRadius = darkMode ? 12.0f : 16.0f;
    self.layer.shadowOffset = CGSizeMake(0.0, 8.0);
}

- (void)setParentVC:(UIViewController *)ParentVC
{
    _ParentVC = ParentVC;
    if (self.favButton) {
        [(id)self.favButton setParentVC:ParentVC];
    }
}

- (void)configureWithVet:(VetModel *)vet isUserOwned:(BOOL)isOwned
{
    self.isOwnedByUser = isOwned;

    self.titleLabel.text = vet.title ?: @"";
    self.typeLabel.text = vet.type == VetTypeCompany ? @"شركة" : @"شخصي";
    
    if (vet.type == VetTypeCompany) {
        _typePillView.backgroundColor = [PPVetCellAccentColor() colorWithAlphaComponent:0.12];
        _typeLabel.textColor = PPVetCellAccentColor();
    } else {
        _typePillView.backgroundColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.12];
        _typeLabel.textColor = UIColor.secondaryLabelColor;
    }
    
    [GM setImageFromUrlString:vet.logoURL imageView:self.logoImageView phImage:@"placeholder"];
    
    id favBtn = self.favButton;
    [favBtn setAdID:vet.vetID ?: @""];
    [favBtn setCollection:@"favoritesVets"];
    [favBtn setParentVC:self.ParentVC];
    [favBtn initValue];
    
    self.shareButton.hidden = isOwned;
    self.favButton.hidden = isOwned;
    self.deleteButton.hidden = !isOwned;
    self.editButton.hidden = !isOwned;
}

- (void)shareTapped
{
    if (!UserManager.sharedManager.currentAuthUser) {
        [UserManager showPromptOnTopController];
        return;
    }
    if ([self.delegate respondsToSelector:@selector(vetCellDidTapShare:)]) {
        [self.delegate vetCellDidTapShare:self];
    }
}

- (void)deleteTapped
{
    if (!UserManager.sharedManager.currentAuthUser) {
        [UserManager showPromptOnTopController];
        return;
    }
    if ([self.delegate respondsToSelector:@selector(vetCellDidTapDelete:)]) {
        [self.delegate vetCellDidTapDelete:self];
    }
}

- (void)editTapped
{
    if (!UserManager.sharedManager.currentAuthUser) {
        [UserManager showPromptOnTopController];
        return;
    }
    if ([self.delegate respondsToSelector:@selector(vetCellDidTapEdit:)]) {
        [self.delegate vetCellDidTapEdit:self];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat cornerRadius = 20.0;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:cornerRadius].CGPath;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applyThemeColors];
        }
    }
}

@end
