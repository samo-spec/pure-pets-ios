//
//  PPProfileTextFieldCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/9/26.
//


#import "PPProfileTextFieldCell.h"

@interface PPProfileTextFieldCell ()
@property (nonatomic, assign) BOOL pp_didSetupViews;
- (void)pp_commonInit;
@end

@implementation PPProfileTextFieldCell

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
    self.preservesSuperviewLayoutMargins = NO;
    self.contentView.preservesSuperviewLayoutMargins = NO;
    self.semanticContentAttribute = PPProfileCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPProfileCurrentSemanticAttribute();

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.contentView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    UITextField *textField = [[UITextField alloc] init];
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    textField.borderStyle = UITextBorderStyleNone;
    textField.backgroundColor = UIColor.clearColor;
    textField.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    textField.font = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    textField.adjustsFontSizeToFitWidth = NO;
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.textAlignment = Language.alignmentForCurrentLanguage;
    textField.semanticContentAttribute = PPProfileCurrentSemanticAttribute();
    [self.contentView addSubview:textField];
    self.textField = textField;

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [titleLabel.heightAnchor constraintGreaterThanOrEqualToConstant:12.0],

        [textField.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6.0],
        [textField.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [textField.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [textField.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0],
        [textField.heightAnchor constraintGreaterThanOrEqualToConstant:24.0]
    ]];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [self.textField removeTarget:nil action:NULL forControlEvents:UIControlEventEditingChanged];
}

- (void)configureWithTitle:(NSString *)title
                      text:(NSString *)text
               placeholder:(NSString *)placeholder
              keyboardType:(UIKeyboardType)keyboardType
           textContentType:(UITextContentType)textContentType
             returnKeyType:(UIReturnKeyType)returnKeyType
    autocapitalizationType:(UITextAutocapitalizationType)autocapitalizationType
                 fieldKind:(PPProfileFieldKind)fieldKind
                    target:(id)target
                    action:(SEL)action
                  delegate:(id<UITextFieldDelegate>)delegate
{
    self.semanticContentAttribute = PPProfileCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPProfileCurrentSemanticAttribute();
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.textField.text = text ?: @"";
    self.textField.placeholder = placeholder ?: @"";
    self.textField.tag = fieldKind;
    self.textField.delegate = delegate;
    self.textField.keyboardType = keyboardType;
    self.textField.textContentType = textContentType;
    self.textField.returnKeyType = returnKeyType;
    self.textField.autocapitalizationType = autocapitalizationType;
    self.textField.textAlignment = Language.alignmentForCurrentLanguage;
    self.textField.semanticContentAttribute = PPProfileCurrentSemanticAttribute();
    [self.textField removeTarget:nil action:NULL forControlEvents:UIControlEventEditingChanged];
    if (target && action) {
        [self.textField addTarget:target action:action forControlEvents:UIControlEventEditingChanged];
    }
}

@end
