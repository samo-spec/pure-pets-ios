//
//  PPDiscountBadge.m
//  Pure Pets
//
//  Design System — Discount badge with red/error background.
//

#import "PPDiscountBadge.h"

@interface PPDiscountBadge ()

@property (nonatomic, strong) UILabel *percentLabel;

@end

@implementation PPDiscountBadge

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self pp_setupUI];
    }
    return self;
}

#pragma mark - UI

- (void)pp_setupUI {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = AppErrorClr;
    self.layer.cornerRadius = PPCornerSmall / 2.0;
    if (@available(iOS 13.0, *)) {
        self.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.clipsToBounds = YES;

    _percentLabel = [[UILabel alloc] init];
    _percentLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _percentLabel.font = [GM boldFontWithSize:PPFontCaption2] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
    _percentLabel.textColor = UIColor.whiteColor;
    _percentLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview:_percentLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_percentLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:PPSpaceXXS],
        [_percentLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-PPSpaceXXS],
        [_percentLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:PPSpaceXS],
        [_percentLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-PPSpaceXS],
    ]];
}

#pragma mark - Configure

- (void)configureWithPercent:(NSInteger)percent {
    _discountPercent = percent;
    if (percent > 0) {
        self.hidden = NO;
        self.percentLabel.text = [NSString stringWithFormat:@"-%ld%%", (long)percent];
    } else {
        self.hidden = YES;
    }
}

- (void)setDiscountPercent:(NSInteger)discountPercent {
    [self configureWithPercent:discountPercent];
}

@end
