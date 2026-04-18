//
//  AccessoryCollectionViewCell 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/06/2025.
//


#import "AccessoryCollectionViewCell.h"
#import "PetAccessory.h"

static const CGFloat kCellInset              = 2.0;
static const CGFloat kCellCornerRadius       = 24.0;
static const CGFloat kCellBadgeCornerRadius  = 999.0;
static const CGFloat kCellShadowRadius       = 18.0;
static const CGFloat kCellShadowOffsetY      = 10.0;
static const CGFloat kCellShadowOpacity      = 0.10f;
static const CGFloat kCellOverlayInset       = 14.0;
static const CGFloat kCellImageFallbackInset = 34.0;

@interface AccessoryCollectionViewCell ()

@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIImageView *placeholderIconView;
@property (nonatomic, strong) CAGradientLayer *scrimLayer;
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, strong) UILabel *stockLabel;
@property (nonatomic, strong) UIStackView *footerStackView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) UILabel *priceLabel;

@end

@implementation AccessoryCollectionViewCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self buildUI];
    }
    return self;
}

- (void)buildUI {
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.accessibilityTraits = UIAccessibilityTraitButton;

    self.containerView = [[UIView alloc] init];
    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.containerView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.68 : 1.0];
    self.containerView.layer.cornerRadius = kCellCornerRadius;
    self.containerView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.containerView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:self.containerView];

    self.imageView = [[UIImageView alloc] init];
    self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.imageView.clipsToBounds = YES;
    self.imageView.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.5];
    self.imageView.image = [UIImage imageNamed:@"placeholder"];
    [self.containerView addSubview:self.imageView];

    self.scrimLayer = [CAGradientLayer layer];
    self.scrimLayer.colors = @[
        (__bridge id)[UIColor colorWithWhite:0 alpha:0.03].CGColor,
        (__bridge id)[UIColor colorWithWhite:0 alpha:0.18].CGColor,
        (__bridge id)[UIColor colorWithWhite:0 alpha:0.64].CGColor
    ];
    self.scrimLayer.locations = @[@0.0, @0.55, @1.0];
    self.scrimLayer.startPoint = CGPointMake(0.5, 0.0);
    self.scrimLayer.endPoint = CGPointMake(0.5, 1.0);
    [self.containerView.layer addSublayer:self.scrimLayer];

    self.placeholderIconView = [[UIImageView alloc] initWithImage:[UIImage pp_symbolNamed:@"pawprint.fill"
                                                                                 pointSize:28
                                                                                    weight:UIImageSymbolWeightSemibold
                                                                                     scale:UIImageSymbolScaleLarge
                                                                                   palette:@[[UIColor colorWithWhite:1.0 alpha:0.95], [UIColor colorWithWhite:1.0 alpha:0.95]]
                                                                              makeTemplate:NO]];
    self.placeholderIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.placeholderIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.placeholderIconView.alpha = 0.92;
    [self.containerView addSubview:self.placeholderIconView];

    self.badgeLabel = [[UILabel alloc] init];
    self.badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.badgeLabel.font = [GM boldFontWithSize:11];
    self.badgeLabel.textAlignment = NSTextAlignmentCenter;
    self.badgeLabel.textColor = AppPrimaryTextClr;
    self.badgeLabel.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.92];
    self.badgeLabel.layer.cornerRadius = kCellBadgeCornerRadius;
    self.badgeLabel.layer.masksToBounds = YES;
    [self.badgeLabel.heightAnchor constraintGreaterThanOrEqualToConstant:24.0].active = YES;
    [self.containerView addSubview:self.badgeLabel];

    self.stockLabel = [[UILabel alloc] init];
    self.stockLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.stockLabel.font = [GM boldFontWithSize:11];
    self.stockLabel.textAlignment = NSTextAlignmentCenter;
    self.stockLabel.textColor = UIColor.whiteColor;
    self.stockLabel.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.95];
    self.stockLabel.layer.cornerRadius = kCellBadgeCornerRadius;
    self.stockLabel.layer.masksToBounds = YES;
    self.stockLabel.numberOfLines = 1;
    [self.stockLabel.heightAnchor constraintGreaterThanOrEqualToConstant:24.0].active = YES;
    [self.containerView addSubview:self.stockLabel];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [GM boldFontWithSize:17];
    self.titleLabel.textColor = UIColor.whiteColor;
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.titleLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.25];
    self.titleLabel.shadowOffset = CGSizeMake(0, 1);

    self.metaLabel = [[UILabel alloc] init];
    self.metaLabel.font = [GM MidFontWithSize:12];
    self.metaLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.84];
    self.metaLabel.numberOfLines = 1;
    self.metaLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.18];
    self.metaLabel.shadowOffset = CGSizeMake(0, 1);

    self.priceLabel = [[UILabel alloc] init];
    self.priceLabel.font = [GM boldFontWithSize:18];
    self.priceLabel.textColor = UIColor.whiteColor;
    self.priceLabel.numberOfLines = 1;
    self.priceLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.25];
    self.priceLabel.shadowOffset = CGSizeMake(0, 1);

    self.footerStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.titleLabel,
        self.metaLabel,
        self.priceLabel
    ]];
    self.footerStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.footerStackView.axis = UILayoutConstraintAxisVertical;
    self.footerStackView.alignment = UIStackViewAlignmentFill;
    self.footerStackView.distribution = UIStackViewDistributionFill;
    self.footerStackView.spacing = 4.0;
    [self.footerStackView setCustomSpacing:8.0 afterView:self.metaLabel];
    [self.containerView addSubview:self.footerStackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.containerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:kCellInset],
        [self.containerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:kCellInset],
        [self.containerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-kCellInset],
        [self.containerView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-kCellInset],

        [self.imageView.topAnchor constraintEqualToAnchor:self.containerView.topAnchor],
        [self.imageView.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor],
        [self.imageView.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor],
        [self.imageView.bottomAnchor constraintEqualToAnchor:self.containerView.bottomAnchor],

        [self.placeholderIconView.centerXAnchor constraintEqualToAnchor:self.containerView.centerXAnchor],
        [self.placeholderIconView.centerYAnchor constraintEqualToAnchor:self.containerView.centerYAnchor constant:-6.0],
        [self.placeholderIconView.widthAnchor constraintEqualToConstant:kCellImageFallbackInset],
        [self.placeholderIconView.heightAnchor constraintEqualToConstant:kCellImageFallbackInset],

        [self.badgeLabel.topAnchor constraintEqualToAnchor:self.containerView.topAnchor constant:kCellOverlayInset],
        [self.badgeLabel.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor constant:kCellOverlayInset],

        [self.stockLabel.topAnchor constraintEqualToAnchor:self.containerView.topAnchor constant:kCellOverlayInset],
        [self.stockLabel.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor constant:-kCellOverlayInset],
        [self.stockLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.badgeLabel.trailingAnchor constant:8.0],

        [self.footerStackView.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor constant:kCellOverlayInset],
        [self.footerStackView.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor constant:-kCellOverlayInset],
        [self.footerStackView.bottomAnchor constraintEqualToAnchor:self.containerView.bottomAnchor constant:-kCellOverlayInset],
    ]];

    [self pp_setShadowColor:[UIColor blackColor]];
    self.layer.shadowOffset = CGSizeMake(0, kCellShadowOffsetY);
    self.layer.shadowRadius = kCellShadowRadius;
    self.layer.shadowOpacity = kCellShadowOpacity;
    self.layer.masksToBounds = NO;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.imageView.image = [UIImage imageNamed:@"placeholder"];
    self.placeholderIconView.hidden = NO;
    self.badgeLabel.text = nil;
    self.stockLabel.text = nil;
    self.titleLabel.text = nil;
    self.metaLabel.text = nil;
    self.priceLabel.text = nil;
    self.containerView.transform = CGAffineTransformIdentity;
}

