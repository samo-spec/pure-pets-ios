//
//  ServiceCollectionViewCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 14/07/2025.
//


#import "ServiceCollectionViewCell.h"
#import "ServiceModel.h"
#import "AppManager.h"
#import "FavoriteButton.h"

@interface ServiceCollectionViewCell ()
@property (nonatomic, strong) UIButton *editButton;
@property (nonatomic, strong) UIView *topGradientView;
@property (nonatomic, strong) UIView *bottomGradientView;
@end

@implementation ServiceCollectionViewCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = [UIColor colorWithHexString:@"#FFFFFF"];
        self.contentView.clipsToBounds = YES;

        _imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        [self.contentView addSubview:_imageView];

        _bottomGradientView = [[UIView alloc] initWithFrame:CGRectZero];
        [AppClasses gardToView:_bottomGradientView
                      colorOne:[UIColor hx_colorWithHexStr:@"#000" alpha:0.0]
                      colorTwo:[UIColor hx_colorWithHexStr:@"#000" alpha:0.3]
                    colorThree:[UIColor hx_colorWithHexStr:@"#000" alpha:0.7]
                           rds:0];
        [self.contentView addSubview:_bottomGradientView];

        _topGradientView = [[UIView alloc] initWithFrame:CGRectZero];
        [AppClasses gardToView:_topGradientView
                      colorOne:[UIColor hx_colorWithHexStr:@"#000" alpha:0.7]
                      colorTwo:[UIColor hx_colorWithHexStr:@"#000" alpha:0.3]
                    colorThree:[UIColor hx_colorWithHexStr:@"#000" alpha:0.0]
                           rds:0];
        [self.contentView addSubview:_topGradientView];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.font = [GM boldFontWithSize:18];
        _titleLabel.numberOfLines = 1;
        _titleLabel.textColor = UIColor.whiteColor;
        _titleLabel.adjustsFontSizeToFitWidth = YES;
        _titleLabel.minimumScaleFactor = 0.82;
        [self.contentView addSubview:_titleLabel];

        _categoryLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _categoryLabel.font = [GM MidFontWithSize:12];
        _categoryLabel.numberOfLines = 1;
        _categoryLabel.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.82];
        _categoryLabel.adjustsFontSizeToFitWidth = YES;
        _categoryLabel.minimumScaleFactor = 0.85;
        [self.contentView addSubview:_categoryLabel];

        _priceLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _priceLabel.font = [GM boldFontWithSize:14];
        _priceLabel.numberOfLines = 1;
        _priceLabel.textColor = AppPrimaryClr ?: [UIColor colorWithRed:0.93 green:0.16 blue:0.45 alpha:1.0];
        _priceLabel.adjustsFontSizeToFitWidth = YES;
        _priceLabel.minimumScaleFactor = 0.88;
        [self.contentView addSubview:_priceLabel];

        _statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _statusLabel.font = [GM boldFontWithSize:11];
        _statusLabel.textAlignment = NSTextAlignmentCenter;
        _statusLabel.numberOfLines = 1;
        _statusLabel.layer.cornerRadius = 12.0;
        _statusLabel.layer.masksToBounds = YES;
        [self.contentView addSubview:_statusLabel];

        _ratingLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _ratingLabel.font = [GM boldFontWithSize:12];
        _ratingLabel.textAlignment = NSTextAlignmentCenter;
        _ratingLabel.numberOfLines = 1;
        _ratingLabel.textColor = [UIColor colorWithRed:0.64 green:0.42 blue:0.08 alpha:1.0];
        _ratingLabel.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.86];
        _ratingLabel.layer.cornerRadius = 13.0;
        _ratingLabel.layer.masksToBounds = YES;
        [self.contentView addSubview:_ratingLabel];

        _shareButton = [self pp_actionButtonWithSystemName:@"square.and.arrow.up" selector:@selector(shareTapped)];
        _favButton = [[FavoriteButton alloc] initWithFrame:CGRectZero];
        [_favButton setTintColor:UIColor.whiteColor];
        UIVisualEffectView *favBlurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
        favBlurView.userInteractionEnabled = NO;
        favBlurView.frame = _favButton.bounds;
        favBlurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        favBlurView.alpha = 0.72;
        [_favButton insertSubview:favBlurView atIndex:0];
        _deleteButton = [self pp_actionButtonWithSystemName:@"trash.fill" selector:@selector(deleteTapped)];
        _deleteButton.hidden = YES;
        _editButton = [self pp_actionButtonWithSystemName:@"square.and.pencil" selector:@selector(editTapped)];
        _editButton.hidden = YES;

        [self.contentView addSubview:_shareButton];
        [self.contentView addSubview:_favButton];
        [self.contentView addSubview:_deleteButton];
        [self.contentView addSubview:_editButton];

        [self setupShadow];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat width = CGRectGetWidth(self.contentView.bounds);
    CGFloat height = CGRectGetHeight(self.contentView.bounds);
    if (width <= 0.0 || height <= 0.0) {
        return;
    }

    BOOL isCompact = width <= 170.0;
    BOOL isRTL = [Language languageVal] != 0;
    CGFloat cornerRadius = width >= 220.0 ? 28.0 : 24.0;
    CGFloat horizontalPadding = isCompact ? 12.0 : 16.0;
    CGFloat buttonPadding = isCompact ? 8.0 : 10.0;
    CGFloat buttonSize = isCompact ? 34.0 : 36.0;
    CGFloat topChromeHeight = isCompact ? 50.0 : 54.0;
    CGFloat bottomChromeHeight = isCompact ? 82.0 : 90.0;
    CGFloat labelHeight = ceil(self.titleLabel.font.lineHeight);
    CGFloat categoryHeight = ceil(self.categoryLabel.font.lineHeight);
    CGFloat priceHeight = ceil(self.priceLabel.font.lineHeight);

    self.contentView.layer.cornerRadius = cornerRadius;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:cornerRadius].CGPath;

    self.imageView.frame = self.contentView.bounds;
    self.topGradientView.frame = CGRectMake(0.0, 0.0, width, topChromeHeight);
    self.bottomGradientView.frame = CGRectMake(0.0, height - bottomChromeHeight, width, bottomChromeHeight);

    CGFloat leadingButtonX = horizontalPadding;
    CGFloat trailingButtonX = width - horizontalPadding - buttonSize;

    if (isRTL) {
        self.shareButton.frame = CGRectMake(leadingButtonX, buttonPadding, buttonSize, buttonSize);
        self.favButton.frame = CGRectMake(trailingButtonX, buttonPadding, buttonSize, buttonSize);
        self.deleteButton.frame = CGRectMake(leadingButtonX, buttonPadding, buttonSize, buttonSize);
        self.editButton.frame = CGRectMake(CGRectGetMaxX(self.deleteButton.frame) + buttonPadding, buttonPadding, buttonSize, buttonSize);
    } else {
        self.shareButton.frame = CGRectMake(leadingButtonX, buttonPadding, buttonSize, buttonSize);
        self.favButton.frame = CGRectMake(trailingButtonX, buttonPadding, buttonSize, buttonSize);
        self.deleteButton.frame = CGRectMake(trailingButtonX, buttonPadding, buttonSize, buttonSize);
        self.editButton.frame = CGRectMake(CGRectGetMinX(self.deleteButton.frame) - buttonPadding - buttonSize, buttonPadding, buttonSize, buttonSize);
    }

    self.titleLabel.textAlignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    self.categoryLabel.textAlignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    self.priceLabel.textAlignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;

    CGFloat statusWidth = MIN(MAX([self.statusLabel.text sizeWithAttributes:@{NSFontAttributeName: self.statusLabel.font}].width + 20.0, 58.0), 96.0);
    CGFloat statusX = width - horizontalPadding - statusWidth;
    self.statusLabel.frame = CGRectMake(statusX, CGRectGetMaxY(self.favButton.frame) + 6.0, statusWidth, 24.0);

    CGFloat ratingWidth = 58.0;
    self.ratingLabel.frame = CGRectMake(horizontalPadding,
                                        height - horizontalPadding - 26.0,
                                        ratingWidth,
                                        26.0);

    CGFloat textWidth = width - (horizontalPadding * 2.0);
    CGFloat priceY = height - horizontalPadding - priceHeight;
    CGFloat categoryY = priceY - 4.0 - categoryHeight;
    CGFloat titleY = categoryY - 4.0 - labelHeight;
    self.titleLabel.frame = CGRectMake(horizontalPadding,
                                       titleY,
                                       textWidth,
                                       labelHeight);
    self.categoryLabel.frame = CGRectMake(horizontalPadding,
                                          categoryY,
                                          textWidth,
                                          categoryHeight);

    CGFloat priceX = self.ratingLabel.hidden ? horizontalPadding : CGRectGetMaxX(self.ratingLabel.frame) + 8.0;
    CGFloat priceWidth = self.ratingLabel.hidden ? textWidth : width - priceX - horizontalPadding;
    self.priceLabel.frame = CGRectMake(priceX,
                                       priceY,
                                       priceWidth,
                                       priceHeight);
}

