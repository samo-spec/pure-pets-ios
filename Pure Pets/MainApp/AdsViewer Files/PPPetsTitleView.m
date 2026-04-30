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
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *locationLabel;
@property (nonatomic, strong) UILabel *categoryLabel;
@property (nonatomic, strong) UIStackView *textStack;
@property (nonatomic, strong) UIStackView *metaPillsStack;
@property (nonatomic, strong) UIStackView *trailingStack;

@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *priceView;
@property (nonatomic, assign) BOOL isFavorite;

@property (nonatomic, assign) BOOL didAnimate;
@property (nonatomic, assign) BOOL usesHeroOverlayStyle;
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
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.backgroundColor = UIColor.clearColor;
 
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [GM boldFontWithSize:21];
    self.titleLabel.textColor = UIColor.labelColor;
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.titleLabel.textAlignment = GM.setAligment;
    self.titleLabel.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [GM MidFontWithSize:13.5];
    self.subtitleLabel.textColor = UIColor.secondaryLabelColor;
    self.subtitleLabel.numberOfLines = 1;
    self.subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.subtitleLabel.adjustsFontForContentSizeCategory = YES;
    self.subtitleLabel.textAlignment = GM.setAligment;
    self.subtitleLabel.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.subtitleLabel.hidden = YES;

    self.locationLabel = [[UILabel alloc] init];
    self.locationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationLabel.font = [GM MidFontWithSize:13];
    self.locationLabel.textColor = UIColor.secondaryLabelColor;
    self.locationLabel.numberOfLines = 1;
    self.locationLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.locationLabel.adjustsFontForContentSizeCategory = YES;
    self.locationLabel.textAlignment = GM.setAligment;
    self.locationLabel.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    self.categoryLabel = [[UILabel alloc] init];
    self.categoryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.categoryLabel.font = [GM boldFontWithSize:11.0];
    self.categoryLabel.textColor = AppPrimaryClr ?: UIColor.labelColor;
    self.categoryLabel.textAlignment = NSTextAlignmentCenter;
    self.categoryLabel.backgroundColor = [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.34];
    self.categoryLabel.layer.cornerRadius = 12;
    self.categoryLabel.layer.borderWidth = 0.5;
    [self.categoryLabel pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.10]];
    self.categoryLabel.layer.masksToBounds = YES;
    self.categoryLabel.hidden = YES;

    self.metaPillsStack = [[UIStackView alloc] init];
    self.metaPillsStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.metaPillsStack.axis = UILayoutConstraintAxisHorizontal;
    self.metaPillsStack.spacing = 6;
    self.metaPillsStack.alignment = UIStackViewAlignmentCenter;
    self.metaPillsStack.distribution = UIStackViewDistributionFillProportionally;
    self.metaPillsStack.hidden = YES;
    self.metaPillsStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    self.textStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.titleLabel,
        self.subtitleLabel,
        self.locationLabel,
        self.metaPillsStack
    ]];
    self.textStack.axis = UILayoutConstraintAxisVertical;
    self.textStack.spacing = 4;
    self.textStack.alignment = UIStackViewAlignmentFill;
    self.textStack.distribution = UIStackViewDistributionFill;
    self.textStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.textStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    [self addSubview:self.textStack];

    self.trailingStack = [[UIStackView alloc] init];
    self.trailingStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.trailingStack.axis = UILayoutConstraintAxisVertical;
    self.trailingStack.spacing = 6;
    self.trailingStack.alignment = UIStackViewAlignmentCenter;
    self.trailingStack.distribution = UIStackViewDistributionFill;
    self.trailingStack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self addSubview:self.trailingStack];

    self.textTrailingConstraint =
        [self.textStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingStack.leadingAnchor constant:-14];

    [NSLayoutConstraint activateConstraints:@[
        [self.textStack.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
        [self.textStack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:18],
        self.textTrailingConstraint,
        [self.textStack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-12],
        [self.metaPillsStack.heightAnchor constraintGreaterThanOrEqualToConstant:24],

        [self.trailingStack.topAnchor constraintEqualToAnchor:self.topAnchor constant:8],
        [self.trailingStack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
        [self.trailingStack.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-8],
        [self.trailingStack.widthAnchor constraintEqualToConstant:126]
    ]];
}

- (UIColor *)pp_luxuryEmeraldColor
{
    return [UIColor colorWithHexString:@"#0F3D2E"];
}

- (UIColor *)pp_luxuryGoldColor
{
    return [UIColor colorWithHexString:@"#C7A24A"];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (self.usesHeroOverlayStyle) {
        self.priceView.layer.cornerRadius = 24.0;
        self.priceView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    } else {
        [Styling applyCornerMaskToView:self.priceView tl:28 tr:8 bl:28 br:28];
    }
    self.priceView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.priceView.bounds
                                                                 cornerRadius:self.priceView.layer.cornerRadius].CGPath;
}

