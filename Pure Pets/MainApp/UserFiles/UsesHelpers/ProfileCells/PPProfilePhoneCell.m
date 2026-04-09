//
//  PPProfilePhoneCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/9/26.
//


#import "PPProfilePhoneCell.h"

@interface PPProfilePhoneCell ()
@property (nonatomic, assign) BOOL pp_didSetupViews;
- (void)pp_commonInit;
@end

@implementation PPProfilePhoneCell

- (instancetype)init
{
    return [self initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) {
        return nil;
    }

    [self pp_commonInit];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self) {
        return nil;
    }

    [self pp_commonInit];
    return self;
}

- (void)pp_commonInit
{
    if (self.pp_didSetupViews) {
        return;
    }
    self.pp_didSetupViews = YES;

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = PPProfileCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPProfileCurrentSemanticAttribute();

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.contentView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    UILabel *prefixLabel = [[UILabel alloc] init];
    prefixLabel.translatesAutoresizingMaskIntoConstraints = NO;
    prefixLabel.font = [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    prefixLabel.textColor = GM.AppPrimaryColorShainer ?: AppPrimaryClr ?: UIColor.systemOrangeColor;
    prefixLabel.textAlignment = NSTextAlignmentCenter;
    [prefixLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [prefixLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    prefixLabel.layer.cornerRadius = 12.0;
    prefixLabel.layer.masksToBounds = YES;
    prefixLabel.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat a = (tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.46 * 0.18 : 0.46;
        return [[UIColor whiteColor] colorWithAlphaComponent:a];
    }];
    self.prefixLabel = prefixLabel;

    UITextField *textField = [[UITextField alloc] init];
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    textField.borderStyle = UITextBorderStyleNone;
    textField.backgroundColor = UIColor.clearColor;
    textField.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    textField.font = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    textField.keyboardType = UIKeyboardTypePhonePad;
    textField.textContentType = UITextContentTypeTelephoneNumber;
    textField.textAlignment = NSTextAlignmentLeft;
    textField.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.textField = textField;

    UIStackView *rowStack = [[UIStackView alloc] initWithArrangedSubviews:@[prefixLabel, textField]];
    rowStack.translatesAutoresizingMaskIntoConstraints = NO;
    rowStack.axis = UILayoutConstraintAxisHorizontal;
    rowStack.alignment = UIStackViewAlignmentCenter;
    rowStack.spacing = 10.0;
    rowStack.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    [self.contentView addSubview:rowStack];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [titleLabel.heightAnchor constraintGreaterThanOrEqualToConstant:12.0],
        [rowStack.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [rowStack.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [rowStack.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [rowStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0],

        [prefixLabel.widthAnchor constraintGreaterThanOrEqualToConstant:56.0],
        [prefixLabel.heightAnchor constraintEqualToConstant:28.0],
        [textField.heightAnchor constraintGreaterThanOrEqualToConstant:24.0]
    ]];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [self.textField removeTarget:nil action:NULL forControlEvents:UIControlEventEditingChanged];
}

- (void)configureWithTitle:(NSString *)title
                    prefix:(NSString *)prefix
                      text:(NSString *)text
               placeholder:(NSString *)placeholder
                 fieldKind:(PPProfileFieldKind)fieldKind
                    target:(id)target
                    action:(SEL)action
                  delegate:(id<UITextFieldDelegate>)delegate
{
    self.semanticContentAttribute = PPProfileCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPProfileCurrentSemanticAttribute();
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.prefixLabel.text = prefix.length > 0 ? prefix : @"";
    self.textField.text = text ?: @"";
    self.textField.placeholder = placeholder ?: @"";
    self.textField.tag = fieldKind;
    self.textField.delegate = delegate;
    self.textField.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    [self.textField removeTarget:nil action:NULL forControlEvents:UIControlEventEditingChanged];
    if (target && action) {
        [self.textField addTarget:target action:action forControlEvents:UIControlEventEditingChanged];
    }
}

@end