- (UIButton *)pp_actionButtonWithSystemName:(NSString *)systemName selector:(SEL)selector
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectZero;
    [button setImage:[UIImage systemImageNamed:systemName] forState:UIControlStateNormal];
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    [button setTintColor:UIColor.whiteColor];
    button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];
    button.layer.cornerRadius = 18.0;
    button.layer.masksToBounds = YES;
    return button;
}

- (void)shareTapped {

    if(!UserManager.sharedManager.isUserLoggedIn)
    {
        [UserManager showPromptOnTopController];
        return;
    }

    if ([self.delegate respondsToSelector:@selector(serviceCellDidTapShare:)]) {
        [self.delegate serviceCellDidTapShare:self];
    }
}

- (void)deleteTapped {

    if(!UserManager.sharedManager.isUserLoggedIn)
    {
        [UserManager showPromptOnTopController];
        return;
    }


    if ([self.delegate respondsToSelector:@selector(serviceCellDidTapDelete:)]) {
        [self.delegate serviceCellDidTapDelete:self];
    }
}

- (void)editTapped {

    if(!UserManager.sharedManager.isUserLoggedIn)
    {
        [UserManager showPromptOnTopController];
        return;
    }


    if ([self.delegate respondsToSelector:@selector(serviceCellDidTapEdit:)]) {
        [self.delegate serviceCellDidTapEdit:self];
    }
}

