//
//  PPCenteredSelectorCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 08/12/2025.
//


//  PPCenteredSelectorCell.m

#import "PPCenteredSelectorCell.h"

@implementation PPCenteredSelectorCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    
    self.contentView.backgroundColor = UIColor.clearColor;
    
    _button = [UIButton buttonWithType:UIButtonTypeSystem];
    _button.translatesAutoresizingMaskIntoConstraints = NO;
    _button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    _button.layer.cornerRadius = 22;
    _button.clipsToBounds = YES;
    _button.contentEdgeInsets = UIEdgeInsetsMake(6, 18, 6, 18);
    
    [self.contentView addSubview:_button];
    
    [NSLayoutConstraint activateConstraints:@[
        [_button.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_button.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_button.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [_button.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];
    
    return self;
}

- (void)applyTitle:(NSString *)title selected:(BOOL)selected {
    [_button setTitle:title forState:UIControlStateNormal];
    
    if (selected) {
        _button.backgroundColor = AppPrimaryClr;
        [_button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    } else {
        _button.backgroundColor = UIColor.systemGray6Color;
        [_button setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
    }
}

@end