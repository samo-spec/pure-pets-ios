//
//  PPPetsTitleView.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 14/01/2026.
//


#import "PPPetsTitleView.h"
#import "PPInfoPillsView.h"

@interface PPPetsTitleView ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *locationLabel;
@property (nonatomic, strong) UIStackView *textStack;
@property (nonatomic, strong) UIStackView *metaPillsStack;

@property (nonatomic, strong) UIView *priceView;
@property (nonatomic, assign) BOOL isFavorite;

@property (nonatomic, assign) BOOL didAnimate;
@property (nonatomic, strong) NSLayoutConstraint *textTrailingConstraint;
@end

@implementation PPPetsTitleView
 

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self setupView];
    }
    return self;
}



#pragma mark - Setup

- (void)setupView
{
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.semanticContentAttribute = GM.setSemantic;

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [GM boldFontWithSize:18];
    self.titleLabel.textColor = UIColor.labelColor;
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.titleLabel.textAlignment = GM.setAligment;

    self.locationLabel = [[UILabel alloc] init];
    self.locationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationLabel.font = [GM MidFontWithSize:14];
    self.locationLabel.textColor = UIColor.secondaryLabelColor;
    self.locationLabel.numberOfLines = 1;
    self.locationLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.locationLabel.adjustsFontForContentSizeCategory = YES;
    self.locationLabel.textAlignment = GM.setAligment;

    [self.titleLabel.heightAnchor constraintEqualToConstant:22].active = YES;
    [self.locationLabel.heightAnchor constraintEqualToConstant:22].active = YES;

    self.metaPillsStack = [[UIStackView alloc] init];
    self.metaPillsStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.metaPillsStack.axis = UILayoutConstraintAxisHorizontal;
    self.metaPillsStack.spacing = 8;
    self.metaPillsStack.alignment = UIStackViewAlignmentCenter;
    self.metaPillsStack.distribution = UIStackViewDistributionFillProportionally;
    self.metaPillsStack.hidden = YES;

    self.textStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.titleLabel,
        self.locationLabel,
        self.metaPillsStack
    ]];
    self.textStack.axis = UILayoutConstraintAxisVertical;
    self.textStack.spacing = 6;
    self.textStack.alignment = UIStackViewAlignmentFill;
    self.textStack.distribution = UIStackViewDistributionFill;
    self.textStack.translatesAutoresizingMaskIntoConstraints = NO;

    [self addSubview:self.textStack];

    self.textTrailingConstraint =
        [self.textStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-16];

    [NSLayoutConstraint activateConstraints:@[
        [self.textStack.topAnchor constraintEqualToAnchor:self.topAnchor constant:10],
        [self.textStack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        self.textTrailingConstraint,
        [self.textStack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-10],
        [self.metaPillsStack.heightAnchor constraintGreaterThanOrEqualToConstant:24]
    ]];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [Styling applyCornerMaskToView:self.priceView tl:28 tr:12 bl:28 br:28];
}

#pragma mark - Public API

- (void)configureWithTitle:(NSString *)title
                  location:(nullable NSString *)location
                     price:(nullable NSString *)price
{
    self.title = title;
    self.location = location;
    self.price = price;

    [self.priceView removeFromSuperview];
    self.priceView = [self pillViewForItem:[PPInfoPill itemWithIcon:nil text:price ?: @""]];
    [self addSubview:self.priceView];

    [NSLayoutConstraint activateConstraints:@[
        [self.priceView.topAnchor constraintEqualToAnchor:self.topAnchor constant:6],
        [self.priceView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-6],
        [self.priceView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-4],
        [self.priceView.widthAnchor constraintEqualToConstant:120]
    ]];

    self.textTrailingConstraint.active = NO;
    self.textTrailingConstraint =
        [self.textStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.priceView.leadingAnchor constant:-12];
    self.textTrailingConstraint.active = YES;
}

