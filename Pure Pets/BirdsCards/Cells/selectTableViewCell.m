//
//  selectTableViewCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 26/07/2024.
//

#import "selectTableViewCell.h"
#import "PrefixHeader.pch"

@implementation selectTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor clearColor];
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    _containerView = [[UIView alloc] init];
    _containerView.backgroundColor = AppForgroundColr;
    _containerView.layer.cornerRadius = 16;
    [_containerView pp_setShadowColor:[UIColor blackColor]];
    _containerView.layer.shadowOffset = CGSizeMake(0, 2);
    _containerView.layer.shadowRadius = 4;
    _containerView.layer.shadowOpacity = 0.05;
    _containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_containerView];

    _mainImageView = [[UIImageView alloc] init];
    _mainImageView.contentMode = UIViewContentModeScaleAspectFill;
    _mainImageView.clipsToBounds = YES;
    _mainImageView.layer.cornerRadius = 12;
    _mainImageView.backgroundColor = AppBackgroundClrLigter;
    _mainImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [_containerView addSubview:_mainImageView];

    _birdIdLabel = [[UILabel alloc] init];
    _birdIdLabel.font = [GM boldFontWithSize:16];
    _birdIdLabel.textColor = [UIColor labelColor];
    _birdIdLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_containerView addSubview:_birdIdLabel];

    _attributeLabel = [[UILabel alloc] init];
    _attributeLabel.font = [GM MidFontWithSize:13];
    _attributeLabel.textColor = [UIColor secondaryLabelColor];
    _attributeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_containerView addSubview:_attributeLabel];

    _classificationLabel = [[UILabel alloc] init];
    _classificationLabel.font = [GM MidFontWithSize:12];
    _classificationLabel.textColor = [UIColor tertiaryLabelColor];
    _classificationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _classificationLabel.hidden = YES;
    [_containerView addSubview:_classificationLabel];

    _sexualImageView = [[UIImageView alloc] init];
    _sexualImageView.contentMode = UIViewContentModeScaleAspectFit;
    _sexualImageView.tintColor = AppBackgroundClr;
    _sexualImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [_containerView addSubview:_sexualImageView];

    _sexualLabel = [[UILabel alloc] init];
    _sexualLabel.font = [GM MidFontWithSize:12];
    _sexualLabel.textColor = [UIColor tertiaryLabelColor];
    _sexualLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_containerView addSubview:_sexualLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_containerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [_containerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [_containerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [_containerView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],

        [_mainImageView.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor constant:12],
        [_mainImageView.centerYAnchor constraintEqualToAnchor:_containerView.centerYAnchor],
        [_mainImageView.widthAnchor constraintEqualToConstant:60],
        [_mainImageView.heightAnchor constraintEqualToConstant:60],

        [_birdIdLabel.topAnchor constraintEqualToAnchor:_containerView.topAnchor constant:12],
        [_birdIdLabel.leadingAnchor constraintEqualToAnchor:_mainImageView.trailingAnchor constant:12],
        [_birdIdLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_sexualImageView.leadingAnchor constant:-8],

        [_attributeLabel.topAnchor constraintEqualToAnchor:_birdIdLabel.bottomAnchor constant:4],
        [_attributeLabel.leadingAnchor constraintEqualToAnchor:_birdIdLabel.leadingAnchor],
        [_attributeLabel.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor constant:-12],

        [_classificationLabel.topAnchor constraintEqualToAnchor:_attributeLabel.bottomAnchor constant:2],
        [_classificationLabel.leadingAnchor constraintEqualToAnchor:_attributeLabel.leadingAnchor],
        [_classificationLabel.trailingAnchor constraintEqualToAnchor:_attributeLabel.trailingAnchor],

        [_sexualImageView.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor constant:-12],
        [_sexualImageView.topAnchor constraintEqualToAnchor:_containerView.topAnchor constant:12],
        [_sexualImageView.widthAnchor constraintEqualToConstant:20],
        [_sexualImageView.heightAnchor constraintEqualToConstant:20],

        [_sexualLabel.centerYAnchor constraintEqualToAnchor:_sexualImageView.centerYAnchor],
        [_sexualLabel.trailingAnchor constraintEqualToAnchor:_sexualImageView.leadingAnchor constant:-4]
    ]];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    if (selected) {
        _containerView.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.1];
    } else {
        _containerView.backgroundColor = AppForgroundColr;
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.birdIdLabel.text = nil;
    self.attributeLabel.text = nil;
    self.classificationLabel.text = nil;
    self.classificationLabel.hidden = YES;
    self.sexualLabel.text = nil;
    self.sexualImageView.image = nil;
    self.mainImageView.image = [UIImage imageNamed:@"placeholder"];
    self.mainImageView.layer.borderWidth = 0.0;
    [self.mainImageView pp_setBorderColor:UIColor.clearColor];
    self.containerView.backgroundColor = AppForgroundColr;
    self.userInteractionEnabled = YES;
    self.contentView.alpha = 1.0;
}

@end
