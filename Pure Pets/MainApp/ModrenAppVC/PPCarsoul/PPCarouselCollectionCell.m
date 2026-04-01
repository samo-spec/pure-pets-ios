//
//  PPCarouselCollectionCell 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 27/12/2025.
//


#import "PPCarouselCollectionCell.h"
#import "PPCarouselItem.h"
#import "GM.h" // fonts/colors

@interface PPCarouselCollectionCell()

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIView *overlayView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;

@end

@implementation PPCarouselCollectionCell

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.contentView.layer.masksToBounds = YES;
        self.layer.cornerRadius = PPCornersHome;
        
        
        
        _imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _imageView.translatesAutoresizingMaskIntoConstraints = NO;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        [self.contentView addSubview:_imageView];

        _overlayView = [UIView new];
        _overlayView.translatesAutoresizingMaskIntoConstraints = NO;
        _overlayView.backgroundColor = UIColor.clearColor;
        [self.contentView addSubview:_overlayView];

        _titleLabel = [UILabel new];
        _titleLabel.font = [GM boldFontWithSize:16];
        _titleLabel.textColor = UIColor.whiteColor;
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_overlayView addSubview:_titleLabel];

        _subtitleLabel = [UILabel new];
        _subtitleLabel.font = [GM MidFontWithSize:14];
        _subtitleLabel.textColor = UIColor.whiteColor;
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_overlayView addSubview:_subtitleLabel];

        [NSLayoutConstraint activateConstraints:@[
            [self.imageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [self.imageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [self.imageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [self.imageView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

            [self.overlayView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [self.overlayView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [self.overlayView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],

            [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.overlayView.leadingAnchor],
            [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.overlayView.trailingAnchor],
            [self.titleLabel.topAnchor constraintEqualToAnchor:self.overlayView.topAnchor],

            [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
            [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
            [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
        ]];
    }
    return self;
}

- (void)configureWithCarouselItem:(PPCarouselItem *)item {
    _titleLabel.text = item.title ?: @"";
    _subtitleLabel.text = item.subtitle ?: @"";
    [GM pp_setImageURL:item.imageURL imageView:self.imageView placeholder: @"placeholder"];
}

@end
