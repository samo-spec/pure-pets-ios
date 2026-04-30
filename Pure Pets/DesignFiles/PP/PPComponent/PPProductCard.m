//
//  PPProductCard.m
//  Pure Pets
//
//  Design System — Product card component.
//  Uses PPDesignTokens for all spacing, typography, corners, and colors.
//

#import "PPProductCard.h"
#import "PPRatingView.h"
#import "PPDiscountBadge.h"

@interface PPProductCard ()

@property (nonatomic, strong, readwrite) UIImageView *productImageView;
@property (nonatomic, strong) UIView *cardSurface;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *priceLabel;
@property (nonatomic, strong) UILabel *originalPriceLabel;
@property (nonatomic, strong) PPRatingView *ratingView;
@property (nonatomic, strong) PPDiscountBadge *discountBadge;
@property (nonatomic, strong) UIButton *addToCartButton;

@end

@implementation PPProductCard

+ (NSString *)reuseIdentifier {
    return @"PPProductCard";
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self pp_setupUI];
    }
    return self;
}

#pragma mark - UI

- (void)pp_setupUI {
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    // ─── Card Surface ───
    _cardSurface = [[UIView alloc] init];
    _cardSurface.translatesAutoresizingMaskIntoConstraints = NO;
    _cardSurface.backgroundColor = AppForgroundColr;
    _cardSurface.layer.cornerRadius = PPCornerLarge;
    if (@available(iOS 13.0, *)) {
        _cardSurface.layer.cornerCurve = kCACornerCurveContinuous;
    }
    _cardSurface.clipsToBounds = YES;
    PPApplyCardShadow(_cardSurface);
    [self.contentView addSubview:_cardSurface];

    // ─── Product Image ───
    _productImageView = [[UIImageView alloc] init];
    _productImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _productImageView.contentMode = UIViewContentModeScaleAspectFill;
    _productImageView.clipsToBounds = YES;
    _productImageView.backgroundColor = [AppPlaceholderTextClr colorWithAlphaComponent:0.15];
    _productImageView.layer.cornerRadius = PPCornerMedium;
    if (@available(iOS 13.0, *)) {
        _productImageView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_cardSurface addSubview:_productImageView];

    // ─── Discount Badge (overlay on image, top-leading) ───
    _discountBadge = [[PPDiscountBadge alloc] initWithFrame:CGRectZero];
    _discountBadge.hidden = YES;
    [_cardSurface addSubview:_discountBadge];

    // ─── Title ───
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM MidFontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    _titleLabel.textColor = AppPrimaryTextClr;
    _titleLabel.numberOfLines = 2;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_cardSurface addSubview:_titleLabel];

    // ─── Rating ───
    _ratingView = [[PPRatingView alloc] initWithRating:0.0];
    [_cardSurface addSubview:_ratingView];

    // ─── Price Row ───
    _priceLabel = [[UILabel alloc] init];
    _priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _priceLabel.font = [GM boldFontWithSize:PPFontCallout] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightBold];
    _priceLabel.textColor = AppPrimaryClr;
    [_cardSurface addSubview:_priceLabel];

    _originalPriceLabel = [[UILabel alloc] init];
    _originalPriceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _originalPriceLabel.font = [GM fontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightRegular];
    _originalPriceLabel.textColor = AppTertiaryTextClr;
    _originalPriceLabel.hidden = YES;
    [_cardSurface addSubview:_originalPriceLabel];

    // ─── Add to Cart Button ───
    _addToCartButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _addToCartButton.translatesAutoresizingMaskIntoConstraints = NO;
    _addToCartButton.backgroundColor = AppPrimaryClr;
    _addToCartButton.layer.cornerRadius = PPCornerSmall;
    if (@available(iOS 13.0, *)) {
        _addToCartButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    _addToCartButton.clipsToBounds = YES;

    UIImageSymbolConfiguration *cartConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:16.0
                                                        weight:UIImageSymbolWeightMedium];
    UIImage *cartIcon = [[UIImage systemImageNamed:@"cart.badge.plus" withConfiguration:cartConfig]
                         imageWithTintColor:UIColor.whiteColor
                         renderingMode:UIImageRenderingModeAlwaysOriginal];
    [_addToCartButton setImage:cartIcon forState:UIControlStateNormal];
    [_addToCartButton addTarget:self action:@selector(pp_cartTapped) forControlEvents:UIControlEventTouchUpInside];
    [_cardSurface addSubview:_addToCartButton];

    // ─── Constraints ───
    CGFloat pad = PPSpaceSM;
    CGFloat innerPad = PPSpaceXS;

    [NSLayoutConstraint activateConstraints:@[
        // Card surface
        [_cardSurface.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [_cardSurface.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_cardSurface.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_cardSurface.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        // Image — top, leading/trailing with padding, aspect ~1:1 (square)
        [_productImageView.topAnchor constraintEqualToAnchor:_cardSurface.topAnchor constant:pad],
        [_productImageView.leadingAnchor constraintEqualToAnchor:_cardSurface.leadingAnchor constant:pad],
        [_productImageView.trailingAnchor constraintEqualToAnchor:_cardSurface.trailingAnchor constant:-pad],
        [_productImageView.heightAnchor constraintEqualToAnchor:_productImageView.widthAnchor],

        // Discount badge — overlaid on top-leading of image
        [_discountBadge.topAnchor constraintEqualToAnchor:_productImageView.topAnchor constant:innerPad],
        [_discountBadge.leadingAnchor constraintEqualToAnchor:_productImageView.leadingAnchor constant:innerPad],

        // Title — below image
        [_titleLabel.topAnchor constraintEqualToAnchor:_productImageView.bottomAnchor constant:pad],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_cardSurface.leadingAnchor constant:pad],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_cardSurface.trailingAnchor constant:-pad],

        // Rating — below title
        [_ratingView.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:innerPad],
        [_ratingView.leadingAnchor constraintEqualToAnchor:_cardSurface.leadingAnchor constant:pad],
        [_ratingView.trailingAnchor constraintLessThanOrEqualToAnchor:_cardSurface.trailingAnchor constant:-pad],

        // Price row — below rating
        [_priceLabel.topAnchor constraintEqualToAnchor:_ratingView.bottomAnchor constant:innerPad],
        [_priceLabel.leadingAnchor constraintEqualToAnchor:_cardSurface.leadingAnchor constant:pad],

        [_originalPriceLabel.leadingAnchor constraintEqualToAnchor:_priceLabel.trailingAnchor constant:PPSpaceXXS],
        [_originalPriceLabel.centerYAnchor constraintEqualToAnchor:_priceLabel.centerYAnchor],

        // Add-to-cart button — aligned trailing, same row as price
        [_addToCartButton.trailingAnchor constraintEqualToAnchor:_cardSurface.trailingAnchor constant:-pad],
        [_addToCartButton.centerYAnchor constraintEqualToAnchor:_priceLabel.centerYAnchor],
        [_addToCartButton.widthAnchor constraintEqualToConstant:36.0],
        [_addToCartButton.heightAnchor constraintEqualToConstant:36.0],

        // Bottom anchor — price row to bottom
        [_priceLabel.bottomAnchor constraintLessThanOrEqualToAnchor:_cardSurface.bottomAnchor constant:-pad],
    ]];

    // Tap gesture on entire card
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_cardTapped)];
    [self.contentView addGestureRecognizer:tap];
}

