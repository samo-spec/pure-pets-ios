//
//  PPInfoPill.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 15/01/2026.
//


#import "PPInfoPillsView.h"

@implementation PPInfoPill

+ (instancetype)itemWithIcon:(nullable NSString *)icon text:(NSString *)text {
    PPInfoPill *item = [PPInfoPill new];
    item.iconName = icon;
    item.text = text;
    return item;
}

@end



@interface PPInfoPillsView ()
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, assign) BOOL didAnimate;
@end

@implementation PPInfoPillsView

- (instancetype)initWithItems:(NSArray<PPInfoPill *> *)items {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.semanticContentAttribute = UISemanticContentAttributeUnspecified;

    _stack = [[UIStackView alloc] init];
    _stack.translatesAutoresizingMaskIntoConstraints = NO;
    _stack.semanticContentAttribute = UISemanticContentAttributeUnspecified;
    
    _stack.axis = UILayoutConstraintAxisHorizontal;
    _stack.alignment = UIStackViewAlignmentFill;
    _stack.distribution = UIStackViewDistributionFillEqually;
    _stack.spacing = items.count > 1 ? 10 : 0;
    
    _stack.layoutMarginsRelativeArrangement = YES;
    _stack.layoutMargins = UIEdgeInsetsMake(2, 0, 2, 0);

    [self addSubview:_stack];

    [NSLayoutConstraint activateConstraints:@[
        [_stack.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];
    
    

    for (PPInfoPill *item in items) {
        if (item.text.length == 0 && item.iconName.length == 0) {
            continue;
        }
        [_stack addArrangedSubview:[self pillViewForItem:item]];
    }

    return self;
}

#pragma mark - Pill UI

- (BOOL)pp_isDarkMode
{
    if (@available(iOS 13.0, *)) {
        return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

- (UIView *)pillViewForItem:(PPInfoPill *)item {

    UIColor *tint = AppPrimaryClr ?: [UIColor colorWithHexString:@"#0F5138"];
    BOOL dark = [self pp_isDarkMode];

    UIView *pill = [[UIView alloc] init];
    pill.backgroundColor = dark ? [UIColor colorWithWhite:0.14 alpha:1.0] : [UIColor whiteColor];
    pill.layer.cornerRadius = 18.0;
    pill.layer.cornerCurve = kCACornerCurveContinuous;
    pill.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    [pill pp_setBorderColor:[UIColor colorWithWhite:dark ? 1.0 : 0.0 alpha:dark ? 0.08 : 0.06]];
    [pill pp_setShadowColor:UIColor.blackColor];
    pill.layer.shadowOpacity = 0.04;
    pill.layer.shadowRadius = 14.0;
    pill.layer.shadowOffset = CGSizeMake(0, 8);
    pill.translatesAutoresizingMaskIntoConstraints = NO;
    pill.alpha = 0.0;
    pill.transform = CGAffineTransformMakeTranslation(0, 10);

    UIImageView *icon = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:item.iconName]];
    icon.tintColor = tint;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];

    if (item.iconName.length == 0) {
        icon.hidden = YES;
    }

    UILabel *label = [[UILabel alloc] init];
    label.text = item.text;
    label.textColor = dark ? UIColor.labelColor : [UIColor colorWithWhite:0.07 alpha:1.0];
    label.font = [GM boldFontWithSize:12.5];
    label.adjustsFontForContentSizeCategory = YES;
    label.numberOfLines = 1;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.85;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.textAlignment = NSTextAlignmentCenter;

    UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[icon, label]];
    content.axis = UILayoutConstraintAxisHorizontal;
    content.spacing = 8;
    content.alignment = UIStackViewAlignmentCenter;
    content.translatesAutoresizingMaskIntoConstraints = NO;

    [pill addSubview:content];

    [NSLayoutConstraint activateConstraints:@[
        [icon.widthAnchor constraintEqualToConstant:14],
        [icon.heightAnchor constraintEqualToConstant:14],

        [content.topAnchor constraintEqualToAnchor:pill.topAnchor constant:14],
        [content.bottomAnchor constraintEqualToAnchor:pill.bottomAnchor constant:-14],
        [content.leadingAnchor constraintEqualToAnchor:pill.leadingAnchor constant:12],
        [content.trailingAnchor constraintEqualToAnchor:pill.trailingAnchor constant:-12],
    ]];

    if ([item.iconName isEqualToString:@"banknote"]) {
        pill.accessibilityIdentifier = @"pricePill";
    }

    pill.clipsToBounds = NO;

    return pill;
}

- (void)didMoveToWindow {
    [super didMoveToWindow];

    if (!self.window || self.didAnimate) return;
    self.didAnimate = YES;

    [self animatePillsIn];
}

- (void)animatePillsIn {
    NSArray<UIView *> *pills = self.stack.arrangedSubviews;
    NSTimeInterval baseDelay = 0.05;
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();

    [pills enumerateObjectsUsingBlock:^(UIView *pill, NSUInteger idx, BOOL *stop) {
        [UIView animateWithDuration:reduceMotion ? 0.16 : 0.28
                              delay:reduceMotion ? 0.0 : (baseDelay * idx)
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            pill.alpha = 1.0;
            pill.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

@end
