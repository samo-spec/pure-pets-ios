//
//  ABCellMenuView.m
//  Test
//
//  Created by Alex Bumbu on 17/02/15.
//  Copyright (c) 2015 Alex Bumbu. All rights reserved.
//

#import "ABCellMenuView.h"

@implementation ABCellMenuView {
    IBOutlet UIButton *deleteButton;
    IBOutlet UIButton *flagButton;
    IBOutlet UIButton *moreButton;
}

- (void)awakeFromNib
{
    [super awakeFromNib];

    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;

    NSArray<UIButton *> *buttons =
        [[self.subviews filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(UIView *evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [evaluatedObject isKindOfClass:[UIButton class]];
    }]] sortedArrayUsingComparator:^NSComparisonResult(UIButton *button1, UIButton *button2) {
        if (button1.frame.origin.x < button2.frame.origin.x) {
            return NSOrderedAscending;
        }
        if (button1.frame.origin.x > button2.frame.origin.x) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];

    if (buttons.count >= 3) {
        deleteButton = buttons[0];
        flagButton = buttons[1];
        moreButton = buttons[2];
    }

    [self pp_styleActionButton:deleteButton];
    [self pp_styleActionButton:flagButton];
    [self pp_styleActionButton:moreButton];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    self.layer.cornerRadius = CGRectGetHeight(self.bounds) / 2.0;
    self.layer.backgroundColor = [[UIColor colorWithWhite:1.0 alpha:0.96] CGColor];
    self.layer.borderWidth = 1.0;
    [self pp_setBorderColor:[[UIColor blackColor] colorWithAlphaComponent:0.05]];

    [self pp_setShadowColor:[UIColor colorWithRed:76.0 / 255.0
                                            green:11.0 / 255.0
                                             blue:37.0 / 255.0
                                            alpha:1.0]];
    self.layer.shadowOpacity = 0.24;
    self.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    self.layer.shadowRadius = 16.0;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:self.layer.cornerRadius].CGPath;

    NSArray<UIButton *> *buttons = [[@[deleteButton ?: UIButton.new,
                                       flagButton ?: UIButton.new,
                                       moreButton ?: UIButton.new] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(UIButton *button, NSDictionary<NSString *,id> * _Nullable bindings) {
        return button.superview != nil;
    }]] copy];
    if (buttons.count == 0) {
        return;
    }
    CGFloat horizontalInset = 10.0;
    CGFloat availableWidth = MAX(0.0, CGRectGetWidth(self.bounds) - (horizontalInset * 2.0));
    CGFloat buttonSide = MIN(36.0, CGRectGetHeight(self.bounds) - 8.0);
    CGFloat divisor = buttons.count > 1 ? (CGFloat)(buttons.count - 1) : 1.0;
    CGFloat spacing = (availableWidth - (buttonSide * buttons.count)) / divisor;
    spacing = MAX(6.0, MIN(spacing, 10.0));
    CGFloat totalWidth = (buttonSide * buttons.count) + (spacing * (buttons.count - 1));
    CGFloat startX = MAX(horizontalInset, (CGRectGetWidth(self.bounds) - totalWidth) / 2.0);

    [buttons enumerateObjectsUsingBlock:^(UIButton * _Nonnull button, NSUInteger idx, BOOL * _Nonnull stop) {
        button.frame = CGRectMake(startX + (idx * (buttonSide + spacing)),
                                  (CGRectGetHeight(self.bounds) - buttonSide) / 2.0,
                                  buttonSide,
                                  buttonSide);
        button.layer.cornerRadius = buttonSide / 2.0;
    }];
}

- (void)pp_styleActionButton:(UIButton *)button
{
    if (!button) {
        return;
    }

    UIColor *accentColor = [UIColor colorWithHexString:@"#973C62"];
    button.backgroundColor = [accentColor colorWithAlphaComponent:0.10];
    button.tintColor = accentColor;
    button.layer.borderWidth = 1.0;
    [button pp_setBorderColor:[accentColor colorWithAlphaComponent:0.14]];
    button.layer.masksToBounds = YES;
    button.imageView.contentMode = UIViewContentModeScaleAspectFit;
}

#pragma mark Actions

- (IBAction)deleteBtnPressed:(id)sender
{
    if (_delegate && [_delegate respondsToSelector:@selector(cellMenuViewDeleteBtnTapped:)]) {
        [_delegate cellMenuViewDeleteBtnTapped:self];
    }
}

- (IBAction)moreBtnPressed:(id)sender
{
    if (_delegate && [_delegate respondsToSelector:@selector(cellMenuViewMoreBtnTapped:)]) {
        [_delegate cellMenuViewMoreBtnTapped:self];
    }
}

- (IBAction)flagBtnPressed:(id)sender
{
    if (_delegate && [_delegate respondsToSelector:@selector(cellMenuViewFlagBtnTapped:)]) {
        [_delegate cellMenuViewFlagBtnTapped:self];
        [_delegate goToviewDataVC:_ImagesArr cardClass:_cardmodel];
    }
}

@end