#pragma mark - Configure

- (void)configureWithTitle:(NSString *)title
                     price:(NSString *)price
             originalPrice:(nullable NSString *)originalPrice
                  imageURL:(nullable NSString *)imageURL
                    rating:(CGFloat)rating
               reviewCount:(NSInteger)reviewCount
               discountPct:(NSInteger)discountPct
                  currency:(NSString *)currency {

    self.titleLabel.text = title;
    self.priceLabel.text = price;

    // Original price with strikethrough
    if (originalPrice.length > 0) {
        self.originalPriceLabel.hidden = NO;
        NSDictionary *attrs = @{
            NSStrikethroughStyleAttributeName : @(NSUnderlineStyleSingle),
            NSForegroundColorAttributeName : AppTertiaryTextClr,
            NSFontAttributeName : self.originalPriceLabel.font
        };
        self.originalPriceLabel.attributedText =
            [[NSAttributedString alloc] initWithString:originalPrice attributes:attrs];
    } else {
        self.originalPriceLabel.hidden = YES;
    }

    // Rating
    [self.ratingView setRating:rating reviewCount:reviewCount];

    // Discount badge
    [self.discountBadge configureWithPercent:discountPct];

    // Image placeholder (external loader should set productImageView.image)
    if (!imageURL || imageURL.length == 0) {
        UIImageSymbolConfiguration *placeholder =
            [UIImageSymbolConfiguration configurationWithPointSize:32.0
                                                            weight:UIImageSymbolWeightLight];
        self.productImageView.image = [UIImage systemImageNamed:@"photo" withConfiguration:placeholder];
        self.productImageView.tintColor = AppPlaceholderTextClr;
    }
}

#pragma mark - Actions

- (void)pp_cartTapped {
    if (self.onAddToCart) {
        self.onAddToCart();
    }
}

- (void)pp_cardTapped {
    if (self.onTap) {
        self.onTap();
    }
}

#pragma mark - Highlight

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];

    CGFloat scale = highlighted ? PPTapScaleDown : 1.0;
    [UIView animateWithDuration:PPAnimDurationFast
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.cardSurface.transform = CGAffineTransformMakeScale(scale, scale);
    } completion:nil];
}

#pragma mark - Reuse

- (void)prepareForReuse {
    [super prepareForReuse];
    self.titleLabel.text = nil;
    self.priceLabel.text = nil;
    self.originalPriceLabel.hidden = YES;
    self.originalPriceLabel.attributedText = nil;
    self.productImageView.image = nil;
    [self.ratingView setRating:0.0 reviewCount:0];
    [self.discountBadge configureWithPercent:0];
    self.onAddToCart = nil;
    self.onTap = nil;
    self.cardSurface.transform = CGAffineTransformIdentity;
}

@end
