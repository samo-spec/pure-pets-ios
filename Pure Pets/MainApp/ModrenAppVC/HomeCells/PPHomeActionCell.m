//
//  PPHomeActionCell 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 26/12/2025.
//


#import "PPHomeActionCell.h"
#import "PPHomeModels.h"

@interface PPHomeActionCell ()

@property (nonatomic, strong) UIView *glowView;
@property (nonatomic, strong) UIView *iconChipView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIImageView *chevronView;
@end

@implementation PPHomeActionCell

+ (NSString *)reuseIdentifier {
    return @"PPHomeActionCell";
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupUI];
    }
    return self;
}

#pragma mark - UI

- (void)setupUI {

    self.contentView.backgroundColor = UIColor.clearColor;

    self.actionButton = [UIButton new];
    self.actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.actionButton addTarget:self
                          action:@selector(handleTap)
                forControlEvents:UIControlEventTouchUpInside];
    [self.actionButton addTarget:self
                          action:@selector(handleTouchDown)
                forControlEvents:UIControlEventTouchDown];
    [self.actionButton addTarget:self
                          action:@selector(handleTouchUp)
                forControlEvents:UIControlEventTouchUpInside];
    [self.actionButton addTarget:self
                          action:@selector(handleTouchUp)
                forControlEvents:UIControlEventTouchUpOutside];
    [self.actionButton addTarget:self
                          action:@selector(handleTouchUp)
                forControlEvents:UIControlEventTouchCancel];
    self.actionButton.tintColor = AppPrimaryClr;
    self.actionButton.showsMenuAsPrimaryAction = NO;
    self.actionButton.layer.shadowColor = UIColor.blackColor.CGColor;
    self.actionButton.layer.shadowOpacity = 0.05f;
    self.actionButton.layer.shadowRadius = 10.0f;
    self.actionButton.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    self.actionButton.adjustsImageWhenHighlighted = NO;
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.background.cornerRadius = 20.0;
        cfg.baseForegroundColor = AppPrimaryClr;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(11.0, 14.0, 11.0, 14.0);
        self.actionButton.configuration = cfg;
    }
    else if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
        cfg.background.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.94];
        cfg.background.cornerRadius = 20.0;
        cfg.background.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.06];
        cfg.background.strokeWidth = 0.75;
        cfg.baseForegroundColor = AppPrimaryClr;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(11.0, 14.0, 11.0, 14.0);
        self.actionButton.configuration = cfg;
    }
    else {
        self.actionButton.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.94];
        self.actionButton.layer.cornerRadius = 20.0;
        self.actionButton.layer.borderWidth = 0.75;
        self.actionButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;
        self.actionButton.clipsToBounds = YES;
    }

    [self.contentView addSubview:self.actionButton];

    self.glowView = [[UIView alloc] init];
    self.glowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.glowView.userInteractionEnabled = NO;
    self.glowView.hidden = YES;
    self.glowView.alpha = 0.16;
    self.glowView.layer.cornerRadius = 16.0;
    [self.actionButton addSubview:self.glowView];

    self.iconChipView = [[UIView alloc] init];
    self.iconChipView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconChipView.userInteractionEnabled = NO;
    self.iconChipView.hidden = YES;
    self.iconChipView.layer.cornerRadius = 15.0;
    self.iconChipView.layer.cornerCurve = kCACornerCurveContinuous;
    [self.actionButton addSubview:self.iconChipView];

    self.iconView = [[UIImageView alloc] init];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.hidden = YES;
    [self.iconChipView addSubview:self.iconView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.hidden = YES;
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.titleLabel.font = [GM boldFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = AppPrimaryTextClr;
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.actionButton addSubview:self.titleLabel];

    UIImage *chevronImage =
        [UIImage pp_symbolNamed:(Language.isRTL ? @"chevron.left" : @"chevron.right")
                      pointSize:11
                         weight:UIImageSymbolWeightBold
                          scale:UIImageSymbolScaleSmall
                        palette:@[[AppPrimaryTextClr colorWithAlphaComponent:0.52] ?: UIColor.secondaryLabelColor]
                   makeTemplate:YES];
    self.chevronView = [[UIImageView alloc] initWithImage:chevronImage];
    self.chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    self.chevronView.contentMode = UIViewContentModeScaleAspectFit;
    self.chevronView.hidden = YES;
    [self.actionButton addSubview:self.chevronView];

    [NSLayoutConstraint activateConstraints:@[
        [self.actionButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.actionButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.actionButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.actionButton.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        [self.actionButton.heightAnchor constraintGreaterThanOrEqualToConstant:56.0],

        [self.glowView.leadingAnchor constraintEqualToAnchor:self.actionButton.leadingAnchor constant:8.0],
        [self.glowView.trailingAnchor constraintEqualToAnchor:self.actionButton.trailingAnchor constant:-8.0],
        [self.glowView.topAnchor constraintEqualToAnchor:self.actionButton.topAnchor constant:7.0],
        [self.glowView.heightAnchor constraintEqualToConstant:24.0],

        [self.iconChipView.leadingAnchor constraintEqualToAnchor:self.actionButton.leadingAnchor constant:10.0],
        [self.iconChipView.centerYAnchor constraintEqualToAnchor:self.actionButton.centerYAnchor],
        [self.iconChipView.widthAnchor constraintEqualToConstant:34.0],
        [self.iconChipView.heightAnchor constraintEqualToConstant:34.0],

        [self.iconView.centerXAnchor constraintEqualToAnchor:self.iconChipView.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:self.iconChipView.centerYAnchor],
        [self.iconView.widthAnchor constraintEqualToConstant:16.0],
        [self.iconView.heightAnchor constraintEqualToConstant:16.0],

        [self.chevronView.trailingAnchor constraintEqualToAnchor:self.actionButton.trailingAnchor constant:-14.0],
        [self.chevronView.centerYAnchor constraintEqualToAnchor:self.actionButton.centerYAnchor],
        [self.chevronView.widthAnchor constraintEqualToConstant:11.0],
        [self.chevronView.heightAnchor constraintEqualToConstant:11.0],

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.iconChipView.trailingAnchor constant:10.0],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.chevronView.leadingAnchor constant:-8.0],
        [self.titleLabel.centerYAnchor constraintEqualToAnchor:self.actionButton.centerYAnchor]
    ]];
}