- (void)updateMetaPillsWithItems:(NSArray<PPInfoPill *> *)items
{
    for (UIView *view in self.metaPillsStack.arrangedSubviews) {
        [self.metaPillsStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    NSMutableArray<PPInfoPill *> *filtered = [NSMutableArray array];
    for (PPInfoPill *item in items) {
        if (item.text.length > 0) {
            [filtered addObject:item];
        }
    }

    self.metaPillsStack.hidden = filtered.count == 0;
    if (filtered.count == 0) {
        return;
    }

    for (PPInfoPill *item in filtered) {
        [self.metaPillsStack addArrangedSubview:[self metaBadgeViewForItem:item]];
    }

    [self animatePillsIn];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];

    if (!self.window || self.didAnimate) return;
    self.didAnimate = YES;
}

- (void)animatePillsIn
{
    NSTimeInterval baseDelay = 0.20;

    [UIView animateWithDuration:0.45
                          delay:baseDelay
         usingSpringWithDamping:0.85
          initialSpringVelocity:0.6
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.priceView.alpha = 1.0;
        self.priceView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [self.metaPillsStack.arrangedSubviews enumerateObjectsUsingBlock:^(UIView *badge, NSUInteger idx, BOOL *stop) {
        [UIView animateWithDuration:0.35
                              delay:0.08 + (0.05 * idx)
             usingSpringWithDamping:0.9
              initialSpringVelocity:0.6
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            badge.alpha = 1.0;
            badge.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

#pragma mark - Badge Builders

- (UIView *)pillViewForItem:(PPInfoPill *)item
{
    UIView *pill = [[UIView alloc] init];
    pill.backgroundColor = UIColor.systemGray6Color;
    pill.translatesAutoresizingMaskIntoConstraints = NO;
    pill.alpha = 0.0;
    pill.transform = CGAffineTransformMakeTranslation(0, 10);

    UIImageView *icon = [[UIImageView alloc] initWithImage:PPImage(item.iconName)];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *label = [[UILabel alloc] init];
    label.text = item.text;
    label.textColor = UIColor.labelColor;
    label.font = [GM boldFontWithSize:18];
    label.numberOfLines = 1;
    label.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *requirelabel = [[UILabel alloc] init];
    requirelabel.text = kLang(@"Required");
    requirelabel.textColor = UIColor.secondaryLabelColor;
    requirelabel.font = [GM MidFontWithSize:12];
    requirelabel.numberOfLines = 1;
    requirelabel.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[requirelabel, label]];
    content.axis = UILayoutConstraintAxisVertical;
    content.spacing = 2;
    content.alignment = UIStackViewAlignmentCenter;
    content.translatesAutoresizingMaskIntoConstraints = NO;

    [pill addSubview:content];

    [NSLayoutConstraint activateConstraints:@[
        [icon.widthAnchor constraintEqualToConstant:22],
        [icon.heightAnchor constraintEqualToConstant:22],
        [label.heightAnchor constraintEqualToConstant:20],
        [content.centerXAnchor constraintEqualToAnchor:pill.centerXAnchor],
        [content.bottomAnchor constraintEqualToAnchor:pill.bottomAnchor constant:-8],
        [content.topAnchor constraintEqualToAnchor:pill.topAnchor constant:8],
        [content.leadingAnchor constraintGreaterThanOrEqualToAnchor:pill.leadingAnchor constant:4],
        [content.trailingAnchor constraintLessThanOrEqualToAnchor:pill.trailingAnchor constant:-4],
    ]];

    UIColor *tint = [UIColor colorWithRed:0.65 green:0.85 blue:0.70 alpha:1.0];
    pill.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    icon.tintColor = [tint colorWithAlphaComponent:1.2];
    label.textColor = UIColor.labelColor;

    if ([item.iconName isEqualToString:@"dollarsColors"]) {
        pill.accessibilityIdentifier = @"pricePill";
    }

    pill.layer.cornerCurve = kCACornerCurveContinuous;
    pill.clipsToBounds = YES;

    return pill;
}

- (UIView *)metaBadgeViewForItem:(PPInfoPill *)item
{
    UIView *badge = [[UIView alloc] init];
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.alpha = 0.0;
    badge.transform = CGAffineTransformMakeTranslation(0, 8);
    badge.layer.cornerRadius = 12;
    badge.layer.cornerCurve = kCACornerCurveContinuous;
    badge.clipsToBounds = YES;

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:item.iconName ?: @"circle.fill"]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = item.text;
    label.font = [GM MidFontWithSize:13];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = UIColor.labelColor;
    label.numberOfLines = 1;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[icon, label]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 6;
    stack.alignment = UIStackViewAlignmentCenter;

    [badge addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [icon.widthAnchor constraintEqualToConstant:14],
        [icon.heightAnchor constraintEqualToConstant:14],
        [stack.topAnchor constraintEqualToAnchor:badge.topAnchor constant:5],
        [stack.bottomAnchor constraintEqualToAnchor:badge.bottomAnchor constant:-5],
        [stack.leadingAnchor constraintEqualToAnchor:badge.leadingAnchor constant:9],
        [stack.trailingAnchor constraintEqualToAnchor:badge.trailingAnchor constant:-9],
    ]];

    UIColor *tint = UIColor.secondaryLabelColor;
    if ([item.iconName isEqualToString:@"figure.dress.line.vertical.figure"]) {
        tint = [UIColor colorWithRed:0.45 green:0.65 blue:0.95 alpha:1.0];
    } else if ([item.iconName isEqualToString:@"clock"]) {
        tint = [UIColor colorWithRed:0.95 green:0.75 blue:0.45 alpha:1.0];
    } else if ([item.iconName isEqualToString:@"pawprint.fill"]) {
        tint = [UIColor colorWithRed:0.55 green:0.75 blue:0.55 alpha:1.0];
    }

    badge.backgroundColor = [tint colorWithAlphaComponent:0.16];
    badge.layer.borderWidth = 0.5;
    badge.layer.borderColor = [tint colorWithAlphaComponent:0.24].CGColor;
    icon.tintColor = tint;

    return badge;
}

#pragma mark - Setters

- (void)setTitle:(NSString *)title
{
    _title = [title copy];
    self.titleLabel.text = _title;
}

- (void)setLocation:(NSString *)location
{
    _location = [location copy];

    if (_location.length == 0) {
        self.locationLabel.attributedText = nil;
        self.locationLabel.hidden = YES;
        return;
    }

    self.locationLabel.hidden = NO;

    UIImageSymbolConfiguration *symbolConfig =
    [UIImageSymbolConfiguration configurationWithPointSize:self.locationLabel.font.pointSize
                                                    weight:UIImageSymbolWeightRegular];

    UIImage *pinImage =
    [[UIImage systemImageNamed:@"mappin.and.ellipse"] imageWithConfiguration:symbolConfig];

    pinImage = [pinImage imageWithTintColor:UIColor.secondaryLabelColor
                              renderingMode:UIImageRenderingModeAlwaysOriginal];

    NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
    attachment.image = pinImage;

    CGFloat yOffset = (self.locationLabel.font.capHeight - pinImage.size.height) / 2.0;
    attachment.bounds = CGRectMake(0, yOffset, pinImage.size.width, pinImage.size.height);

    NSAttributedString *iconString =
    [NSAttributedString attributedStringWithAttachment:attachment];

    NSDictionary *textAttrs = @{
        NSFontAttributeName : self.locationLabel.font,
        NSForegroundColorAttributeName : UIColor.secondaryLabelColor
    };

    NSAttributedString *textString =
    [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@", _location]
                                    attributes:textAttrs];

    NSMutableAttributedString *final =
    [[NSMutableAttributedString alloc] initWithAttributedString:iconString];
    [final appendAttributedString:textString];

    self.locationLabel.attributedText = final;
    self.locationLabel.alpha = 0.0;
    self.locationLabel.transform = CGAffineTransformMakeScale(0.9, 0.9);

    [UIView animateWithDuration:0.18
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.locationLabel.alpha = 1.0;
        self.locationLabel.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end
