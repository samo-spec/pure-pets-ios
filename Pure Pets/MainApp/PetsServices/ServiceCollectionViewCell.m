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
@end

@implementation ServiceCollectionViewCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.width)];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, frame.size.height - 40, frame.size.width - 32, 20)];
        _titleLabel.font = [GM MidFontWithSize:17];
        _titleLabel.textAlignment = [Language languageVal] == 0 ? NSTextAlignmentLeft : NSTextAlignmentRight;
        _titleLabel.numberOfLines = 1;
        _titleLabel.textColor = UIColor.whiteColor;

        _priceLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, frame.size.height - 20, frame.size.width - 32, 15)];
        _priceLabel.font = [GM MidFontWithSize:13];
        _priceLabel.textAlignment = [Language languageVal] == 0 ? NSTextAlignmentLeft : NSTextAlignmentRight;
        _priceLabel.numberOfLines = 1;
        _priceLabel.textColor = UIColor.whiteColor;

        self.contentView.backgroundColor = [UIColor colorWithHexString:@"#FFFFFF"];
        self.contentView.layer.cornerRadius = 25;
        self.contentView.clipsToBounds = YES;

        [self.contentView addSubview:_imageView];
        
        UIView *downView = [[UIView alloc] initWithFrame:CGRectMake(0, frame.size.height - 54, frame.size.width, 54)];
        [AppClasses gardToView:downView colorOne:[UIColor hx_colorWithHexStr:@"#000" alpha:0.0] colorTwo:[UIColor hx_colorWithHexStr:@"#000" alpha:0.3] colorThree:[UIColor hx_colorWithHexStr:@"#000" alpha:0.7] rds:0];
        [self.contentView addSubview:downView];
        
        [self.contentView addSubview:_titleLabel];
        [self.contentView addSubview:_priceLabel];

        CGFloat buttonSize = 32;
        CGFloat padding = 6;

        UIView *downView2 = [[UIView alloc] initWithFrame:CGRectMake(0, frame.size.height - 54, frame.size.width, 54)];
        [AppClasses gardToView:downView2 colorOne:[UIColor hx_colorWithHexStr:@"#000" alpha:0.7] colorTwo:[UIColor hx_colorWithHexStr:@"#000" alpha:0.3] colorThree:[UIColor hx_colorWithHexStr:@"#000" alpha:0] rds:0];
        //[self.contentView addSubview:downView2];
        
        
        UIView *upView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 54)];
        [AppClasses gardToView:upView colorOne:[UIColor hx_colorWithHexStr:@"#000" alpha:0.7] colorTwo:[UIColor hx_colorWithHexStr:@"#000" alpha:0.3] colorThree:[UIColor hx_colorWithHexStr:@"#000" alpha:0] rds:0];
        [self.contentView addSubview:upView];

        _shareButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _shareButton.frame = CGRectMake(padding, padding, buttonSize, buttonSize);
        [_shareButton setImage:[UIImage systemImageNamed:@"square.and.arrow.up"] forState:UIControlStateNormal];
        [_shareButton addTarget:self action:@selector(shareTapped) forControlEvents:UIControlEventTouchUpInside];
        [_shareButton setTintColor:UIColor.whiteColor];

        _favButton = [[FavoriteButton alloc] initWithFrame:CGRectMake(CGRectGetMaxX(_shareButton.frame) + padding, padding, buttonSize, buttonSize)];
        [_favButton setTintColor:UIColor.whiteColor];

        _deleteButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _deleteButton.frame = CGRectMake(self.contentView.hx_w - padding - buttonSize, padding, buttonSize, buttonSize);
        [_deleteButton setImage:[UIImage systemImageNamed:@"trash.fill"] forState:UIControlStateNormal];
        [_deleteButton addTarget:self action:@selector(deleteTapped) forControlEvents:UIControlEventTouchUpInside];
        [_deleteButton setTintColor:UIColor.whiteColor];
        _deleteButton.hidden = YES;

        _editButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _editButton.frame = CGRectMake(self.deleteButton.hx_x - padding - buttonSize, padding, buttonSize, buttonSize);
        [_editButton setImage:[UIImage systemImageNamed:@"square.and.pencil"] forState:UIControlStateNormal];
        [_editButton addTarget:self action:@selector(editTapped) forControlEvents:UIControlEventTouchUpInside];
        [_editButton setTintColor:UIColor.whiteColor];
        _editButton.hidden = YES;

        [self.contentView addSubview:_shareButton];
        [self.contentView addSubview:_favButton];
        [self.contentView addSubview:_deleteButton];
        [self.contentView addSubview:_editButton];

        [self setupShadow];
    }
    return self;
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

    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOffset = CGSizeMake(0, 2);
    self.layer.shadowRadius = 6.0;
    self.layer.shadowOpacity = 0.15;
    self.layer.masksToBounds = NO;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:8.0].CGPath;
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

    // Create edit button if needed
    if (self.isOwnedByUser && !_editButton) {
        CGFloat padding = 6;
        CGFloat buttonSize = 32;
        _editButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _editButton.frame = CGRectMake(CGRectGetMaxX(_deleteButton.frame) + padding, padding, buttonSize, buttonSize);
        [_editButton setImage:[UIImage systemImageNamed:@"square.and.pencil"] forState:UIControlStateNormal];
        [_editButton setTintColor:UIColor.whiteColor];
        [_editButton addTarget:self action:@selector(editTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_editButton];
    }

    if (_editButton) {
        _editButton.hidden = !self.isOwnedByUser;
    }
}






@end
