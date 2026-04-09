//
//  PPProfileSelectorCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/9/26.
//


#import "PPProfileSelectorCell.h"

@interface PPProfileSelectorCell ()
@property (nonatomic, assign) BOOL pp_didSetupViews;
- (void)pp_commonInit;
@end

@implementation PPProfileSelectorCell

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
    titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    [self.contentView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    UILabel *flagLabel = [[UILabel alloc] init];
    flagLabel.translatesAutoresizingMaskIntoConstraints = NO;
    flagLabel.font = [UIFont systemFontOfSize:18.0];
    flagLabel.textAlignment = NSTextAlignmentCenter;
    [self.contentView addSubview:flagLabel];
    self.flagLabel = flagLabel;

    UILabel *valueLabel = [[UILabel alloc] init];
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.font = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    valueLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    valueLabel.numberOfLines = 2;
    [self.contentView addSubview:valueLabel];
    self.valueLabel = valueLabel;

    UIImageView *chevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down"]];
    chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    chevronView.tintColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.8];
    chevronView.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:chevronView];
    self.chevronView = chevronView;

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [titleLabel.heightAnchor constraintGreaterThanOrEqualToConstant:12.0],
        [chevronView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:10.0],
        [chevronView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [chevronView.widthAnchor constraintEqualToConstant:14.0],
        [chevronView.heightAnchor constraintEqualToConstant:14.0],

        [flagLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [flagLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [flagLabel.widthAnchor constraintEqualToConstant:22.0],
        [flagLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-14.0],

        [valueLabel.leadingAnchor constraintEqualToAnchor:flagLabel.trailingAnchor constant:8.0],
        [valueLabel.centerYAnchor constraintEqualToAnchor:flagLabel.centerYAnchor],
        [valueLabel.trailingAnchor constraintEqualToAnchor:chevronView.leadingAnchor constant:-12.0],
        [valueLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0]
    ]];
}



- (void)configureWithTitle:(NSString *)title
                     value:(NSString *)value
                      flag:(NSString *)flag
{
    self.semanticContentAttribute = PPProfileCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPProfileCurrentSemanticAttribute();
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.valueLabel.text = value ?: @"";
    self.valueLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.flagLabel.text = flag ?: @"";
}

@end