#pragma mark - Configure

- (void)configureWithTitle:(NSString *)title
                systemIcon:(NSString *)systemIconName {
    [self pp_hideQuickActionChrome];
    self.actionButton.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIImage *icon = [UIImage pp_symbolNamed:systemIconName pointSize:22 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleLarge palette:@[AppPrimaryClr] makeTemplate:YES];
    if (@available(iOS 15.0, *)) {

        UIButtonConfiguration *cfg = self.actionButton.configuration;
        cfg.title = title;
        cfg.image = icon;
        cfg.imagePlacement = NSDirectionalRectEdgeLeading;
        cfg.imagePadding = PPSpaceSM;
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
       // cfg.background.cornerRadius = 16;
        cfg.baseForegroundColor = AppPrimaryClr;
        cfg.attributedTitle =
        [[NSAttributedString alloc] initWithString:title
                                        attributes:@{
            NSFontAttributeName : [GM boldFontWithSize:PPFontSubheadline],
            NSForegroundColorAttributeName : AppPrimaryTextClr
        }];

        self.actionButton.configuration = cfg;
        self.actionButton.clipsToBounds = YES;
    }
    else {
        [self.actionButton setTitle:title forState:UIControlStateNormal];
        [self.actionButton setImage:icon forState:UIControlStateNormal];
        self.actionButton.titleLabel.font = [GM boldFontWithSize:PPFontSubheadline];
        [self.actionButton setTitleColor:AppPrimaryTextClr forState:UIControlStateNormal];
    }
}

- (void)configureWithQuickAction:(PPHomeQuickActionModel *)quickAction
{
    self.actionButton.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    UIColor *accent = AppPrimaryClr ?: UIColor.systemPinkColor;
    UIColor *surfaceTint = [AppForgroundColr colorWithAlphaComponent:0.92] ?: [UIColor secondarySystemBackgroundColor];

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *cfg = self.actionButton.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
        cfg.title = @"";
        cfg.image = nil;
        cfg.baseForegroundColor = AppPrimaryTextClr;
        cfg.background.cornerRadius = 20.0;
        cfg.background.backgroundColor = surfaceTint;
        cfg.background.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.06];
        cfg.background.strokeWidth = 0.75;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(11.0, 15.0, 11.0, 15.0);
        self.actionButton.configuration = cfg;
    } else {
        self.actionButton.backgroundColor = surfaceTint;
        self.actionButton.layer.cornerRadius = 20.0;
        self.actionButton.layer.borderWidth = 0.75;
        self.actionButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;
    }

    [self.actionButton setTitle:nil forState:UIControlStateNormal];
    [self.actionButton setImage:nil forState:UIControlStateNormal];
    self.glowView.hidden = NO;
    self.iconChipView.hidden = NO;
    self.iconView.hidden = NO;
    self.titleLabel.hidden = NO;
    self.chevronView.hidden = NO;

    self.glowView.backgroundColor = [accent colorWithAlphaComponent:0.06];
    self.iconChipView.backgroundColor = [accent colorWithAlphaComponent:0.10];
    self.iconChipView.layer.borderWidth = 0.8;
    self.iconChipView.layer.borderColor = [accent colorWithAlphaComponent:0.08].CGColor;
    self.titleLabel.text = PPSafeString(quickAction.title);
    self.actionButton.accessibilityLabel = self.titleLabel.text;
    self.iconView.tintColor = accent;
    self.iconView.image =
        [UIImage pp_symbolNamed:PPSafeString(quickAction.iconName)
                      pointSize:17
                         weight:UIImageSymbolWeightSemibold
                          scale:UIImageSymbolScaleMedium
                        palette:@[accent]
                   makeTemplate:YES];
}

- (void)handleTap {
    if (self.onTap) {
        self.onTap();
    }
}

- (void)handleTouchDown
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    [UIView animateWithDuration:0.12
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.actionButton.transform = CGAffineTransformMakeScale(0.985, 0.985);
        self.actionButton.alpha = 0.98;
    } completion:nil];
}

- (void)handleTouchUp
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.actionButton.transform = CGAffineTransformIdentity;
        self.actionButton.alpha = 1.0;
        return;
    }

    [UIView animateWithDuration:0.18
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.actionButton.transform = CGAffineTransformIdentity;
        self.actionButton.alpha = 1.0;
    } completion:nil];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.onTap = nil;
    [self handleTouchUp];
    [self pp_hideQuickActionChrome];
}

- (void)setOnTap:(void (^)(void))onTap {
    _onTap = [onTap copy];
}

- (void)pp_hideQuickActionChrome
{
    self.glowView.hidden = YES;
    self.iconChipView.hidden = YES;
    self.iconView.hidden = YES;
    self.titleLabel.hidden = YES;
    self.chevronView.hidden = YES;
    self.titleLabel.text = nil;
    self.iconView.image = nil;
}

@end
