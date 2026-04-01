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
    _stack.spacing = items.count > 1 ? 10 : 0;
    _stack.translatesAutoresizingMaskIntoConstraints = NO;
    _stack.semanticContentAttribute = UISemanticContentAttributeUnspecified;
    
    _stack.axis = UILayoutConstraintAxisHorizontal;
    _stack.alignment = UIStackViewAlignmentFill;
    _stack.distribution = UIStackViewDistributionFillEqually;
    _stack.spacing = items.count > 1 ? 10 : 0;
    
    _stack.layoutMarginsRelativeArrangement = YES;
    _stack.layoutMargins = UIEdgeInsetsMake(4, 0, 4, 0);

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

- (UIView *)pillViewForItem:(PPInfoPill *)item {

    UIView *pill = [[UIView alloc] init];
    pill.backgroundColor = UIColor.tertiarySystemFillColor;
    pill.layer.cornerRadius = 18;
    pill.translatesAutoresizingMaskIntoConstraints = NO;
    pill.alpha = 0.0;
    pill.transform = CGAffineTransformMakeTranslation(0, 10);

    UIImageView *icon = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:item.iconName]];
    icon.tintColor = UIColor.secondaryLabelColor;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.translatesAutoresizingMaskIntoConstraints = NO;

    if (item.iconName.length == 0) {
        icon.hidden = YES;
    }

    UILabel *label = [[UILabel alloc] init];
    label.text = item.text;
    label.textColor = UIColor.labelColor;
    label.font = [GM MidFontWithSize:16];
    label.adjustsFontForContentSizeCategory = YES;
    label.numberOfLines = 1;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.textAlignment = NSTextAlignmentCenter;

    UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[icon, label]];
    content.axis = UILayoutConstraintAxisHorizontal;
    content.spacing = 6;
    content.alignment = UIStackViewAlignmentCenter;
    content.translatesAutoresizingMaskIntoConstraints = NO;

    [pill addSubview:content];

    [NSLayoutConstraint activateConstraints:@[
        [icon.widthAnchor constraintEqualToConstant:16],
        [icon.heightAnchor constraintEqualToConstant:16],

        [content.topAnchor constraintEqualToAnchor:pill.topAnchor constant:10],
        [content.bottomAnchor constraintEqualToAnchor:pill.bottomAnchor constant:-10],
        [content.leadingAnchor constraintEqualToAnchor:pill.leadingAnchor constant:12],
        [content.trailingAnchor constraintEqualToAnchor:pill.trailingAnchor constant:-12],
    ]];

    // --- Soft, interactive, per-pill color styling ---
    UIColor *tint = UIColor.secondaryLabelColor;

    if ([item.iconName isEqualToString:@"figure.dress.line.vertical.figure"]) {
        tint = [UIColor colorWithRed:0.45 green:0.65 blue:0.95 alpha:1.0]; // soft blue
    } else if ([item.iconName isEqualToString:@"pawprint.fill"]) {
        tint = [UIColor colorWithRed:0.55 green:0.75 blue:0.55 alpha:1.0]; // soft green
    } else if ([item.iconName isEqualToString:@"clock"]) {
        tint = [UIColor colorWithRed:0.95 green:0.75 blue:0.45 alpha:1.0]; // soft amber
    } else if ([item.iconName isEqualToString:@"banknote"]) {
        tint = [UIColor colorWithRed:0.65 green:0.85 blue:0.70 alpha:1.0]; // money mint
    }

    pill.backgroundColor = [tint colorWithAlphaComponent:0.14];
    pill.layer.borderWidth = 0.5;
    pill.layer.borderColor = [tint colorWithAlphaComponent:0.28].CGColor;
    icon.tintColor = tint;
    label.textColor = UIColor.labelColor;
    // --- End color styling ---

    if ([item.iconName isEqualToString:@"banknote"]) {
        pill.accessibilityIdentifier = @"pricePill";
    }

    // Optional polish: interactive feel (iOS 16+ best practices)
    pill.layer.cornerCurve = kCACornerCurveContinuous;
    pill.clipsToBounds = YES;

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

    [pills enumerateObjectsUsingBlock:^(UIView *pill, NSUInteger idx, BOOL *stop) {
        [UIView animateWithDuration:0.45
                              delay:baseDelay * idx
             usingSpringWithDamping:0.85
              initialSpringVelocity:0.6
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            pill.alpha = 1.0;
            pill.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

@end
