//
//  PPOptionCell.m
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 24/08/2025.
//


// PPOptionCell.m
#import "PPOptionCell.h"
#import "PPImageLoaderManager.h"
#import "PPModernAvatarRenderer.h"
@implementation PPOptionCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.contentView.backgroundColor=AppBackgroundClrLigter;
        _circleImageView = [[UIImageView alloc] init];
        _circleImageView.translatesAutoresizingMaskIntoConstraints = NO;
        _circleImageView.layer.cornerRadius = 20; // circle (40x40)
        _circleImageView.layer.masksToBounds = YES;
        _circleImageView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_circleImageView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [Styling fontMedium:16];
        _titleLabel.textColor = AppPrimaryTextClr;
        _titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
        [self.contentView addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subtitleLabel.font = [Styling fontRegular:14];
        _subtitleLabel.textColor = AppPrimaryTextClr;
        _subtitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
        _subtitleLabel.numberOfLines = 2;
        [self.contentView addSubview:_subtitleLabel];

        // Layout
        [NSLayoutConstraint activateConstraints:@[
            [_circleImageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:24],
            [_circleImageView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_circleImageView.widthAnchor constraintEqualToConstant:40],
            [_circleImageView.heightAnchor constraintEqualToConstant:40],

            [_titleLabel.leadingAnchor constraintEqualToAnchor:_circleImageView.trailingAnchor constant:12],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_titleLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:-10],

            [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
            [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],

        ]];
    }
    return self;
}

- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle image:(UIImage *)image {
    self.titleLabel.text = title;
    self.subtitleLabel.text = subtitle;

    if (subtitle.length == 0) {
        // No subtitle → center title
        [self.titleLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor].active = YES;
        self.subtitleLabel.hidden = YES;
    } else {
        self.subtitleLabel.hidden = NO;
    }
    
    

    self.circleImageView.image = image ?: [PPModernAvatarRenderer avatarImageForName:title size:40];
}


- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle imageUrl:(NSString *)imageUrl {
    self.titleLabel.text = title;
    self.subtitleLabel.text = subtitle;

    if (subtitle.length == 0) {
        // No subtitle → center title
        [self.titleLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor].active = YES;
        self.subtitleLabel.hidden = YES;
    } else {
        self.subtitleLabel.hidden = NO;
    }
    [PPImageLoaderManager.shared setImageOnImageView:self.circleImageView url:imageUrl placeholder:[PPModernAvatarRenderer avatarImageForName:title size:40] complation:^(UIImage * _Nonnull image,
                                                                                                                                                    NSString * _Nullable urlString) {
        
    }];
   //  [self.circleImageView setImageFromUrl:imageUrl placeholderImage:PPUserPlaceholderImageName]; // person.crop.circle.fill.badge.plus //person.crop.circle.fill
    

    self.circleImageView.tintColor = AppPrimaryClr;
}


- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle imageNamed:(NSString *)imageNamed {
    [self configureWithTitle:title subtitle:subtitle imageNamed:imageNamed useSmallIcon:NO];
}

- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle imageNamed:(NSString *)imageNamed useSmallIcon:(BOOL)useSmallIcon {
    self.titleLabel.text = title;
    self.subtitleLabel.text = subtitle;

    if (subtitle.length == 0) {
        // No subtitle → center title
        [self.titleLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor].active = YES;
        self.subtitleLabel.hidden = YES;
    } else {
        self.subtitleLabel.hidden = NO;
    }
    
    if(imageNamed.length > 0)
    {
        UIImage *iconImage = [UIImage systemImageNamed:imageNamed] ?: [UIImage imageNamed:imageNamed];
        if (useSmallIcon) {
            // Scale down icon to 24x24 for gender selector
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(24, 24), NO, 0.0);
            [iconImage drawInRect:CGRectMake(0, 0, 24, 24)];
            UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            self.circleImageView.image = scaledImage;
            // Adjust circle size for smaller icon
            [NSLayoutConstraint deactivateConstraints:@[
                self.circleImageView.widthAnchor constraintEqualToConstant:40],
                self.circleImageView.heightAnchor constraintEqualToConstant:40
            ]];
            self.circleImageView.widthAnchor.constant = 32;
            self.circleImageView.heightAnchor.constant = 32;
            self.circleImageView.layer.cornerRadius = 16;
        } else {
            self.circleImageView.image = iconImage;
        }
        self.circleImageView.tintColor = AppButtonMixColorClr;
    }
     // person.crop.circle.fill.badge.plus //person.crop.circle.fill
    

    //self.circleImageView.tintColor = AppPrimaryClr;
}
@end



