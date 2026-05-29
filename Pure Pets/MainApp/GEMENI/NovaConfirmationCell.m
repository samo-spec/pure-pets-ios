//
//  NovaConfirmationCell.m
//  Pure Pets
//

#import "NovaConfirmationCell.h"
#import "AppManager.h"

@interface NovaConfirmationCell ()

@property (nonatomic, strong) UIVisualEffectView *cardView;
@property (nonatomic, strong) UIView *accentView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *confirmButton;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, strong, nullable) PetAccessory *product;
@property (nonatomic, assign) CGFloat maxWidth;

@end

@implementation NovaConfirmationCell

+ (NSString *)reuseIdentifier {
    return @"NovaConfirmationCell";
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self pp_setupUI];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.product = nil;
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.contentView.alpha = 1.0;
    self.contentView.transform = CGAffineTransformIdentity;
}

- (void)pp_setupUI {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.contentView.clipsToBounds = NO;
    self.clipsToBounds = NO;

    UIBlurEffectStyle blurStyle = UIBlurEffectStyleRegular;
    if (@available(iOS 13.0, *)) {
        blurStyle = UIBlurEffectStyleSystemThinMaterial;
    }

    self.cardView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:blurStyle]];
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardView.clipsToBounds = YES;
    self.cardView.layer.cornerRadius = 24.0;
    self.cardView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    UIColor *brandColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    self.cardView.layer.borderColor = [brandColor colorWithAlphaComponent:0.20].CGColor;
    self.cardView.layer.shadowColor = [UIColor.blackColor colorWithAlphaComponent:0.14].CGColor;
    self.cardView.layer.shadowOpacity = 1.0;
    self.cardView.layer.shadowRadius = 18.0;
    self.cardView.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    if (@available(iOS 13.0, *)) {
        self.cardView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:self.cardView];

    UIView *content = self.cardView.contentView;
    content.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    self.accentView = [[UIView alloc] init];
    self.accentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.accentView.backgroundColor = [brandColor colorWithAlphaComponent:0.92];
    self.accentView.layer.cornerRadius = 2.0;
    [content addSubview:self.accentView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [GM boldFontWithSize:PPFontHeadline] ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    self.titleLabel.numberOfLines = 0;
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.titleLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [content addSubview:self.titleLabel];

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [GM fontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightRegular];
    self.subtitleLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    self.subtitleLabel.numberOfLines = 0;
    self.subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.subtitleLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [content addSubview:self.subtitleLabel];

    self.confirmButton = [self pp_buttonWithTitle:kLang(@"nova_cart_confirm_add") primary:YES];
    [self.confirmButton addTarget:self action:@selector(pp_confirmTapped) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:self.confirmButton];

    self.cancelButton = [self pp_buttonWithTitle:kLang(@"nova_cart_confirm_cancel") primary:NO];
    [self.cancelButton addTarget:self action:@selector(pp_cancelTapped) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:self.cancelButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8.0],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20.0],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20.0],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12.0],

        [self.accentView.topAnchor constraintEqualToAnchor:content.topAnchor constant:20.0],
        [self.accentView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:18.0],
        [self.accentView.widthAnchor constraintEqualToConstant:4.0],
        [self.accentView.heightAnchor constraintEqualToConstant:34.0],

        [self.titleLabel.topAnchor constraintEqualToAnchor:content.topAnchor constant:18.0],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.accentView.trailingAnchor constant:12.0],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-18.0],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:7.0],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],

        [self.confirmButton.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:16.0],
        [self.confirmButton.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.confirmButton.heightAnchor constraintEqualToConstant:46.0],

        [self.cancelButton.topAnchor constraintEqualToAnchor:self.confirmButton.topAnchor],
        [self.cancelButton.leadingAnchor constraintEqualToAnchor:self.confirmButton.trailingAnchor constant:10.0],
        [self.cancelButton.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
        [self.cancelButton.widthAnchor constraintEqualToAnchor:self.confirmButton.widthAnchor multiplier:0.86],
        [self.cancelButton.heightAnchor constraintEqualToAnchor:self.confirmButton.heightAnchor],
        [self.cancelButton.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-18.0]
    ]];
}

- (UIButton *)pp_buttonWithTitle:(NSString *)title primary:(BOOL)primary {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.titleLabel.font = [GM MidFontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.78;
    button.titleLabel.numberOfLines = 1;
    [button setTitle:title forState:UIControlStateNormal];
    UIColor *brand = AppPrimaryClr ?: UIColor.systemOrangeColor;
    button.backgroundColor = primary ? brand : [brand colorWithAlphaComponent:0.10];
    [button setTitleColor:primary ? UIColor.whiteColor : brand forState:UIControlStateNormal];
    button.layer.cornerRadius = 16.0;
    button.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [button addTarget:self action:@selector(pp_buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(pp_buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
    return button;
}

- (void)configureWithMessage:(ChatMessageModel *)messageModel maxWidth:(CGFloat)maxWidth {
    self.maxWidth = maxWidth;
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.cardView.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.confirmButton.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.cancelButton.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.confirmButton setTitle:kLang(@"nova_cart_confirm_add") forState:UIControlStateNormal];
    [self.cancelButton setTitle:kLang(@"nova_cart_confirm_cancel") forState:UIControlStateNormal];

    PetAccessory *product = nil;
    for (id item in messageModel.novaProducts ?: @[]) {
        if ([item isKindOfClass:PetAccessory.class]) {
            product = (PetAccessory *)item;
            break;
        }
    }
    self.product = product;

    NSString *runtimeTitle = [messageModel.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    self.titleLabel.text = runtimeTitle.length > 0 ? runtimeTitle : kLang(@"nova_cart_confirmation_title");
    NSString *productName = product.name.length > 0 ? product.name : kLang(@"nova_cart_confirmation_item");
    self.subtitleLabel.text = [NSString stringWithFormat:kLang(@"nova_cart_confirmation_subtitle_format"), productName];
    self.accessibilityLabel = [NSString stringWithFormat:@"%@. %@", self.titleLabel.text ?: @"", self.subtitleLabel.text ?: @""];
}

- (void)pp_buttonTouchDown:(UIButton *)button {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    [UIView animateWithDuration:0.10 delay:0.0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        button.transform = CGAffineTransformMakeScale(0.975, 0.975);
        button.alpha = 0.92;
    } completion:nil];
}

- (void)pp_buttonTouchUp:(UIButton *)button {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        button.transform = CGAffineTransformIdentity;
        button.alpha = 1.0;
        return;
    }
    [UIView animateWithDuration:0.18 delay:0.0 usingSpringWithDamping:0.86 initialSpringVelocity:0.18 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        button.transform = CGAffineTransformIdentity;
        button.alpha = 1.0;
    } completion:nil];
}

- (void)pp_confirmTapped {
    if (!self.product) {
        return;
    }
    [self.delegate novaConfirmationCellDidConfirm:self product:self.product];
}

- (void)pp_cancelTapped {
    [self.delegate novaConfirmationCellDidCancel:self];
}

@end
