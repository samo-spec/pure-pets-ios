//
//  OptionTableViewCell 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 13/08/2025.
//


// OptionTableViewCell.m
#import "OptionTableViewCell.h"
#import "OptionModel.h"

@interface OptionTableViewCell ()
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel     *titleLabel;
@property (nonatomic, strong) UILabel     *subtitleLabel;     // NEW
@property (nonatomic, strong) UIStackView *labelsStack;       // NEW
@end

@implementation OptionTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier]) {
        
        // Make the cell itself transparent so backgroundView/selectedBackgroundView show through
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = AppForgroundColr;
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
         
        [Styling applyCornerMaskToView:self tl:30 tr:15 bl:30 br:15];
        [Styling applyCornerMaskToView:self.contentView tl:30 tr:15 bl:30 br:15];
        
        // Icon
        _iconView = [[UIImageView alloc] init];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconView.contentMode = UIViewContentModeScaleAspectFill;
        _iconView.tintColor = AppButtonMixColorClr;
        _iconView.layer.cornerRadius = 6;
        _iconView.clipsToBounds = YES;
        
        // Title
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [GM MidFontWithSize:17];
        _titleLabel.textColor = GM.PrimaryTextColor;
        _titleLabel.numberOfLines = 1;
        _titleLabel.textAlignment = ([Language languageVal] == 0) ? NSTextAlignmentLeft : NSTextAlignmentRight;
        
        // Subtitle
        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subtitleLabel.font = [GM fontWithSize:13];
        _subtitleLabel.textColor = GM.SecondaryTextColor;
        _subtitleLabel.numberOfLines = 0;
        _subtitleLabel.textAlignment = _titleLabel.textAlignment;
        [_subtitleLabel sizeToFit];
        // Stack
        _labelsStack = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _subtitleLabel]];
        _labelsStack.translatesAutoresizingMaskIntoConstraints = NO;
        _labelsStack.axis = UILayoutConstraintAxisVertical;
        _labelsStack.spacing = 2.0;
        
        [self.contentView addSubview:_iconView];
        [self.contentView addSubview:_labelsStack];
        
        CGFloat padding = 16.0;
        CGFloat iconSize = 34.0;
        BOOL isRTL = ([Language languageVal] == 1);
        
        if (isRTL) {
            [NSLayoutConstraint activateConstraints:@[
                [_iconView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
                [_iconView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
                [_iconView.widthAnchor constraintEqualToConstant:iconSize],
                [_iconView.heightAnchor constraintEqualToConstant:iconSize],
                
                [_labelsStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:padding],
                [_labelsStack.trailingAnchor constraintEqualToAnchor:_iconView.leadingAnchor constant:-12],
                [_labelsStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
                [_labelsStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8]
            ]];
        } else {
            [NSLayoutConstraint activateConstraints:@[
                [_iconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:padding],
                [_iconView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
                [_iconView.widthAnchor constraintEqualToConstant:iconSize],
                [_iconView.heightAnchor constraintEqualToConstant:iconSize],
                
                [_labelsStack.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:12],
                [_labelsStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-padding],
                [_labelsStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
                [_labelsStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8]
            ]];
        }
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.subtitleLabel.hidden = YES;
    self.iconView.image = nil;
}

- (void)configureWithOption:(OptionModel *)option {
    
    // Title
    self.titleLabel.text = option.title;
    
    // Subtitle shown only when present & non-empty
    NSString *subtitle = option.subtitle;
    BOOL hasSubtitle = (subtitle.length > 0);
    self.subtitleLabel.text = hasSubtitle ? subtitle : nil;
    self.subtitleLabel.hidden = !hasSubtitle;
    
    // Icon priority: SF Symbol -> Asset image
    UIImage *img = nil;
    if (option.systemImageName.length > 0) {
        if (@available(iOS 13.0, *)) {
            img = [UIImage systemImageNamed:option.systemImageName];
        }
    }
    if (!img && option.imageName.length > 0) {
        img = [UIImage imageNamed:option.imageName];
    }
    self.iconView.image = img;
}

-(void)configureWithAddressTitleModel:(PPAddressModel *)addressTitle
{
    // Title
    self.titleLabel.text = addressTitle.fullName ? PPSafeString(addressTitle.fullName) : PPSafeString(addressTitle.addressLine1);
    self.Address = addressTitle;
    // Subtitle shown only when present & non-empty
    NSString *subtitle = nil;
    BOOL hasSubtitle = (subtitle.length > 0);
    self.subtitleLabel.text = hasSubtitle ? subtitle : nil;
    self.subtitleLabel.hidden = !hasSubtitle;
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    [Styling applyCornerMaskToView:self tl:30 tr:15 bl:30 br:15];
    [Styling applyCornerMaskToView:self.contentView tl:30 tr:15 bl:30 br:15];
}
@end



