//
//  PPHomeSectionDividerView.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/12/2025.
//
#import "PPHomeSectionDividerView.h"

@implementation PPHomeSectionDividerView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;

    UIView *line = [UIView new];
    line.translatesAutoresizingMaskIntoConstraints = NO;
    line.backgroundColor =
        [[UIColor labelColor] colorWithAlphaComponent:0.12];

    [self addSubview:line];

    [NSLayoutConstraint activateConstraints:@[
        [line.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [line.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        [line.topAnchor constraintEqualToAnchor:self.topAnchor],
        [line.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],
    ]];

    return self;
}

@end
