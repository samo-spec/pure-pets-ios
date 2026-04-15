#import "PPUniversalCellHelper.h"

@implementation PPCornerBlurView

- (void)layoutSubviews
{
    [super layoutSubviews];

    self.blurView.frame = self.bounds;

    for (CALayer *sublayer in self.layer.sublayers) {
        if ([sublayer.name isEqualToString:@"pp.cornerBlur.tint"]) {
            sublayer.frame = self.bounds;
        }
    }

    if (self.layoutSubviewsBlock) {
        self.layoutSubviewsBlock();
    }
}

- (void)applyBlurStyle:(UIBlurEffectStyle)style
             tintColor:(nullable UIColor *)tintColor
{
    if (self.blurView.superview != self) {
        UIVisualEffectView *blurView =
            [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:style]];
        blurView.userInteractionEnabled = NO;
        blurView.translatesAutoresizingMaskIntoConstraints = NO;
        [self insertSubview:blurView atIndex:0];
        self.blurView = blurView;
        [NSLayoutConstraint activateConstraints:@[
            [blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
        ]];
    } else {
        self.blurView.effect = [UIBlurEffect effectWithStyle:style];
    }

    CALayer *existingTint = nil;
    for (CALayer *sublayer in self.layer.sublayers) {
        if ([sublayer.name isEqualToString:@"pp.cornerBlur.tint"]) {
            existingTint = sublayer;
            break;
        }
    }

    if (tintColor) {
        
        if (!existingTint) {
            existingTint = [CALayer layer];
            existingTint.name = @"pp.cornerBlur.tint";
            [self.layer addSublayer:existingTint];
        }
        existingTint.backgroundColor = tintColor.CGColor;
        existingTint.frame = self.bounds;
    } else {
        [existingTint removeFromSuperlayer];
    }
}

@end
