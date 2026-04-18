//
//  ButtonsContainerView.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/05/2025.
//

#import "ButtonsContainerView.h"

@implementation ButtonsContainerView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.whiteColor;
        self.layer.cornerRadius = 32;
        self.layer.masksToBounds = NO;

        // Shadow
        [self pp_setShadowColor:[UIColor blackColor]];
        self.layer.shadowOpacity = 0.15;
        self.layer.shadowOffset = CGSizeMake(0, 4);
        self.layer.shadowRadius = 8;

        self.translatesAutoresizingMaskIntoConstraints = NO;
        [self.heightAnchor constraintEqualToConstant:64].active = YES;
    }
    return self;
}



- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:22].CGPath;
}

- (void)setButtonsWithImageNames:(NSArray<NSString *> *)imageNames
                          target:(id)target
                         actions:(NSArray<NSString *> *)selectorNames {
    if (imageNames.count != selectorNames.count) return;

    CGFloat buttonWidth = 44;
    CGFloat totalWidth = imageNames.count * buttonWidth;

    UIStackView *stackView = [[UIStackView alloc] init];
    stackView.axis = UILayoutConstraintAxisHorizontal;
    stackView.distribution = UIStackViewDistributionFillEqually;
    stackView.spacing = 0;
    stackView.alignment = UIStackViewAlignmentCenter;
    stackView.translatesAutoresizingMaskIntoConstraints = NO;

    for (int i = 0; i < imageNames.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        UIImage *image = [UIImage imageNamed:imageNames[i]];
        [button setImage:image forState:UIControlStateNormal];
       // button.tintColor = UIColor.blackColor;
        button.translatesAutoresizingMaskIntoConstraints = NO;

        [button.widthAnchor constraintEqualToConstant:buttonWidth].active = YES;
        [button.heightAnchor constraintEqualToConstant:44].active = YES;

        SEL selector = NSSelectorFromString(selectorNames[i]);
        [button addTarget:target action:selector forControlEvents:UIControlEventTouchUpInside];

        [stackView addArrangedSubview:button];
    }

    [self addSubview:stackView];

    [NSLayoutConstraint activateConstraints:@[
        [stackView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [stackView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [stackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [stackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.widthAnchor constraintEqualToConstant:totalWidth]
    ]];
}

@end



