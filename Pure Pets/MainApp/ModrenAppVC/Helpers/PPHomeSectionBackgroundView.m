//
//  PPHomeSectionBackgroundView.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/01/2026.
//

#import "PPHomeSectionBackgroundView.h"
@implementation PPHomeSectionBackgroundView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = [UIColor clearColor];

    UIView *bg = [UIView new];
    bg.translatesAutoresizingMaskIntoConstraints = NO;
    bg.backgroundColor = [UIColor colorWithWhite:0.94 alpha:1.0]; // 🔴 change here
    bg.layer.cornerRadius = PPCornersHome;
    bg.layer.masksToBounds = YES;

    [self addSubview:bg];

    [NSLayoutConstraint activateConstraints:@[
        [bg.topAnchor constraintEqualToAnchor:self.topAnchor],
        [bg.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [bg.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [bg.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
    ]];

    return self;
}

@end