- (void)setupShadow {
    self.contentView.layer.cornerRadius = 25.0;
    self.contentView.layer.masksToBounds = YES;

    [self pp_setShadowColor:[UIColor blackColor]];
    self.layer.shadowOffset = CGSizeMake(0, 2);
    self.layer.shadowRadius = 6.0;
    self.layer.shadowOpacity = 0.15;
    self.layer.masksToBounds = NO;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:25.0].CGPath;
}

- (void)configureWithService:(ServiceModel *)service {
    [GM setImageFromUrlString:service.imageURL imageView:self.imageView phImage:@"placeholder"];
    self.titleLabel.text = service.title;
    self.categoryLabel.text = service.category.length > 0 ? service.category : [service localizedTypeName];
    NSString *currencyCode = service.currency.length > 0 ? service.currency : kLang(@"Rials");
    NSString *priceText = [GM formatPrice:@(service.price) currencyCode:currencyCode];
    self.priceLabel.text = priceText.length > 0 ? priceText : [NSString stringWithFormat:@"%.2f %@", service.price, currencyCode];

    self.statusLabel.text = [service localizedAvailabilityStatus];
    UIColor *statusColor = service.isLive
        ? [UIColor colorWithRed:0.16 green:0.55 blue:0.34 alpha:1.0]
        : [UIColor colorWithRed:0.72 green:0.18 blue:0.22 alpha:1.0];
    self.statusLabel.textColor = statusColor;
    self.statusLabel.backgroundColor = [statusColor colorWithAlphaComponent:0.16];

    BOOL hasRating = [service hasDisplayableRating];
    self.ratingLabel.hidden = !hasRating;
    self.ratingLabel.text = hasRating ? [service localizedRatingBadgeText] : @"";

    self.favButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.24];
    self.favButton.layer.cornerRadius = 18.0;
    self.favButton.layer.masksToBounds = YES;

    self.favButton.adID = service.serviceID ?: @"";
    self.favButton.collection = @"favoritesServices";
    [self.favButton initValue];
    [self setNeedsLayout];
}



- (void)configureWithService:(ServiceModel *)service isUserOwned:(BOOL)isOwned {
    [self configureWithService:service];
    self.isOwnedByUser = isOwned;
    [self updateButtonVisibility];
}


- (void)updateButtonVisibility {
    self.shareButton.hidden = self.isOwnedByUser;
    self.favButton.hidden = self.isOwnedByUser;
    self.deleteButton.hidden = !self.isOwnedByUser;
    self.editButton.hidden = !self.isOwnedByUser;
}





@end
