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
        _titleLabel.font = [GM MidFontWithSize:17];
        _titleLabel.numberOfLines = 1;
        _titleLabel.textColor = UIColor.whiteColor;
        _titleLabel.adjustsFontSizeToFitWidth = YES;
        _titleLabel.minimumScaleFactor = 0.82;
        [self.contentView addSubview:_titleLabel];

        _priceLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _priceLabel.font = [GM MidFontWithSize:13];
        _priceLabel.numberOfLines = 1;
        _priceLabel.textColor = UIColor.whiteColor;
        _priceLabel.adjustsFontSizeToFitWidth = YES;
        _priceLabel.minimumScaleFactor = 0.88;
        [self.contentView addSubview:_priceLabel];

        _shareButton = [self pp_actionButtonWithSystemName:@"square.and.arrow.up" selector:@selector(shareTapped)];
        _favButton = [[FavoriteButton alloc] initWithFrame:CGRectZero];
        [_favButton setTintColor:UIColor.whiteColor];
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
    CGFloat buttonSize = isCompact ? 30.0 : 32.0;
    CGFloat topChromeHeight = isCompact ? 50.0 : 54.0;
    CGFloat bottomChromeHeight = isCompact ? 62.0 : 68.0;
    CGFloat labelHeight = ceil(self.titleLabel.font.lineHeight);
    CGFloat priceHeight = ceil(self.priceLabel.font.lineHeight);

    self.contentView.layer.cornerRadius = cornerRadius;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:cornerRadius].CGPath;

    self.imageView.frame = self.contentView.bounds;
    self.topGradientView.frame = CGRectMake(0.0, 0.0, width, topChromeHeight);
    self.bottomGradientView.frame = CGRectMake(0.0, height - bottomChromeHeight, width, bottomChromeHeight);

    CGFloat leadingButtonX = horizontalPadding;
    CGFloat trailingButtonX = width - horizontalPadding - buttonSize;

    if (isRTL) {
        self.shareButton.frame = CGRectMake(trailingButtonX, buttonPadding, buttonSize, buttonSize);
        self.favButton.frame = CGRectMake(CGRectGetMinX(self.shareButton.frame) - buttonPadding - buttonSize, buttonPadding, buttonSize, buttonSize);
        self.deleteButton.frame = CGRectMake(leadingButtonX, buttonPadding, buttonSize, buttonSize);
        self.editButton.frame = CGRectMake(CGRectGetMaxX(self.deleteButton.frame) + buttonPadding, buttonPadding, buttonSize, buttonSize);
    } else {
        self.shareButton.frame = CGRectMake(leadingButtonX, buttonPadding, buttonSize, buttonSize);
        self.favButton.frame = CGRectMake(CGRectGetMaxX(self.shareButton.frame) + buttonPadding, buttonPadding, buttonSize, buttonSize);
        self.deleteButton.frame = CGRectMake(trailingButtonX, buttonPadding, buttonSize, buttonSize);
        self.editButton.frame = CGRectMake(CGRectGetMinX(self.deleteButton.frame) - buttonPadding - buttonSize, buttonPadding, buttonSize, buttonSize);
    }

    self.titleLabel.textAlignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    self.priceLabel.textAlignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;

    CGFloat titleY = height - horizontalPadding - priceHeight - 4.0 - labelHeight;
    self.titleLabel.frame = CGRectMake(horizontalPadding,
                                       titleY,
                                       width - (horizontalPadding * 2.0),
                                       labelHeight);
    self.priceLabel.frame = CGRectMake(horizontalPadding,
                                       CGRectGetMaxY(self.titleLabel.frame) + 4.0,
                                       width - (horizontalPadding * 2.0),
                                       priceHeight);
}

- (UIButton *)pp_actionButtonWithSystemName:(NSString *)systemName selector:(SEL)selector
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectZero;
    [button setImage:[UIImage systemImageNamed:systemName] forState:UIControlStateNormal];
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    [button setTintColor:UIColor.whiteColor];
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
    self.priceLabel.text = [NSString stringWithFormat:@"%.2f", service.price];

    self.favButton.adID = service.serviceID ?: @"";
    self.favButton.collection = @"favoritesServices";
    [self.favButton initValue];
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
