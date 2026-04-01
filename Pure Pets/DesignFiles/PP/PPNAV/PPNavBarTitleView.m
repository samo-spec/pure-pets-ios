//
//  PPNavBarTitleView 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 06/01/2026.
//


#import "PPNavBarTitleView.h"
 
@interface PPNavBarTitleView ()
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIStackView *textStack;
@property (nonatomic, strong) UIStackView *rootStack;
@end

@implementation PPNavBarTitleView

- (instancetype)initWithTitle:(NSString *)title
                      subtitle:(NSString *)subtitle
                          icon:(UIImage *)icon 
{
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;

    _blurStyle = UIBlurEffectStyleSystemChromeMaterial;
    _maxWidth  = 240;

    [self buildUI];
    [self updateTitle:title subtitle:subtitle icon:icon];

    return self;
}

#pragma mark - UI

- (void)buildUI
{
    self.translatesAutoresizingMaskIntoConstraints = NO;

    // 🔹 Blur background
    self.blurView =
    [[UIVisualEffectView alloc]
     initWithEffect:[UIBlurEffect effectWithStyle:self.blurStyle]];
    self.blurView.translatesAutoresizingMaskIntoConstraints = NO;
    self.blurView.layer.cornerRadius = 16;
    self.blurView.clipsToBounds = YES;

    // 🔹 Icon
    self.iconView = [UIImageView new];
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconView.contentMode = UIViewContentModeScaleAspectFill;
    self.iconView.clipsToBounds = YES;
    self.iconView.tintColor = AppPrimaryTextClr;
    [self.iconView setContentHuggingPriority:UILayoutPriorityRequired
                                     forAxis:UILayoutConstraintAxisHorizontal];

    // 🔹 Title
    self.titleLabel = [UILabel new];
    self.titleLabel.font = [GM boldFontWithSize:17];
    self.titleLabel.textColor = AppPrimaryTextClr;
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;

    // 🔹 Subtitle
    self.subtitleLabel = [UILabel new];
    self.subtitleLabel.font = [GM MidFontWithSize:13];
    self.subtitleLabel.textColor = AppSecondaryTextClr;
    self.subtitleLabel.numberOfLines = 1;
    self.subtitleLabel.textAlignment = NSTextAlignmentCenter;

    // 🔹 Text stack (vertical)
    self.textStack =
    [[UIStackView alloc] initWithArrangedSubviews:@[
        self.titleLabel,
        self.subtitleLabel
    ]];
    self.textStack.axis = UILayoutConstraintAxisVertical;
    self.textStack.spacing = 2;
    self.textStack.alignment = UIStackViewAlignmentCenter;

    // 🔹 Root stack (horizontal)
    self.rootStack =
    [[UIStackView alloc] initWithArrangedSubviews:@[
        self.iconView,
        self.textStack
    ]];
    self.rootStack.axis = UILayoutConstraintAxisHorizontal;
    self.rootStack.spacing = 8;
    self.rootStack.alignment = UIStackViewAlignmentCenter;
    self.rootStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.blurView.alpha = 0;
    [self addSubview:self.blurView];
    [self addSubview:self.rootStack];
    [self.heightAnchor constraintGreaterThanOrEqualToConstant:36].active = YES;
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        // Blur fills self
        [self.blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],

        // Root stack padding
        [self.rootStack.topAnchor constraintEqualToAnchor:self.blurView.contentView.topAnchor constant:6],
        [self.rootStack.bottomAnchor constraintEqualToAnchor:self.blurView.contentView.bottomAnchor constant:-6],
        [self.rootStack.leadingAnchor constraintEqualToAnchor:self.blurView.contentView.leadingAnchor constant:12],
        [self.rootStack.trailingAnchor constraintEqualToAnchor:self.blurView.contentView.trailingAnchor constant:-12],

        // Icon size
        [self.iconView.widthAnchor constraintEqualToConstant:18],
        [self.iconView.heightAnchor constraintEqualToConstant:18],

        // Max width safety
        [self.widthAnchor constraintLessThanOrEqualToConstant:self.maxWidth],
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:36]
    ]];

    // RTL / LTR support
    self.semanticContentAttribute = UISemanticContentAttributeUnspecified;
}

#pragma mark - Public

- (instancetype)initWithTitle:(nullable NSString *)title
                      subtitle:(nullable NSString *)subtitle
                          icon:(nullable UIImage *)icon
                ppIconPostion:(NSInteger)ppIconPostion 
{
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;

    _blurStyle   = UIBlurEffectStyleSystemChromeMaterial;
    _maxWidth    = 240;
    _ppIconPostion = ppIconPostion;

    [self buildUI];
    [self updateTitle:title subtitle:subtitle icon:icon];

    return self;
}

#pragma mark - Intrinsic Size

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(UIViewNoIntrinsicMetric, UIViewNoIntrinsicMetric);
}



#pragma mark - Public

- (void)updateTitle:(NSString *)title
           subtitle:(NSString *)subtitle
               icon:(UIImage *)icon
{
    self.titleLabel.text = title;

    // Subtitle
    BOOL hasSubtitle = (subtitle.length > 0);
    self.subtitleLabel.text = subtitle;
    self.subtitleLabel.hidden = !hasSubtitle;

    // Icon
    if (icon) {
        self.iconView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.iconView.hidden = NO;
    } else {
        self.iconView.hidden = YES;
    }

    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
}

@end