#pragma mark - Public API

- (void)configureWithTitle:(NSString *)title
                  location:(nullable NSString *)location
                     price:(nullable NSString *)price
{
    [self configureWithTitle:title location:location price:price category:nil];
}

- (void)configureWithTitle:(NSString *)title
                  subtitle:(nullable NSString *)subtitle
                  location:(nullable NSString *)location
                     price:(nullable NSString *)price
{
    self.subtitle = subtitle;
    [self configureWithTitle:title location:location price:price category:nil];
}

- (void)setSubtitle:(NSString *)subtitle
{
    _subtitle = [subtitle copy];
    self.subtitleLabel.text = _subtitle;
    self.subtitleLabel.hidden = _subtitle.length == 0;
}

- (void)configureWithTitle:(NSString *)title
                  location:(nullable NSString *)location
                     price:(nullable NSString *)price
                  category:(nullable NSString *)category
{
    self.title = title;
    self.location = location;
    self.price = price;

    for (UIView *v in self.trailingStack.arrangedSubviews) {
        [self.trailingStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }

    self.priceView = [self pillViewForItem:[PPInfoPill itemWithIcon:nil text:price ?: @""]];
    [self.trailingStack addArrangedSubview:self.priceView];
    [self pp_applyHeroOverlayStyleIfNeeded];

    [NSLayoutConstraint activateConstraints:@[
        [self.priceView.widthAnchor constraintEqualToConstant:126],
        [self.priceView.heightAnchor constraintGreaterThanOrEqualToConstant:56]
    ]];

    if (category.length > 0) {
        self.categoryLabel.text = [NSString stringWithFormat:@"  %@  ", category];
        self.categoryLabel.hidden = NO;
        [self.trailingStack addArrangedSubview:self.categoryLabel];
        [NSLayoutConstraint activateConstraints:@[
            [self.categoryLabel.heightAnchor constraintEqualToConstant:26],
            [self.categoryLabel.widthAnchor constraintEqualToConstant:126]
        ]];
    } else {
        self.categoryLabel.hidden = YES;
    }

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

- (void)enableBlurBackgroundWithStyle:(UIBlurEffectStyle)style {
    if (self.blurView) {
        [self.blurView removeFromSuperview];
    }
    
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:style];
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.blurView.translatesAutoresizingMaskIntoConstraints = NO;
    self.blurView.layer.cornerRadius = self.layer.cornerRadius;
    self.blurView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.blurView.layer.cornerCurve = self.layer.cornerCurve;
    }
    
    [self insertSubview:self.blurView atIndex:0];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];
    
    self.backgroundColor = UIColor.clearColor;
}

- (void)applyHeroOverlayStyle
{
    self.usesHeroOverlayStyle = YES;
    [self pp_applyHeroOverlayStyleIfNeeded];
}

- (void)pp_applyHeroOverlayStyleIfNeeded
{
    if (!self.usesHeroOverlayStyle) {
        return;
    }

    self.titleLabel.font = [GM boldFontWithSize:24.0];
    self.titleLabel.textColor = UIColor.whiteColor;
    self.titleLabel.textAlignment = GM.setAligment;
    self.subtitleLabel.font = [GM MidFontWithSize:13.5];
    self.subtitleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.78];
    self.subtitleLabel.textAlignment = GM.setAligment;
    self.locationLabel.font = [GM MidFontWithSize:13.0];
    self.locationLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.66];
    self.locationLabel.textAlignment = GM.setAligment;
    if (self.location.length > 0) {
        [self setLocation:self.location];
    }
    self.textStack.spacing = 6.0;
    self.trailingStack.spacing = 4.0;

    self.priceView.backgroundColor = [[UIColor colorWithWhite:0.04 alpha:1.0] colorWithAlphaComponent:0.58];
    self.priceView.layer.cornerRadius = 24.0;
    self.priceView.layer.borderWidth = 0.75;
    [self.priceView pp_setBorderColor:[[self pp_luxuryGoldColor] colorWithAlphaComponent:0.28]];
    [self.priceView pp_setShadowColor:UIColor.blackColor];
    self.priceView.layer.shadowOpacity = 0.24;
    self.priceView.layer.shadowRadius = 18.0;
    self.priceView.layer.shadowOffset = CGSizeMake(0, 12);
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];

    if (!self.window || self.didAnimate) return;
    self.didAnimate = YES;
}

