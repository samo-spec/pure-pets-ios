//
//  PPProfileActionCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/9/26.
//


#import "PPProfileActionCell.h"

@interface PPProfileActionCell ()
@property (nonatomic, assign) BOOL pp_didSetupViews;
@end

@implementation PPProfileActionCell

#pragma mark - Initializers

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self pp_commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self pp_commonInit];
    }
    return self;
}

#pragma mark - Setup

- (void)pp_commonInit
{
    if (self.pp_didSetupViews) {
        return;
    }
    self.pp_didSetupViews = YES;

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.preservesSuperviewLayoutMargins = NO;
    self.contentView.preservesSuperviewLayoutMargins = NO;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    self.semanticContentAttribute = PPProfileCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPProfileCurrentSemanticAttribute();

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:iconView];
    self.iconView = iconView;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    titleLabel.numberOfLines = 1;
    [self.contentView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    [NSLayoutConstraint activateConstraints:@[
        [iconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [iconView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:18.0],
        [iconView.heightAnchor constraintEqualToConstant:18.0],

        [titleLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:10.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:16.0],
        [titleLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-16.0],

        [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:48.0],
    ]];
}

#pragma mark - Reuse

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.iconView.image = nil;
    self.titleLabel.text = nil;
    self.accessibilityIdentifier = nil;
}

#pragma mark - Public

- (void)configureWithTitle:(NSString *)title iconName:(NSString *)iconName
{
    self.semanticContentAttribute = GM.setSemantic;
    self.contentView.semanticContentAttribute =GM.setSemantic;
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.iconView.image = [UIImage systemImageNamed:iconName ?: @"plus"];
}

@end
