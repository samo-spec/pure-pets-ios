//
//  PPChickIDTextField.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 21/12/2025.
//


#import "PPTextField.h"

@interface PPTextField()
@property (strong, nonatomic) UIButton *actionButton;
@end
@implementation PPTextField

- (instancetype)init
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

#pragma mark - Setup

- (void)commonInit
{
    self.translatesAutoresizingMaskIntoConstraints = NO;

    // Typography
    self.font = [GM MidFontWithSize:15];
    self.textColor = AppPrimaryTextClr;
    self.tintColor = [GM appPrimaryColor];

    // Keyboard
    self.keyboardType = UIKeyboardTypeDefault;
    self.autocorrectionType = UITextAutocorrectionTypeNo;
    self.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.returnKeyType = UIReturnKeyDone;
    self.clearButtonMode = UITextFieldViewModeNever;

    self.textAlignment = GM.setAligment;
    self.backgroundColor = AppBackgroundClr;
    self.layer.cornerRadius = 23;
    self.layer.masksToBounds = YES;

    // Left padding
    UIView *leftPadding = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 16, 1)];
    self.leftView = leftPadding;
    self.leftViewMode = UITextFieldViewModeAlways;

    // Right action button
    self.actionButton =
    [PPButtonHelper buttonWithImageNamed:@"arrow.up.circle.dotted"
                     selectedImageNamed:@"arrow.up.circle"
                                  width:36
                                 height:36
                                    menu:nil
                                   target:self
                                   action:@selector(onRightButtonTapped)];

    self.actionButton.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *rightContainer =
    [[UIView alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
    rightContainer.userInteractionEnabled = YES; // ✅ MUST BE YES
    rightContainer.backgroundColor = UIColor.clearColor;

    [rightContainer addSubview:self.actionButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.actionButton.centerXAnchor constraintEqualToAnchor:rightContainer.centerXAnchor],
        [self.actionButton.centerYAnchor constraintEqualToAnchor:rightContainer.centerYAnchor],
        [self.actionButton.widthAnchor constraintEqualToConstant:36],
        [self.actionButton.heightAnchor constraintEqualToConstant:36],
    ]];

    self.rightView = rightContainer;
    self.rightViewMode = UITextFieldViewModeAlways;

    // Fixed height
    [self.heightAnchor constraintEqualToConstant:46].active = YES;

    self.semanticContentAttribute = GM.setSemantic;
}

#pragma mark - States

- (void)onEditingChanged
{
    // Optional validation hook
    if (self.text.length > 0) {
        self.layer.borderWidth = 0;
        self.actionButton.selected = YES;
    } else self.actionButton.selected = NO;
}

#pragma mark - Text Insets

- (CGRect)textRectForBounds:(CGRect)bounds
{
    return [self insetBounds:bounds];
}

- (CGRect)editingRectForBounds:(CGRect)bounds
{
    return [self insetBounds:bounds];
}

- (CGRect)placeholderRectForBounds:(CGRect)bounds
{
    return [self insetBounds:bounds];
}

- (CGRect)insetBounds:(CGRect)bounds
{
    CGFloat left = 16;
    CGFloat right = self.rightView ? 44 : 16;
    return CGRectMake(bounds.origin.x + left,
                      bounds.origin.y,
                      bounds.size.width - left - right,
                      bounds.size.height);
}

- (void)onRightButtonTapped
{
    [self sendActionsForControlEvents:UIControlEventPrimaryActionTriggered];
}



@end