- (void)animatePillsIn
{
    NSTimeInterval baseDelay = 0.10;
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();

    [UIView animateWithDuration:reduceMotion ? 0.16 : 0.28
                          delay:reduceMotion ? 0.0 : baseDelay
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.priceView.alpha = 1.0;
        self.priceView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [self.metaPillsStack.arrangedSubviews enumerateObjectsUsingBlock:^(UIView *badge, NSUInteger idx, BOOL *stop) {
        [UIView animateWithDuration:reduceMotion ? 0.16 : 0.24
                              delay:reduceMotion ? 0.0 : (0.06 + (0.04 * idx))
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
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
    pill.backgroundColor = [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.64];
    pill.translatesAutoresizingMaskIntoConstraints = NO;
    pill.alpha = 0.0;
    pill.transform = CGAffineTransformMakeTranslation(0, 8);
    pill.layer.cornerRadius = 24.0;
    pill.layer.cornerCurve = kCACornerCurveContinuous;
    pill.layer.shadowOpacity = 0.12;
    pill.layer.shadowRadius = 16.0;
    pill.layer.shadowOffset = CGSizeMake(0, 10);
    pill.layer.borderWidth = 0.6;
    [pill pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.12]];
    [pill pp_setShadowColor:UIColor.blackColor];

    UIImageView *icon = [[UIImageView alloc] initWithImage:PPImage(item.iconName)];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *label = [[UILabel alloc] init];
    label.text = item.text;
    label.textColor = self.usesHeroOverlayStyle ? UIColor.whiteColor : UIColor.labelColor;
    label.font = [GM boldFontWithSize:19];
    label.numberOfLines = 1;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.textAlignment = NSTextAlignmentCenter;

    UILabel *requirelabel = [[UILabel alloc] init];
    requirelabel.text = kLang(@"Required");
    requirelabel.textColor = self.usesHeroOverlayStyle ? [[self pp_luxuryGoldColor] colorWithAlphaComponent:0.92] : UIColor.secondaryLabelColor;
    requirelabel.font = [GM MidFontWithSize:10.5];
    requirelabel.numberOfLines = 1;
    requirelabel.translatesAutoresizingMaskIntoConstraints = NO;
    requirelabel.textAlignment = NSTextAlignmentCenter;

    UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[requirelabel, label]];
    content.axis = UILayoutConstraintAxisVertical;
    content.spacing = 3;
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

    UIColor *tint = self.usesHeroOverlayStyle ? [self pp_luxuryGoldColor] : (AppPrimaryClr ?: UIColor.systemBlueColor);
    pill.backgroundColor = self.usesHeroOverlayStyle
        ? [[UIColor colorWithWhite:0.04 alpha:1.0] colorWithAlphaComponent:0.58]
        : [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.68];
    icon.tintColor = tint;
    label.textColor = self.usesHeroOverlayStyle ? UIColor.whiteColor : UIColor.labelColor;
    pill.clipsToBounds = NO;
    pill.accessibilityIdentifier = @"pricePill";

    return pill;
}

- (UIView *)metaBadgeViewForItem:(PPInfoPill *)item
{
    UIView *badge = [[UIView alloc] init];
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.alpha = 0.0;
    badge.transform = CGAffineTransformMakeTranslation(0, 6);
    badge.layer.cornerRadius = 13;
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

    UIColor *tint = AppPrimaryClr ?: UIColor.systemBlueColor;
    badge.backgroundColor = [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.42];
    badge.layer.borderWidth = 0.5;
    [badge pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.10]];
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

    UIColor *locationColor = self.usesHeroOverlayStyle ? [[UIColor whiteColor] colorWithAlphaComponent:0.78] : UIColor.secondaryLabelColor;
    pinImage = [pinImage imageWithTintColor:locationColor
                              renderingMode:UIImageRenderingModeAlwaysOriginal];

    NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
    attachment.image = pinImage;

    CGFloat yOffset = (self.locationLabel.font.capHeight - pinImage.size.height) / 2.0;
    attachment.bounds = CGRectMake(0, yOffset, pinImage.size.width, pinImage.size.height);

    NSAttributedString *iconString =
    [NSAttributedString attributedStringWithAttachment:attachment];

    NSDictionary *textAttrs = @{
        NSFontAttributeName : self.locationLabel.font,
        NSForegroundColorAttributeName : locationColor
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

    [UIView animateWithDuration:0.22
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.locationLabel.alpha = 1.0;
        self.locationLabel.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end
