//
//  PPFloatingSearchAccessoryView.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 06/01/2026.
//

#import "PPFloatingSearchAccessoryView.h"
@implementation PPFloatingSearchAccessoryView {
    UIVisualEffectView *_blur;
    UIButton *_cancelButton;
}

- (instancetype)init {
    CGFloat barHeight = 56.0;
    self = [super initWithFrame:CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, barHeight)];
    if (!self) return nil;

    self.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    // --- Glass blur backdrop ---
    _blur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
    _blur.frame = self.bounds;
    _blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _blur.layer.cornerRadius = PPCornerMedium;
    _blur.clipsToBounds = YES;
    _blur.layer.borderWidth = 0.5;
    _blur.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;

    // --- Search text field ---
    _textField = [UITextField new];
    _textField.placeholder = kLang(@"Search");
    _textField.font = [GM MidFontWithSize:PPFontHeadline];
    _textField.returnKeyType = UIReturnKeySearch;
    _textField.clearButtonMode = UITextFieldViewModeWhileEditing;

    UIImageSymbolConfiguration *iconCfg =
        [UIImageSymbolConfiguration configurationWithPointSize:PPFontSubheadline weight:UIImageSymbolWeightMedium];
    UIImageView *searchIcon =
        [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:iconCfg]];
    searchIcon.tintColor = UIColor.secondaryLabelColor;
    _textField.leftView = searchIcon;
    _textField.leftViewMode = UITextFieldViewModeAlways;

    // --- Cancel button (44pt touch target) ---
    _cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *cancelCfg =
        [UIImageSymbolConfiguration configurationWithPointSize:PPFontSubheadline weight:UIImageSymbolWeightSemibold];
    [_cancelButton setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:cancelCfg]
                    forState:UIControlStateNormal];
    [_cancelButton addTarget:self
                      action:@selector(cancelTapped)
            forControlEvents:UIControlEventTouchUpInside];

    UIStackView *stack =
    [[UIStackView alloc] initWithArrangedSubviews:@[_textField, _cancelButton]];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = PPSpaceSM;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    [_blur.contentView addSubview:stack];
    [self addSubview:_blur];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:_blur.contentView.leadingAnchor constant:PPSpaceBase],
        [stack.trailingAnchor constraintEqualToAnchor:_blur.contentView.trailingAnchor constant:-PPSpaceBase],
        [stack.centerYAnchor constraintEqualToAnchor:_blur.contentView.centerYAnchor],
        [_cancelButton.widthAnchor constraintEqualToConstant:44.0],
        [_cancelButton.heightAnchor constraintEqualToConstant:44.0],
        [_textField.heightAnchor constraintEqualToConstant:40.0]
    ]];

    return self;
}

- (void)cancelTapped {
    if (self.onCancel) self.onCancel();
}

@end