- (void)configureWithAccessory:(PetAccessory *)accessory {
    self.titleLabel.text = PPSafeString(accessory.name);
    self.badgeLabel.text = [NSString stringWithFormat:@"  %@  ", [PetAccessory typeTextForAccessory:accessory]];
    self.stockLabel.text = [NSString stringWithFormat:@"  %@  ", [accessory stockStatusText]];
    self.priceLabel.text = [GM formatPrice:(accessory.finalPrice ?: accessory.price) currencyCode:kLang(@"Rials")];
    self.metaLabel.text = [PetAccessory conditionTextForAccessory:accessory];

    UIColor *stockColor = accessory.quantity <= 0
        ? [UIColor systemRedColor]
        : (accessory.quantity <= 5 ? [UIColor colorWithRed:0.89 green:0.52 blue:0.10 alpha:1.0] : [AppPrimaryClr colorWithAlphaComponent:0.96]);
    self.stockLabel.backgroundColor = stockColor;

    NSString *imageURL = accessory.imageURLsArray.firstObject;
    self.placeholderIconView.hidden = imageURL.length > 0;
    if (imageURL.length > 0) {
        [GM setImageFromUrlString:imageURL imageView:self.imageView phImage:@"placeholder"];
    } else {
        self.imageView.image = [UIImage imageNamed:@"placeholder"];
    }
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [self pp_updateInteractionTransform];
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    [self pp_updateInteractionTransform];
}

- (void)pp_updateInteractionTransform {
    BOOL active = self.highlighted || self.selected;
    [UIView animateWithDuration:0.18
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.containerView.transform = active ? CGAffineTransformMakeScale(0.98, 0.98) : CGAffineTransformIdentity;
        self.layer.shadowOpacity = active ? 0.16f : kCellShadowOpacity;
    } completion:nil];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect shadowRect = CGRectInset(self.bounds, kCellInset, kCellInset);
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:shadowRect cornerRadius:kCellCornerRadius].CGPath;
    self.scrimLayer.frame = self.containerView.bounds;
}

@end
