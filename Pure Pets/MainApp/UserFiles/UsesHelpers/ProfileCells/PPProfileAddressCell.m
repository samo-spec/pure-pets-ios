//
//  PPProfileAddressCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/9/26.
//



#import "PPProfileAddressCell.h"

@interface PPProfileAddressCell ()
@property (nonatomic, assign) BOOL pp_didSetupViews;
- (void)pp_commonInit;
@end

@implementation PPProfileAddressCell

- (instancetype)init
{
    return [self initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) {
        return nil;
    }

    [self pp_commonInit];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self) {
        return nil;
    }

    [self pp_commonInit];
    return self;
}

- (void)pp_commonInit
{
    if (self.pp_didSetupViews) {
        return;
    }
    self.pp_didSetupViews = YES;

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = PPProfileCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPProfileCurrentSemanticAttribute();

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.numberOfLines = 1;
    [self.contentView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    UILabel *badgeLabel = [[UILabel alloc] init];
    badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    badgeLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    badgeLabel.textColor = UIColor.whiteColor;
    badgeLabel.backgroundColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    badgeLabel.textAlignment = NSTextAlignmentCenter;
    badgeLabel.layer.cornerRadius = 10.0;
    badgeLabel.layer.masksToBounds = YES;
    badgeLabel.text = kLang(@"Default");
    [self.contentView addSubview:badgeLabel];
    self.badgeLabel = badgeLabel;

    UILabel *detailLabel = [[UILabel alloc] init];
    detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    detailLabel.font = [GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightRegular];
    detailLabel.textColor = [UIColor secondaryLabelColor];
    detailLabel.numberOfLines = 0;
    [self.contentView addSubview:detailLabel];
    self.detailLabel = detailLabel;

    UIImageView *chevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:PPProfileForwardChevronSymbolName()]];
    chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    chevronView.tintColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.75];
    chevronView.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:chevronView];
    self.chevronView = chevronView;

    [NSLayoutConstraint activateConstraints:@[
        [chevronView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [chevronView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [chevronView.widthAnchor constraintEqualToConstant:14.0],
        [chevronView.heightAnchor constraintEqualToConstant:14.0],

        [titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:badgeLabel.leadingAnchor constant:-8.0],
        [titleLabel.heightAnchor constraintGreaterThanOrEqualToConstant:12.0],
        
        [badgeLabel.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor],
        [badgeLabel.trailingAnchor constraintEqualToAnchor:chevronView.leadingAnchor constant:-10.0],
        [badgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:54.0],
        [badgeLabel.heightAnchor constraintEqualToConstant:20.0],

        [detailLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [detailLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [detailLabel.trailingAnchor constraintEqualToAnchor:chevronView.leadingAnchor constant:-10.0],
        [detailLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0]
    ]];
}

- (void)configureWithAddress:(PPAddressModel *)address
{
    self.semanticContentAttribute = PPProfileCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPProfileCurrentSemanticAttribute();
    NSString *title = address.fullName.length > 0 ? address.fullName : (address.locatioName.length > 0 ? address.locatioName : kLang(@"Shipping Addresses"));
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.detailLabel.text = address.displayName ?: @"";
    self.detailLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.badgeLabel.hidden = !address.isDefault;
    self.titleLabel.textColor = address.isDefault ? (AppPrimaryClr ?: UIColor.labelColor) : (AppPrimaryTextClr ?: UIColor.labelColor);
    self.chevronView.image = [UIImage systemImageNamed:PPProfileForwardChevronSymbolName()];
}

@end
