//
//  TitleSubtitleCell 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 15/08/2025.
//


#import "TitleSubtitleCell.h"
#import "GM.h"

@interface TitleSubtitleCell ()
@property (nonatomic, strong) UILabel *titleLabel_;
@property (nonatomic, strong) UILabel *subtitleLabel_;
@end

@implementation TitleSubtitleCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier]) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.contentView.backgroundColor = UIColor.clearColor;

        _titleLabel_ = [UILabel new];
        _titleLabel_.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel_.font = [GM boldFontWithSize:20];
        _titleLabel_.textColor = GM.PrimaryTextColor;
        _titleLabel_.numberOfLines = 0;

        _subtitleLabel_ = [UILabel new];
        _subtitleLabel_.translatesAutoresizingMaskIntoConstraints = NO;
        _subtitleLabel_.font = [GM MidFontWithSize:16];
        _subtitleLabel_.textColor = GM.SecondaryTextColor;
        _subtitleLabel_.numberOfLines = 0;

        UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel_, _subtitleLabel_]];
        stack.axis = UILayoutConstraintAxisVertical;
        stack.spacing = 4;
        stack.translatesAutoresizingMaskIntoConstraints = NO;

        [self.contentView addSubview:stack];
        CGFloat pad = 0;
        [NSLayoutConstraint activateConstraints:@[
            [stack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:pad],
            [stack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-pad],
            [stack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
            [stack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],
        ]];
    }
    return self;
}

- (UILabel *)titleLabel   { return _titleLabel_; }
- (UILabel *)subtitleLabel{ return _subtitleLabel_; }

@end
