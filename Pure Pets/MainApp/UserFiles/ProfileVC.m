//
//  ProfileVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 06/08/2024.
//

#import "ProfileVC.h"
#import "PPPermissionHelper.h"
#import "PPVerificationCodeViewController.h"
#import "PPSelectOptionViewController.h"

#define PPDispatchMain(block) dispatch_async(dispatch_get_main_queue(), block)

@import FirebaseAuth;
@import FirebaseStorage;
@import PhotosUI;

typedef NS_ENUM(NSInteger, PPProfileSection) {
    PPProfileSectionDetails = 0,
    PPProfileSectionContact,
    PPProfileSectionAddresses,
    PPProfileSectionCount
};

typedef NS_ENUM(NSInteger, PPProfileFieldKind) {
    PPProfileFieldKindUserName = 1,
    PPProfileFieldKindFirstName,
    PPProfileFieldKindLastName,
    PPProfileFieldKindMobile,
    PPProfileFieldKindEmail,
    PPProfileFieldKindAbout
};

typedef NS_ENUM(NSInteger, PPProfileDetailRow) {
    PPProfileDetailRowUserName = 0,
    PPProfileDetailRowFirstName,
    PPProfileDetailRowLastName,
    PPProfileDetailRowCount
};

typedef NS_ENUM(NSInteger, PPProfileContactRow) {
    PPProfileContactRowCountry = 0,
    PPProfileContactRowMobile,
    PPProfileContactRowEmail,
    PPProfileContactRowAbout,
    PPProfileContactRowCount
};

static const CGFloat kPPProfileCellHorizontalInset = 20.0;
static const CGFloat kPPProfileCellVerticalInset   = 10.0;

@interface PPProfileBaseCell : UITableViewCell
@end

@implementation PPProfileBaseCell

- (void)setFrame:(CGRect)frame
{
    frame.origin.x = kPPProfileCellHorizontalInset;
    frame.size.width -= kPPProfileCellHorizontalInset * 2.0;
    frame.origin.y += kPPProfileCellVerticalInset * 0.5;
    frame.size.height -= kPPProfileCellVerticalInset;
    if (frame.size.width  < 0.0) frame.size.width  = 0.0;
    if (frame.size.height < 0.0) frame.size.height = 0.0;
    [super setFrame:frame];
}

@end

@interface PPProfileTextFieldCell : PPProfileBaseCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITextField *textField;
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
                  delegate:(id<UITextFieldDelegate>)delegate;
@end

@implementation PPProfileTextFieldCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.preservesSuperviewLayoutMargins = NO;
    self.contentView.preservesSuperviewLayoutMargins = NO;

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
    [self.contentView addSubview:textField];
    self.textField = textField;

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],

        [textField.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [textField.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [textField.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [textField.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0],
        [textField.heightAnchor constraintGreaterThanOrEqualToConstant:24.0]
    ]];

    return self;
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
    [self.textField removeTarget:nil action:NULL forControlEvents:UIControlEventEditingChanged];
    if (target && action) {
        [self.textField addTarget:target action:action forControlEvents:UIControlEventEditingChanged];
    }
}

@end

@interface PPProfilePhoneCell : PPProfileBaseCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *prefixLabel;
@property (nonatomic, strong) UITextField *textField;
- (void)configureWithTitle:(NSString *)title
                    prefix:(NSString *)prefix
                      text:(NSString *)text
               placeholder:(NSString *)placeholder
                 fieldKind:(PPProfileFieldKind)fieldKind
                    target:(id)target
                    action:(SEL)action
                  delegate:(id<UITextFieldDelegate>)delegate;
@end

@implementation PPProfilePhoneCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

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
    prefixLabel.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.46];
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

        [rowStack.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [rowStack.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [rowStack.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [rowStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0],

        [prefixLabel.widthAnchor constraintGreaterThanOrEqualToConstant:56.0],
        [prefixLabel.heightAnchor constraintEqualToConstant:28.0],
        [textField.heightAnchor constraintGreaterThanOrEqualToConstant:24.0]
    ]];

    return self;
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
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.prefixLabel.text = prefix.length > 0 ? prefix : @"";
    self.textField.text = text ?: @"";
    self.textField.placeholder = placeholder ?: @"";
    self.textField.tag = fieldKind;
    self.textField.delegate = delegate;
    [self.textField removeTarget:nil action:NULL forControlEvents:UIControlEventEditingChanged];
    if (target && action) {
        [self.textField addTarget:target action:action forControlEvents:UIControlEventEditingChanged];
    }
}

@end

@interface PPProfileTextViewCell : PPProfileBaseCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (nonatomic, strong) NSLayoutConstraint *textViewHeightConstraint;
- (void)configureWithTitle:(NSString *)title
                      text:(NSString *)text
               placeholder:(NSString *)placeholder
                 fieldKind:(PPProfileFieldKind)fieldKind
                  delegate:(id<UITextViewDelegate>)delegate;
- (void)updatePreferredHeight;
- (void)updatePlaceholderVisibility;
@end

@implementation PPProfileTextViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.contentView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    UITextView *textView = [[UITextView alloc] init];
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    textView.backgroundColor = UIColor.clearColor;
    textView.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    textView.font = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
    textView.scrollEnabled = NO;
    textView.textContainerInset = UIEdgeInsetsZero;
    textView.textContainer.lineFragmentPadding = 0.0;
    textView.autocorrectionType = UITextAutocorrectionTypeNo;
    textView.textAlignment = Language.alignmentForCurrentLanguage;
    [self.contentView addSubview:textView];
    self.textView = textView;

    UILabel *placeholderLabel = [[UILabel alloc] init];
    placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    placeholderLabel.font = textView.font;
    placeholderLabel.textColor = UIColor.placeholderTextColor;
    placeholderLabel.numberOfLines = 0;
    placeholderLabel.userInteractionEnabled = NO;
    [self.contentView addSubview:placeholderLabel];
    self.placeholderLabel = placeholderLabel;

    NSLayoutConstraint *heightConstraint = [textView.heightAnchor constraintGreaterThanOrEqualToConstant:116.0];
    heightConstraint.active = YES;
    self.textViewHeightConstraint = heightConstraint;

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],

        [textView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [textView.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [textView.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [textView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0],

        [placeholderLabel.topAnchor constraintEqualToAnchor:textView.topAnchor],
        [placeholderLabel.leadingAnchor constraintEqualToAnchor:textView.leadingAnchor constant:2.0],
        [placeholderLabel.trailingAnchor constraintLessThanOrEqualToAnchor:textView.trailingAnchor]
    ]];

    return self;
}

- (void)configureWithTitle:(NSString *)title
                      text:(NSString *)text
               placeholder:(NSString *)placeholder
                 fieldKind:(PPProfileFieldKind)fieldKind
                  delegate:(id<UITextViewDelegate>)delegate
{
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.textView.tag = fieldKind;
    self.textView.delegate = delegate;
    self.textView.textAlignment = Language.alignmentForCurrentLanguage;
    self.textView.text = text ?: @"";
    self.placeholderLabel.text = placeholder ?: @"";
    self.placeholderLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self updatePlaceholderVisibility];
    [self updatePreferredHeight];
}

- (void)updatePreferredHeight
{
    CGFloat fittingWidth = CGRectGetWidth(self.textView.bounds);
    if (fittingWidth <= 1.0) {
        fittingWidth = UIScreen.mainScreen.bounds.size.width - 72.0;
    }
    CGSize targetSize = CGSizeMake(MAX(120.0, fittingWidth), CGFLOAT_MAX);
    CGFloat preferredHeight = ceil([self.textView sizeThatFits:targetSize].height);
    self.textViewHeightConstraint.constant = MAX(116.0, preferredHeight);
}

- (void)updatePlaceholderVisibility
{
    self.placeholderLabel.hidden = self.textView.text.length > 0;
}

@end

@interface PPProfileSelectorCell : PPProfileBaseCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *valueLabel;
@property (nonatomic, strong) UILabel *flagLabel;
@property (nonatomic, strong) UIImageView *chevronView;
- (void)configureWithTitle:(NSString *)title
                     value:(NSString *)value
                      flag:(NSString *)flag;
@end

@implementation PPProfileSelectorCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    [self.contentView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    UILabel *flagLabel = [[UILabel alloc] init];
    flagLabel.translatesAutoresizingMaskIntoConstraints = NO;
    flagLabel.font = [UIFont systemFontOfSize:18.0];
    flagLabel.textAlignment = NSTextAlignmentCenter;
    [self.contentView addSubview:flagLabel];
    self.flagLabel = flagLabel;

    UILabel *valueLabel = [[UILabel alloc] init];
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.font = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    valueLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    valueLabel.numberOfLines = 2;
    [self.contentView addSubview:valueLabel];
    self.valueLabel = valueLabel;

    UIImageView *chevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down"]];
    chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    chevronView.tintColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.8];
    chevronView.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:chevronView];
    self.chevronView = chevronView;

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],

        [chevronView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:10.0],
        [chevronView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [chevronView.widthAnchor constraintEqualToConstant:14.0],
        [chevronView.heightAnchor constraintEqualToConstant:14.0],

        [flagLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [flagLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [flagLabel.widthAnchor constraintEqualToConstant:22.0],
        [flagLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-14.0],

        [valueLabel.leadingAnchor constraintEqualToAnchor:flagLabel.trailingAnchor constant:8.0],
        [valueLabel.centerYAnchor constraintEqualToAnchor:flagLabel.centerYAnchor],
        [valueLabel.trailingAnchor constraintEqualToAnchor:chevronView.leadingAnchor constant:-12.0],
        [valueLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0]
    ]];

    return self;
}

- (void)configureWithTitle:(NSString *)title
                     value:(NSString *)value
                      flag:(NSString *)flag
{
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.valueLabel.text = value ?: @"";
    self.valueLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.flagLabel.text = flag ?: @"";
}

@end

@interface PPProfileAddressCell : PPProfileBaseCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, strong) UIImageView *chevronView;
- (void)configureWithAddress:(PPAddressModel *)address;
@end

@implementation PPProfileAddressCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.numberOfLines = 1;
    [self.contentView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    UILabel *badgeLabel = [[UILabel alloc] init];
    badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    badgeLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    badgeLabel.textColor = UIColor.whiteColor;
    badgeLabel.backgroundColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    badgeLabel.textAlignment = NSTextAlignmentCenter;
    badgeLabel.layer.cornerRadius = 10.0;
    badgeLabel.layer.masksToBounds = YES;
    badgeLabel.text = kLang(@"Default");
    [self.contentView addSubview:badgeLabel];
    self.badgeLabel = badgeLabel;

    UILabel *detailLabel = [[UILabel alloc] init];
    detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    detailLabel.font = [GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightRegular];
    detailLabel.textColor = [UIColor secondaryLabelColor];
    detailLabel.numberOfLines = 0;
    [self.contentView addSubview:detailLabel];
    self.detailLabel = detailLabel;

    UIImageView *chevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
    chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    chevronView.tintColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.75];
    chevronView.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:chevronView];
    self.chevronView = chevronView;

    [NSLayoutConstraint activateConstraints:@[
        [chevronView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [chevronView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [chevronView.widthAnchor constraintEqualToConstant:14.0],
        [chevronView.heightAnchor constraintEqualToConstant:14.0],

        [titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:badgeLabel.leadingAnchor constant:-8.0],

        [badgeLabel.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor],
        [badgeLabel.trailingAnchor constraintEqualToAnchor:chevronView.leadingAnchor constant:-10.0],
        [badgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:54.0],
        [badgeLabel.heightAnchor constraintEqualToConstant:20.0],

        [detailLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [detailLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [detailLabel.trailingAnchor constraintEqualToAnchor:chevronView.leadingAnchor constant:-10.0],
        [detailLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0]
    ]];

    return self;
}

- (void)configureWithAddress:(PPAddressModel *)address
{
    NSString *title = address.fullName.length > 0 ? address.fullName : (address.locatioName.length > 0 ? address.locatioName : kLang(@"Shipping Addresses"));
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.detailLabel.text = address.displayName ?: @"";
    self.detailLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.badgeLabel.hidden = !address.isDefault;
    self.titleLabel.textColor = address.isDefault ? (AppPrimaryClr ?: UIColor.labelColor) : (AppPrimaryTextClr ?: UIColor.labelColor);
}

@end

@interface PPProfileActionCell : PPProfileBaseCell
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
- (void)configureWithTitle:(NSString *)title iconName:(NSString *)iconName;
@end

@implementation PPProfileActionCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:iconView];
    self.iconView = iconView;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    titleLabel.numberOfLines = 1;
    [self.contentView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    [NSLayoutConstraint activateConstraints:@[
        [iconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [iconView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:18.0],
        [iconView.heightAnchor constraintEqualToConstant:18.0],

        [titleLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:10.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:16.0],
        [titleLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-16.0]
    ]];

    return self;
}

- (void)configureWithTitle:(NSString *)title iconName:(NSString *)iconName
{
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.iconView.image = [UIImage systemImageNamed:iconName ?: @"plus"];
}

@end

@interface ProfileVC ()<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UITextViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, AddressFormVCDelegate, TOCropViewControllerDelegate, PHPickerViewControllerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<PPAddressModel *> *addresses;
@property (nonatomic, strong) id<FIRListenerRegistration> addressListener;
@property (nonatomic, strong) NSMutableArray<CountryCodeModel *> *contriesArray;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *formDataArray;
@property (nonatomic, strong) CountryCodeModel *selectedCountry;

@property (nonatomic, copy) NSString *draftUserName;
@property (nonatomic, copy) NSString *draftFirstName;
@property (nonatomic, copy) NSString *draftLastName;
@property (nonatomic, copy) NSString *draftUserEmail;
@property (nonatomic, copy) NSString *draftUserAbout;
@property (nonatomic, copy) NSString *draftMobileLocal;

@property (nonatomic, assign) BOOL showingSave;
@property (nonatomic, assign) BOOL isSavingProfile;
@property (nonatomic, assign) BOOL suppressEditTracking;
@property (nonatomic, copy) NSDictionary<NSString *, id> *profileDraftBaseline;

@property (nonatomic, strong) UIView *headerRoot;
@property (nonatomic, strong) UIView *headerCardView;
@property (nonatomic, strong) UILabel *headerEyebrowLabel;
@property (nonatomic, strong) UILabel *headerNameLabel;
@property (nonatomic, strong) UILabel *headerHandleLabel;
@property (nonatomic, strong) UILabel *headerMetaLabel;
@property (nonatomic, strong) RoundedImageViewWithShadow *avatarIMV;
@property (nonatomic, strong) UIButton *addPhotoBtn;
@property (nonatomic, strong) UIView *backgroundGlowViewTop;
@property (nonatomic, strong) UIView *backgroundGlowViewBottom;
@property (nonatomic, strong, nullable) UIImage *pendingAvatarImage;

@property (nonatomic, strong) UIBarButtonItem *saveDataBarButton;
@property (nonatomic, strong) UIBarButtonItem *logoutBarButton;
@end

@implementation ProfileVC

#pragma mark - Appearance

- (UIColor *)pp_profileCanvasColor
{
    return [UIColor colorWithRed:0.969 green:0.961 blue:0.949 alpha:1.0];
}

- (UIColor *)pp_profileSurfaceColor
{
    return [[UIColor whiteColor] colorWithAlphaComponent:0.82];
}

- (UIColor *)pp_profileSurfaceBorderColor
{
    return [UIColor colorWithRed:0.25 green:0.17 blue:0.18 alpha:0.08];
}

- (void)pp_applyProfileCanvasBackground
{
    UIColor *canvasColor = [self pp_profileCanvasColor];
    self.view.backgroundColor = canvasColor;
    self.view.opaque = YES;
    self.navigationController.view.backgroundColor = canvasColor;

    if (!self.tableView) {
        return;
    }

    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.opaque = NO;
    self.tableView.alwaysBounceVertical = YES;

    UIView *backgroundView = self.tableView.backgroundView;
    if (!backgroundView) {
        backgroundView = [[UIView alloc] initWithFrame:self.tableView.bounds];
        backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.tableView.backgroundView = backgroundView;
    }
    backgroundView.backgroundColor = canvasColor;
}

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.formDataArray = [NSMutableDictionary dictionary];
    self.addresses = PPCurrentUser.Addresses ?: @[];
    self.suppressEditTracking = YES;

    [self pp_prepareDraftState];
    [self pp_buildTableView];
    [self setupModernBackdrop];
    [self setupHeaderUI];
    [self pp_applyProfileCanvasBackground];
    [self pp_refreshProfileHeaderContent];
    [self listenToAddresses];
    [self pp_captureProfileDraftBaseline];
    self.showingSave = NO;
    self.suppressEditTracking = NO;
    [self pp_refreshRightNavSaveState];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.navigationController) {
                [self.navigationController popViewControllerAnimated:YES];
            } else {
                [self dismissViewControllerAnimated:YES completion:nil];
            }
        });
        return;
    }

    [self BellowIos26Buttons];
    [self pp_applyProfileCanvasBackground];
    [self.tableView reloadData];

    //[[NSNotificationCenter defaultCenter] postNotificationName:PPHideSystemTabBarNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.tableView.contentInset = UIEdgeInsetsMake(6.0, 0.0, 24.0, 0.0);
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(6.0, 0.0, 24.0, 0.0);
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [PPHUD dismiss];
    [[NSNotificationCenter defaultCenter] postNotificationName:PPShowSystemTabBarNotification object:nil];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self pp_refreshProfileHeaderContent];
    CGFloat headerWidth = CGRectGetWidth(self.tableView.bounds);
    if (headerWidth <= 0.0) {
        headerWidth = CGRectGetWidth(self.view.bounds);
    }
    CGRect headerBounds = self.headerRoot.bounds;
    if (ABS(headerBounds.size.width - headerWidth) > 0.5) {
        headerBounds.size.width = headerWidth;
        self.headerRoot.bounds = headerBounds;
    }
    [self.headerRoot setNeedsLayout];
    [self.headerRoot layoutIfNeeded];
    CGFloat headerHeight = [self.headerRoot systemLayoutSizeFittingSize:CGSizeMake(headerWidth, UILayoutFittingCompressedSize.height)
                                        withHorizontalFittingPriority:UILayoutPriorityRequired
                                              verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
    CGRect frame = self.headerRoot.frame;
    frame.size.width = headerWidth;
    frame.size.height = headerHeight;
    self.headerRoot.frame = frame;
    self.tableView.tableHeaderView = self.headerRoot;
    [Styling addLiquidGlassBorderToView:self.avatarIMV cornerRadius:54.0];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    [self pp_applyProfileCanvasBackground];

    self.backgroundGlowViewTop.layer.cornerRadius = CGRectGetWidth(self.backgroundGlowViewTop.bounds) * 0.5;
    self.backgroundGlowViewBottom.layer.cornerRadius = CGRectGetWidth(self.backgroundGlowViewBottom.bounds) * 0.5;
    [self.view sendSubviewToBack:self.backgroundGlowViewBottom];
    [self.view sendSubviewToBack:self.backgroundGlowViewTop];

    self.avatarIMV.layer.borderWidth = 3.0;
    self.avatarIMV.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.86].CGColor;

    self.headerCardView.layer.borderWidth = 1.0;
    self.headerCardView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.68].CGColor;

    self.addPhotoBtn.layer.borderWidth = 0.0;
    self.addPhotoBtn.layer.shadowColor = [UIColor colorWithRed:0.16 green:0.09 blue:0.10 alpha:1.0].CGColor;
    self.addPhotoBtn.layer.shadowOpacity = 0.10;
    self.addPhotoBtn.layer.shadowRadius = 18.0;
    self.addPhotoBtn.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    self.tableView.backgroundView = nil;

    self.tableView.backgroundColor = AppClearClr;
    
}

- (void)dealloc
{
    [self.addressListener remove];
    self.addressListener = nil;
}

#pragma mark - Setup

- (void)pp_buildTableView
{
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.showsVerticalScrollIndicator = NO;
    tableView.showsHorizontalScrollIndicator = NO;
    tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    tableView.rowHeight = UITableViewAutomaticDimension;
    tableView.estimatedRowHeight = 84.0;
    tableView.contentInset = UIEdgeInsetsMake(6.0, 0.0, 24.0, 0.0);
    tableView.scrollIndicatorInsets = UIEdgeInsetsMake(6.0, 0.0, 24.0, 0.0);
    if (@available(iOS 15.0, *)) {
        tableView.sectionHeaderTopPadding = 0.0;
    }

    [tableView registerClass:PPProfileTextFieldCell.class forCellReuseIdentifier:@"PPProfileTextFieldCell"];
    [tableView registerClass:PPProfilePhoneCell.class forCellReuseIdentifier:@"PPProfilePhoneCell"];
    [tableView registerClass:PPProfileTextViewCell.class forCellReuseIdentifier:@"PPProfileTextViewCell"];
    [tableView registerClass:PPProfileSelectorCell.class forCellReuseIdentifier:@"PPProfileSelectorCell"];
    [tableView registerClass:PPProfileAddressCell.class forCellReuseIdentifier:@"PPProfileAddressCell"];
    [tableView registerClass:PPProfileActionCell.class forCellReuseIdentifier:@"PPProfileActionCell"];

    [self.view addSubview:tableView];
    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [tableView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
    self.tableView = tableView;
}

- (void)pp_prepareDraftState
{
    self.contriesArray = [GM getMiddleEastCountriesForLanguage:[Language currentLanguageCode]];
    self.selectedCountry = [self pp_resolvedSelectedCountry];
    [self pp_loadDraftValuesFromUser:PPCurrentUser];
    [self setformDataArray:@(self.selectedCountry.ID) forKey:@"CountryID"];
}

- (CountryCodeModel *)pp_resolvedSelectedCountry
{
    NSInteger selectedCountryID = PPCurrentUser.CountryID;
    CountryCodeModel *countryByID = selectedCountryID > 0
        ? [[self.contriesArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", selectedCountryID]] firstObject]
        : nil;
    CountryCodeModel *countryByMobile = [self pp_countryFromStoredMobileNumber:PPCurrentUser.MobileNo];
    NSString *carrierISO = [self pp_trimmedString:[GM getCurrentCountryFromCarrier]];
    CountryCodeModel *countryByCarrier = carrierISO.length > 0 ? [self pp_countryWithISOCode:carrierISO] : nil;
    NSString *currentISO = [self pp_trimmedString:CitiesManager.shared.CurrentCountry.iso];
    CountryCodeModel *countryByCurrent = currentISO.length > 0 ? [self pp_countryWithISOCode:currentISO] : nil;
    NSString *localeISO = [self pp_trimmedString:[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode]];
    CountryCodeModel *countryByLocale = localeISO.length > 0 ? [self pp_countryWithISOCode:localeISO] : nil;

    CountryCodeModel *resolved = countryByID ?: countryByMobile ?: countryByCarrier ?: countryByCurrent ?: countryByLocale ?: [self pp_qatarCountry];
    if (countryByID && countryByMobile && ![[self pp_trimmedString:countryByID.phoneCode] isEqualToString:[self pp_trimmedString:countryByMobile.phoneCode]]) {
        NSString *storedMobile = [self pp_trimmedString:PPCurrentUser.MobileNo];
        if ([storedMobile hasPrefix:[self pp_trimmedString:countryByMobile.phoneCode]]) {
            resolved = countryByMobile;
        }
    }
    return resolved ?: [self pp_qatarCountry];
}

- (void)pp_loadDraftValuesFromUser:(UserModel *)user
{
    self.draftUserName = [self pp_trimmedString:user.UserName];
    self.draftFirstName = [self pp_trimmedString:user.FirstName];
    self.draftLastName = [self pp_trimmedString:user.LastName];
    self.draftUserEmail = [self pp_trimmedString:user.UserEmail];
    self.draftUserAbout = [self pp_trimmedString:user.UserAbout];

    NSString *storedMobile = [self pp_trimmedString:user.MobileNo];
    if (storedMobile.length > 0 && self.selectedCountry.phoneCode.length > 0) {
        self.draftMobileLocal = [self pp_localPhonePartFromE164:storedMobile dialCode:self.selectedCountry.phoneCode];
    } else {
        self.draftMobileLocal = storedMobile ?: @"";
    }
}

- (void)pp_syncDraftStateFromCurrentUser
{
    self.suppressEditTracking = YES;
    self.selectedCountry = [self pp_resolvedSelectedCountry];
    [self pp_loadDraftValuesFromUser:PPCurrentUser];
    [self.formDataArray removeAllObjects];
    [self setformDataArray:@(self.selectedCountry.ID) forKey:@"CountryID"];
    [self pp_captureProfileDraftBaseline];
    self.pendingAvatarImage = nil;
    self.suppressEditTracking = NO;
    [self.tableView reloadData];
    [self pp_refreshProfileHeaderContent];
    [self pp_refreshRightNavSaveState];
}

#pragma mark - Draft / Dirty State

- (NSDictionary<NSString *, id> *)pp_profileDraftSnapshot
{
    CountryCodeModel *country = self.selectedCountry ?: [self pp_qatarCountry];
    return @{
        @"firstName": [self pp_trimmedString:self.draftFirstName] ?: @"",
        @"lastName": [self pp_trimmedString:self.draftLastName] ?: @"",
        @"userName": [self pp_trimmedString:self.draftUserName] ?: @"",
        @"userEmail": [[self pp_trimmedString:self.draftUserEmail] lowercaseString] ?: @"",
        @"userAbout": [self pp_trimmedString:self.draftUserAbout] ?: @"",
        @"mobileLocal": [self pp_trimmedString:self.draftMobileLocal] ?: @"",
        @"countryID": @((long)(country ? country.ID : 0))
    };
}

- (void)pp_captureProfileDraftBaseline
{
    self.profileDraftBaseline = [self pp_profileDraftSnapshot];
}

- (BOOL)pp_hasPendingProfileChanges
{
    if (self.pendingAvatarImage != nil) {
        return YES;
    }

    NSDictionary<NSString *, id> *currentSnapshot = [self pp_profileDraftSnapshot];
    if (!self.profileDraftBaseline) {
        return currentSnapshot.count > 0;
    }
    return ![self.profileDraftBaseline isEqualToDictionary:currentSnapshot];
}

- (void)pp_refreshRightNavSaveState
{
    BOOL hasChanges = [self pp_hasPendingProfileChanges];
    self.showingSave = hasChanges;
    if (hasChanges) {
        [self pp_showSaveButton];
    } else {
        [self pp_showLogoutButton];
    }
}

- (void)markFormAsEdited
{
    if (self.suppressEditTracking) {
        return;
    }
    [self pp_refreshRightNavSaveState];
}

- (void)setformDataArray:(id)obj forKey:(NSString *)key
{
    if (key.length == 0) {
        return;
    }
    if (!self.formDataArray) {
        self.formDataArray = [NSMutableDictionary dictionary];
    }
    if (!obj || obj == [NSNull null]) {
        [self.formDataArray removeObjectForKey:key];
        return;
    }
    if ([obj isKindOfClass:NSString.class]) {
        NSString *trimmed = [(NSString *)obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length == 0) {
            [self.formDataArray removeObjectForKey:key];
            return;
        }
        self.formDataArray[key] = trimmed;
        return;
    }
    self.formDataArray[key] = obj;
}

#pragma mark - Nav Bar

- (void)pp_showSaveButton
{
    if (!self.saveDataBarButton) {
        self.saveDataBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"checkmark"]
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(updateUserData)];
    }
    self.saveDataBarButton.target = self;
    self.saveDataBarButton.action = @selector(updateUserData);
    self.navigationItem.rightBarButtonItem = self.saveDataBarButton;

    UIButton *saveButton = [self pp_ButtonWithSystemName:@"checkmark" action:@selector(updateUserData)];
    [self pp_navBarRemoveButtonForKey:@"saveOrLogout"];
    [self _pp_addRightButton:saveButton key:@"saveOrLogout"];
}

- (void)pp_showLogoutButton
{
    UIButton *logoutButton = [self pp_ButtonWithSystemName:@"power" action:@selector(logoutTapped)];
    [self pp_navBarRemoveButtonForKey:@"saveOrLogout"];
    [self _pp_addRightButton:logoutButton key:@"saveOrLogout"];
}

- (void)BellowIos26Buttons
{
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"UserProfile") showBack:YES];

    if (!self.saveDataBarButton) {
        self.saveDataBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"checkmark"]
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(updateUserData)];
    }
    [self pp_refreshRightNavSaveState];
}

- (void)pp_setProfileSaving:(BOOL)isSaving
{
    self.isSavingProfile = isSaving;
    self.navigationItem.rightBarButtonItem.enabled = !isSaving;
    self.navigationItem.leftBarButtonItem.enabled = !isSaving;
    [self pp_navBarHideButtonForKey:@"saveOrLogout" hidden:isSaving animated:NO];
    self.tableView.userInteractionEnabled = !isSaving;
}

#pragma mark - Header

- (NSString *)pp_localizedProfileStringForKey:(NSString *)key fallback:(NSString *)fallback
{
    NSString *value = key.length ? kLang(key) : nil;
    if (![value isKindOfClass:NSString.class] || value.length == 0 || [value isEqualToString:key]) {
        return fallback ?: @"";
    }
    return value;
}

- (void)setupModernBackdrop
{
    if (self.backgroundGlowViewTop || self.backgroundGlowViewBottom) {
        return;
    }

    UIView *topGlow = [[UIView alloc] init];
    topGlow.translatesAutoresizingMaskIntoConstraints = NO;
    topGlow.userInteractionEnabled = NO;
    topGlow.backgroundColor = [[UIColor colorWithRed:0.93 green:0.80 blue:0.69 alpha:1.0] colorWithAlphaComponent:0.12];
    topGlow.layer.shadowColor = [UIColor colorWithRed:0.98 green:0.82 blue:0.60 alpha:1.0].CGColor;
    topGlow.layer.shadowOpacity = 0.10;
    topGlow.layer.shadowRadius = 64.0;
    topGlow.layer.shadowOffset = CGSizeZero;

    UIView *bottomGlow = [[UIView alloc] init];
    bottomGlow.translatesAutoresizingMaskIntoConstraints = NO;
    bottomGlow.userInteractionEnabled = NO;
    bottomGlow.backgroundColor = [[UIColor colorWithRed:0.72 green:0.45 blue:0.42 alpha:1.0] colorWithAlphaComponent:0.06];
    bottomGlow.layer.shadowColor = [UIColor colorWithRed:0.68 green:0.27 blue:0.33 alpha:1.0].CGColor;
    bottomGlow.layer.shadowOpacity = 0.08;
    bottomGlow.layer.shadowRadius = 72.0;
    bottomGlow.layer.shadowOffset = CGSizeZero;

    [self.view insertSubview:topGlow belowSubview:self.tableView];
    [self.view insertSubview:bottomGlow belowSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [topGlow.widthAnchor constraintEqualToConstant:220.0],
        [topGlow.heightAnchor constraintEqualToConstant:220.0],
        [topGlow.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:-72.0],
        [topGlow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:84.0],

        [bottomGlow.widthAnchor constraintEqualToConstant:200.0],
        [bottomGlow.heightAnchor constraintEqualToConstant:200.0],
        [bottomGlow.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:48.0],
        [bottomGlow.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-64.0]
    ]];

    self.backgroundGlowViewTop = topGlow;
    self.backgroundGlowViewBottom = bottomGlow;
}

- (void)setupHeaderUI
{
    self.headerRoot = [[UIView alloc] init];
    self.headerRoot.backgroundColor = UIColor.clearColor;

    UIColor *brandColor = AppPrimaryClr ?: UIColor.systemOrangeColor;

    UIView *cardView = [[UIView alloc] init];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    cardView.backgroundColor = [self pp_profileSurfaceColor];
    cardView.layer.cornerRadius = 34.0;
    cardView.layer.masksToBounds = NO;
    cardView.layer.borderWidth = 1.0;
    cardView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.68].CGColor;
    cardView.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:1.0].CGColor;
    cardView.layer.shadowOpacity = 0.08;
    cardView.layer.shadowRadius = 24.0;
    cardView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    [self.headerRoot addSubview:cardView];

    UIView *tintView = [[UIView alloc] init];
    tintView.translatesAutoresizingMaskIntoConstraints = NO;
    tintView.backgroundColor = [[UIColor colorWithRed:0.99 green:0.96 blue:0.93 alpha:1.0] colorWithAlphaComponent:0.72];
    tintView.layer.cornerRadius = 34.0;
    tintView.layer.masksToBounds = YES;
    [cardView addSubview:tintView];

    UIView *ambientGlow = [[UIView alloc] init];
    ambientGlow.translatesAutoresizingMaskIntoConstraints = NO;
    ambientGlow.backgroundColor = [brandColor colorWithAlphaComponent:0.16];
    ambientGlow.userInteractionEnabled = NO;
    ambientGlow.layer.cornerRadius = 94.0;
    ambientGlow.layer.shadowColor = [brandColor colorWithAlphaComponent:0.50].CGColor;
    ambientGlow.layer.shadowOpacity = 0.16;
    ambientGlow.layer.shadowRadius = 42.0;
    ambientGlow.layer.shadowOffset = CGSizeZero;
    [cardView addSubview:ambientGlow];

    UIView *secondaryGlow = [[UIView alloc] init];
    secondaryGlow.translatesAutoresizingMaskIntoConstraints = NO;
    secondaryGlow.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.40];
    secondaryGlow.userInteractionEnabled = NO;
    secondaryGlow.layer.cornerRadius = 58.0;
    secondaryGlow.layer.shadowColor = [[UIColor whiteColor] colorWithAlphaComponent:0.45].CGColor;
    secondaryGlow.layer.shadowOpacity = 0.20;
    secondaryGlow.layer.shadowRadius = 22.0;
    secondaryGlow.layer.shadowOffset = CGSizeZero;
    [cardView addSubview:secondaryGlow];

    UIView *accentBar = [[UIView alloc] init];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = brandColor;
    accentBar.layer.cornerRadius = 3.0;
    [cardView addSubview:accentBar];

    UIView *eyebrowPill = [[UIView alloc] init];
    eyebrowPill.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowPill.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.74];
    eyebrowPill.layer.cornerRadius = 14.0;
    eyebrowPill.layer.borderWidth = 1.0;
    eyebrowPill.layer.borderColor = [brandColor colorWithAlphaComponent:0.10].CGColor;
    eyebrowPill.layer.masksToBounds = YES;
    [cardView addSubview:eyebrowPill];

    UILabel *eyebrowLabel = [[UILabel alloc] init];
    eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    eyebrowLabel.textColor = [brandColor colorWithAlphaComponent:0.92];
    eyebrowLabel.textAlignment = NSTextAlignmentCenter;
    [eyebrowPill addSubview:eyebrowLabel];

    UIView *avatarHalo = [[UIView alloc] init];
    avatarHalo.translatesAutoresizingMaskIntoConstraints = NO;
    avatarHalo.backgroundColor = [brandColor colorWithAlphaComponent:0.12];
    avatarHalo.layer.cornerRadius = 62.0;
    avatarHalo.layer.borderWidth = 1.0;
    avatarHalo.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.48].CGColor;
    avatarHalo.layer.shadowColor = [brandColor colorWithAlphaComponent:0.30].CGColor;
    avatarHalo.layer.shadowOpacity = 0.12;
    avatarHalo.layer.shadowRadius = 22.0;
    avatarHalo.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    [cardView addSubview:avatarHalo];

    RoundedImageViewWithShadow *avatarView = [[RoundedImageViewWithShadow alloc] initWithImage:[UIImage systemImageNamed:@"person.crop.circle.fill"]];
    avatarView.userInteractionEnabled = YES;
    if (PPCurrentUser.UserImageUrl) {
        [GM setImageFromUrlString:PPSafeString(PPCurrentUser.UserImageUrl.absoluteString)
                        imageView:avatarView.imageView
                          phImage:@"person.crop.circle.fill"];
    }
    avatarView.layer.cornerRadius = 54.0;
    avatarView.layer.masksToBounds = YES;
    avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapAddPhoto)];
    [avatarView addGestureRecognizer:tap];
    [avatarHalo addSubview:avatarView];
    self.avatarIMV = avatarView;

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.font = [GM boldFontWithSize:29.0] ?: [UIFont systemFontOfSize:29.0 weight:UIFontWeightBold];
    nameLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.numberOfLines = 2;
    [cardView addSubview:nameLabel];

    UILabel *handleLabel = [[UILabel alloc] init];
    handleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    handleLabel.font = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    handleLabel.textColor = [UIColor secondaryLabelColor];
    handleLabel.textAlignment = NSTextAlignmentCenter;
    handleLabel.numberOfLines = 1;
    [cardView addSubview:handleLabel];

    UILabel *metaLabel = [[UILabel alloc] init];
    metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    metaLabel.font = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    metaLabel.textColor = [brandColor colorWithAlphaComponent:0.92];
    metaLabel.textAlignment = NSTextAlignmentCenter;
    metaLabel.numberOfLines = 2;
    metaLabel.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.78];
    metaLabel.layer.cornerRadius = 17.0;
    metaLabel.layer.borderWidth = 1.0;
    metaLabel.layer.borderColor = [brandColor colorWithAlphaComponent:0.10].CGColor;
    metaLabel.layer.masksToBounds = YES;
    [cardView addSubview:metaLabel];

    UIButton *addPhotoButton = [UIButton buttonWithType:UIButtonTypeSystem];
    addPhotoButton.translatesAutoresizingMaskIntoConstraints = NO;
    [addPhotoButton setTitle:[self pp_localizedProfileStringForKey:@"Add Photo" fallback:@"Add Photo"] forState:UIControlStateNormal];
    [addPhotoButton setImage:[UIImage systemImageNamed:@"camera.fill"] forState:UIControlStateNormal];
    [addPhotoButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    addPhotoButton.tintColor = UIColor.whiteColor;
    addPhotoButton.backgroundColor = brandColor;
    addPhotoButton.layer.cornerRadius = 24.0;
    addPhotoButton.contentEdgeInsets = UIEdgeInsetsMake(0, 22, 0, 22);
    addPhotoButton.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    addPhotoButton.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 6);
    addPhotoButton.titleEdgeInsets = UIEdgeInsetsMake(0, 6, 0, 0);
    [addPhotoButton.titleLabel setFont:[GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold]];
    [addPhotoButton addTarget:self action:@selector(didTapAddPhoto) forControlEvents:UIControlEventTouchUpInside];
    [cardView addSubview:addPhotoButton];
    self.addPhotoBtn = addPhotoButton;

    [NSLayoutConstraint activateConstraints:@[
        [cardView.topAnchor constraintEqualToAnchor:self.headerRoot.topAnchor constant:10.0],
        [cardView.leadingAnchor constraintEqualToAnchor:self.headerRoot.leadingAnchor constant:20.0],
        [cardView.trailingAnchor constraintEqualToAnchor:self.headerRoot.trailingAnchor constant:-20.0],
        [cardView.bottomAnchor constraintEqualToAnchor:self.headerRoot.bottomAnchor constant:-14.0],

        [tintView.topAnchor constraintEqualToAnchor:cardView.topAnchor],
        [tintView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor],
        [tintView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor],
        [tintView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor],

        [ambientGlow.widthAnchor constraintEqualToConstant:188.0],
        [ambientGlow.heightAnchor constraintEqualToConstant:188.0],
        [ambientGlow.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:-82.0],
        [ambientGlow.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:82.0],

        [secondaryGlow.widthAnchor constraintEqualToConstant:116.0],
        [secondaryGlow.heightAnchor constraintEqualToConstant:116.0],
        [secondaryGlow.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:42.0],
        [secondaryGlow.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:-34.0],

        [accentBar.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:22.0],
        [accentBar.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [accentBar.widthAnchor constraintEqualToConstant:72.0],
        [accentBar.heightAnchor constraintEqualToConstant:6.0],

        [eyebrowPill.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:16.0],
        [eyebrowPill.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [eyebrowPill.trailingAnchor constraintLessThanOrEqualToAnchor:cardView.trailingAnchor constant:-24.0],
        [eyebrowPill.heightAnchor constraintGreaterThanOrEqualToConstant:28.0],

        [eyebrowLabel.topAnchor constraintEqualToAnchor:eyebrowPill.topAnchor constant:6.0],
        [eyebrowLabel.leadingAnchor constraintEqualToAnchor:eyebrowPill.leadingAnchor constant:12.0],
        [eyebrowLabel.trailingAnchor constraintEqualToAnchor:eyebrowPill.trailingAnchor constant:-12.0],
        [eyebrowLabel.bottomAnchor constraintEqualToAnchor:eyebrowPill.bottomAnchor constant:-6.0],

        [avatarHalo.centerXAnchor constraintEqualToAnchor:cardView.centerXAnchor],
        [avatarHalo.topAnchor constraintEqualToAnchor:eyebrowPill.bottomAnchor constant:20.0],
        [avatarHalo.widthAnchor constraintEqualToConstant:124.0],
        [avatarHalo.heightAnchor constraintEqualToConstant:124.0],

        [avatarView.centerXAnchor constraintEqualToAnchor:avatarHalo.centerXAnchor],
        [avatarView.centerYAnchor constraintEqualToAnchor:avatarHalo.centerYAnchor],
        [avatarView.widthAnchor constraintEqualToConstant:108.0],
        [avatarView.heightAnchor constraintEqualToConstant:108.0],

        [nameLabel.topAnchor constraintEqualToAnchor:avatarHalo.bottomAnchor constant:22.0],
        [nameLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [nameLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-24.0],

        [handleLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:8.0],
        [handleLabel.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor],
        [handleLabel.trailingAnchor constraintEqualToAnchor:nameLabel.trailingAnchor],

        [metaLabel.topAnchor constraintEqualToAnchor:handleLabel.bottomAnchor constant:14.0],
        [metaLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:cardView.leadingAnchor constant:34.0],
        [metaLabel.centerXAnchor constraintEqualToAnchor:cardView.centerXAnchor],
        [metaLabel.trailingAnchor constraintLessThanOrEqualToAnchor:cardView.trailingAnchor constant:-34.0],

        [addPhotoButton.topAnchor constraintEqualToAnchor:metaLabel.bottomAnchor constant:24.0],
        [addPhotoButton.centerXAnchor constraintEqualToAnchor:cardView.centerXAnchor],
        [addPhotoButton.widthAnchor constraintGreaterThanOrEqualToConstant:158.0],
        [addPhotoButton.heightAnchor constraintEqualToConstant:48.0],
        [addPhotoButton.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-24.0]
    ]];

    self.headerCardView = cardView;
    self.headerEyebrowLabel = eyebrowLabel;
    self.headerNameLabel = nameLabel;
    self.headerHandleLabel = handleLabel;
    self.headerMetaLabel = metaLabel;

    CGSize fittingSize = [self.headerRoot systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    self.headerRoot.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), fittingSize.height);
    self.tableView.tableHeaderView = self.headerRoot;
}

- (void)pp_refreshProfileHeaderContent
{
    NSString *firstName = [self pp_trimmedString:self.draftFirstName];
    if (firstName.length == 0) {
        firstName = [self pp_trimmedString:PPCurrentUser.FirstName];
    }
    NSString *lastName = [self pp_trimmedString:self.draftLastName];
    if (lastName.length == 0) {
        lastName = [self pp_trimmedString:PPCurrentUser.LastName];
    }
    NSArray<NSString *> *nameParts = [@[firstName ?: @"", lastName ?: @""]
        filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
    NSString *fullName = [nameParts componentsJoinedByString:@" "];
    NSString *draftHandle = [self pp_trimmedString:self.draftUserName];
    if (fullName.length == 0) {
        fullName = draftHandle.length > 0 ? draftHandle : [self pp_trimmedString:PPCurrentUser.UserName];
    }
    if (fullName.length == 0) {
        fullName = [self pp_localizedProfileStringForKey:@"UserProfile" fallback:@"Profile"];
    }

    NSString *handle = draftHandle.length > 0 ? draftHandle : [self pp_trimmedString:PPCurrentUser.UserName];
    if (handle.length > 0 && ![handle hasPrefix:@"@"]) {
        handle = [@"@" stringByAppendingString:handle];
    }
    if (handle.length == 0) {
        handle = [self pp_localizedProfileStringForKey:@"profile_identity_hint"
                                              fallback:@"Account details and saved places"];
    }

    NSString *email = [self pp_trimmedString:self.draftUserEmail];
    if (email.length == 0) {
        email = [self pp_trimmedString:PPCurrentUser.UserEmail];
    }

    NSString *phone = @"";
    NSString *draftLocalMobile = [self pp_trimmedString:self.draftMobileLocal];
    NSString *dialCode = [self pp_trimmedString:self.selectedCountry.phoneCode];
    if (draftLocalMobile.length > 0 && dialCode.length > 0) {
        phone = [NSString stringWithFormat:@"%@%@", dialCode, draftLocalMobile];
    } else {
        phone = [self pp_trimmedString:PPCurrentUser.MobileNo];
    }

    NSString *meta = nil;
    if (email.length > 0 && phone.length > 0) {
        meta = [NSString stringWithFormat:@"%@  •  %@", email, phone];
    } else {
        meta = email.length > 0 ? email : phone;
    }
    if (meta.length == 0) {
        meta = [self pp_localizedProfileStringForKey:@"member_since"
                                            fallback:@"Keep your identity and delivery details up to date."];
    }

    self.headerEyebrowLabel.text = [self pp_localizedProfileStringForKey:@"account" fallback:@"Account"];
    self.headerNameLabel.text = fullName;
    self.headerHandleLabel.text = handle;
    self.headerMetaLabel.text = [NSString stringWithFormat:@"  %@  ", meta];
}

#pragma mark - Table Data

- (NSIndexPath *)pp_indexPathForFieldKind:(PPProfileFieldKind)fieldKind
{
    switch (fieldKind) {
        case PPProfileFieldKindUserName:
            return [NSIndexPath indexPathForRow:PPProfileDetailRowUserName inSection:PPProfileSectionDetails];
        case PPProfileFieldKindFirstName:
            return [NSIndexPath indexPathForRow:PPProfileDetailRowFirstName inSection:PPProfileSectionDetails];
        case PPProfileFieldKindLastName:
            return [NSIndexPath indexPathForRow:PPProfileDetailRowLastName inSection:PPProfileSectionDetails];
        case PPProfileFieldKindMobile:
            return [NSIndexPath indexPathForRow:PPProfileContactRowMobile inSection:PPProfileSectionContact];
        case PPProfileFieldKindEmail:
            return [NSIndexPath indexPathForRow:PPProfileContactRowEmail inSection:PPProfileSectionContact];
        case PPProfileFieldKindAbout:
            return [NSIndexPath indexPathForRow:PPProfileContactRowAbout inSection:PPProfileSectionContact];
        default:
            break;
    }
    return nil;
}

- (BOOL)pp_isAddressActionRow:(NSIndexPath *)indexPath
{
    return indexPath.section == PPProfileSectionAddresses && indexPath.row == self.addresses.count;
}

- (BOOL)pp_isAddressRow:(NSIndexPath *)indexPath
{
    return indexPath.section == PPProfileSectionAddresses && indexPath.row < self.addresses.count;
}

- (void)pp_reloadRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    if (!self.isViewLoaded || !self.tableView) {
        return;
    }
    NSArray<NSIndexPath *> *visibleSafeRows = [indexPaths filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSIndexPath *evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [self.tableView numberOfSections] > evaluatedObject.section &&
        [self.tableView numberOfRowsInSection:evaluatedObject.section] > evaluatedObject.row;
    }]];
    if (visibleSafeRows.count == 0) {
        [self.tableView reloadData];
        return;
    }
    [self.tableView reloadRowsAtIndexPaths:visibleSafeRows withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return PPProfileSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case PPProfileSectionDetails:
            return PPProfileDetailRowCount;
        case PPProfileSectionContact:
            return PPProfileContactRowCount;
        case PPProfileSectionAddresses:
            return self.addresses.count + 1;
        default:
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == PPProfileSectionDetails) {
        PPProfileTextFieldCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProfileTextFieldCell" forIndexPath:indexPath];
        switch (indexPath.row) {
            case PPProfileDetailRowUserName:
                [cell configureWithTitle:kLang(@"UserName_Palce")
                                    text:self.draftUserName
                             placeholder:kLang(@"UserName_Palce")
                            keyboardType:UIKeyboardTypeDefault
                         textContentType:UITextContentTypeNickname
                           returnKeyType:UIReturnKeyNext
                  autocapitalizationType:UITextAutocapitalizationTypeWords
                               fieldKind:PPProfileFieldKindUserName
                                  target:self
                                  action:@selector(pp_textFieldEditingChanged:)
                                delegate:self];
                break;
            case PPProfileDetailRowFirstName:
                [cell configureWithTitle:kLang(@"firstName_Palce")
                                    text:self.draftFirstName
                             placeholder:kLang(@"Enter_First_Name")
                            keyboardType:UIKeyboardTypeDefault
                         textContentType:UITextContentTypeGivenName
                           returnKeyType:UIReturnKeyNext
                  autocapitalizationType:UITextAutocapitalizationTypeWords
                               fieldKind:PPProfileFieldKindFirstName
                                  target:self
                                  action:@selector(pp_textFieldEditingChanged:)
                                delegate:self];
                break;
            default:
                [cell configureWithTitle:kLang(@"LastName_Palce")
                                    text:self.draftLastName
                             placeholder:kLang(@"Enter_Last_Name")
                            keyboardType:UIKeyboardTypeDefault
                         textContentType:UITextContentTypeFamilyName
                           returnKeyType:UIReturnKeyNext
                  autocapitalizationType:UITextAutocapitalizationTypeWords
                               fieldKind:PPProfileFieldKindLastName
                                  target:self
                                  action:@selector(pp_textFieldEditingChanged:)
                                delegate:self];
                break;
        }
        return cell;
    }

    if (indexPath.section == PPProfileSectionContact) {
        switch (indexPath.row) {
            case PPProfileContactRowCountry: {
                PPProfileSelectorCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProfileSelectorCell" forIndexPath:indexPath];
                NSString *countryName = [self pp_trimmedString:self.selectedCountry.country];
                if (countryName.length == 0) {
                    countryName = kLang(@"TapToSelect");
                }
                [cell configureWithTitle:kLang(@"code_Palce")
                                   value:countryName
                                    flag:self.selectedCountry.flag ?: @""];
                return cell;
            }
            case PPProfileContactRowMobile: {
                PPProfilePhoneCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProfilePhoneCell" forIndexPath:indexPath];
                [cell configureWithTitle:kLang(@"MobileNo_Palce")
                                  prefix:[self pp_trimmedString:self.selectedCountry.phoneCode]
                                    text:self.draftMobileLocal
                             placeholder:kLang(@"MobileNo_Palce")
                               fieldKind:PPProfileFieldKindMobile
                                  target:self
                                  action:@selector(pp_textFieldEditingChanged:)
                                delegate:self];
                return cell;
            }
            case PPProfileContactRowEmail: {
                PPProfileTextFieldCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProfileTextFieldCell" forIndexPath:indexPath];
                [cell configureWithTitle:kLang(@"UserEmail_Palce")
                                    text:self.draftUserEmail
                             placeholder:kLang(@"UserEmail_Palce")
                            keyboardType:UIKeyboardTypeEmailAddress
                         textContentType:UITextContentTypeEmailAddress
                           returnKeyType:UIReturnKeyNext
                  autocapitalizationType:UITextAutocapitalizationTypeNone
                               fieldKind:PPProfileFieldKindEmail
                                  target:self
                                  action:@selector(pp_textFieldEditingChanged:)
                                delegate:self];
                cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
                cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
                return cell;
            }
            default: {
                PPProfileTextViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProfileTextViewCell" forIndexPath:indexPath];
                [cell configureWithTitle:kLang(@"UserAbout_Palce")
                                    text:self.draftUserAbout
                             placeholder:kLang(@"UserAbout_Palce")
                               fieldKind:PPProfileFieldKindAbout
                                delegate:self];
                return cell;
            }
        }
    }

    if ([self pp_isAddressActionRow:indexPath]) {
        PPProfileActionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProfileActionCell" forIndexPath:indexPath];
        [cell configureWithTitle:kLang(@"Add New Address") iconName:@"plus"];
        return cell;
    }

    PPProfileAddressCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProfileAddressCell" forIndexPath:indexPath];
    if (indexPath.row < self.addresses.count) {
        [cell configureWithAddress:self.addresses[indexPath.row]];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (!PPIOS26()) {
       // [Styling applyBackgroundStyleForTableView:tableView cell:cell indexPath:indexPath useRowCardMode:NO];
    }

    cell.backgroundColor = UIColor.clearColor;
    cell.clipsToBounds = NO;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.contentView.backgroundColor = [self pp_profileSurfaceColor];
    cell.contentView.layer.cornerRadius = 20.0;
    cell.contentView.layer.masksToBounds = YES;
    cell.contentView.layer.borderWidth = 1.0;
    cell.contentView.layer.borderColor = [self pp_profileSurfaceBorderColor].CGColor;
    cell.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:1.0].CGColor;
    cell.layer.shadowOpacity = 0.05;
    cell.layer.shadowRadius = 12.0;
    cell.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    cell.layer.masksToBounds = NO;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == PPProfileSectionContact && indexPath.row == PPProfileContactRowCountry) {
        return YES;
    }
    return [self pp_isAddressRow:indexPath] || [self pp_isAddressActionRow:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == PPProfileSectionContact && indexPath.row == PPProfileContactRowCountry) {
        [self pp_presentCountryPicker];
        return;
    }

    if ([self pp_isAddressActionRow:indexPath]) {
        [self openAddressFormForNew];
        return;
    }

    if ([self pp_isAddressRow:indexPath]) {
        PPAddressModel *address = self.addresses[indexPath.row];
        [self openAddressFormFor:address];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self pp_isAddressRow:indexPath];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle != UITableViewCellEditingStyleDelete || ![self pp_isAddressRow:indexPath]) {
        return;
    }

    PPAddressModel *address = self.addresses[indexPath.row];
    if (!address) {
        return;
    }

    [[PPAddressesManager sharedManager] deleteAddress:address completion:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [PPHUD showSuccess:kLang(@"AddressesDeleted") subtitle:@""];
            } else {
                [PPHUD showError:kLang(@"DeleteFailed") subtitle:error.localizedDescription ?: @""];
            }
            [self reloadAddressesSection];
        });
    }];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case PPProfileSectionDetails:
        case PPProfileSectionContact:
        case PPProfileSectionAddresses:
            return 76.0;
        default:
            return 0.000001;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 0.000001;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    return [UIView new];
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForFooterInSection:(NSInteger)section
{
    return 0.000001;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section
{
    return [self tableView:tableView heightForHeaderInSection:section];
}

- (NSArray<NSString *> *)pp_sectionHeaderContentForSection:(NSInteger)section
{
    switch (section) {
        case PPProfileSectionDetails:
            return @[
                kLang(@"profile_details"),
                kLang(@"profile_details_hint")
            ];
        case PPProfileSectionContact:
            return @[
                kLang(@"contact_and_bio"),
                kLang(@"contact_and_bio_hint")
            ];
        case PPProfileSectionAddresses:
            return @[
                kLang(@"saved_addresses"),
                kLang(@"saved_addresses_hint")
            ];
        default:
            return @[@"", @""];
    }
}

- (UIView *)pp_profileSectionHeaderViewWithTitle:(NSString *)title subtitle:(NSString *)subtitle
{
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = UIColor.clearColor;

    UIView *accentBar = [[UIView alloc] init];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    accentBar.layer.cornerRadius = 2.0;
    [container addSubview:accentBar];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.text = title ?: @"";
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [container addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.9];
    subtitleLabel.text = subtitle ?: @"";
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.numberOfLines = 2;
    [container addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [accentBar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20.0],
        [accentBar.topAnchor constraintEqualToAnchor:container.topAnchor constant:14.0],
        [accentBar.widthAnchor constraintEqualToConstant:28.0],
        [accentBar.heightAnchor constraintEqualToConstant:4.0],

        [titleLabel.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:9.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:accentBar.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:container.bottomAnchor constant:-8.0]
    ]];

    return container;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section >= PPProfileSectionCount) {
        return [UIView new];
    }
    NSArray<NSString *> *content = [self pp_sectionHeaderContentForSection:section];
    return [self pp_profileSectionHeaderViewWithTitle:content.firstObject subtitle:content.lastObject];
}

#pragma mark - Editing

- (void)pp_textFieldEditingChanged:(UITextField *)textField
{
    NSString *value = textField.text ?: @"";
    switch ((PPProfileFieldKind)textField.tag) {
        case PPProfileFieldKindUserName:
            self.draftUserName = value;
            [self setformDataArray:value forKey:@"UserName"];
            break;
        case PPProfileFieldKindFirstName:
            self.draftFirstName = value;
            [self setformDataArray:value forKey:@"firstName"];
            break;
        case PPProfileFieldKindLastName:
            self.draftLastName = value;
            [self setformDataArray:value forKey:@"LastName"];
            break;
        case PPProfileFieldKindMobile: {
            self.draftMobileLocal = value;
            NSString *countryCode = [self pp_trimmedString:self.selectedCountry.phoneCode];
            NSString *localNumber = [self pp_trimmedString:value];
            NSString *combined = localNumber.length > 0 ? [NSString stringWithFormat:@"%@%@", countryCode ?: @"", localNumber] : @"";
            [self setformDataArray:combined forKey:@"MobileNo"];
            [self setformDataArray:localNumber forKey:kMobileNoRow];
            break;
        }
        case PPProfileFieldKindEmail:
            self.draftUserEmail = value;
            [self setformDataArray:value forKey:@"UserEmail"];
            break;
        default:
            break;
    }

    [self pp_refreshProfileHeaderContent];
    [self markFormAsEdited];
}

- (void)textViewDidChange:(UITextView *)textView
{
    if ((PPProfileFieldKind)textView.tag == PPProfileFieldKindAbout) {
        self.draftUserAbout = textView.text ?: @"";
        [self setformDataArray:textView.text forKey:@"UserAbout"];
    }

    UIView *view = textView;
    while (view && ![view isKindOfClass:PPProfileTextViewCell.class]) {
        view = view.superview;
    }
    if ([view isKindOfClass:PPProfileTextViewCell.class]) {
        PPProfileTextViewCell *cell = (PPProfileTextViewCell *)view;
        [cell updatePlaceholderVisibility];
        [cell updatePreferredHeight];
    }

    [self.tableView beginUpdates];
    [self.tableView endUpdates];
    [self markFormAsEdited];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    switch ((PPProfileFieldKind)textField.tag) {
        case PPProfileFieldKindUserName:
            [self pp_focusFieldKind:PPProfileFieldKindFirstName];
            return NO;
        case PPProfileFieldKindFirstName:
            [self pp_focusFieldKind:PPProfileFieldKindLastName];
            return NO;
        case PPProfileFieldKindLastName:
            [self pp_focusFieldKind:PPProfileFieldKindEmail];
            return NO;
        case PPProfileFieldKindEmail:
            [self pp_focusFieldKind:PPProfileFieldKindAbout];
            return NO;
        default:
            [textField resignFirstResponder];
            return YES;
    }
}

- (void)pp_focusFieldKind:(PPProfileFieldKind)fieldKind
{
    NSIndexPath *indexPath = [self pp_indexPathForFieldKind:fieldKind];
    if (!indexPath) {
        return;
    }

    [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        if ([cell isKindOfClass:PPProfileTextFieldCell.class]) {
            [((PPProfileTextFieldCell *)cell).textField becomeFirstResponder];
        } else if ([cell isKindOfClass:PPProfilePhoneCell.class]) {
            [((PPProfilePhoneCell *)cell).textField becomeFirstResponder];
        } else if ([cell isKindOfClass:PPProfileTextViewCell.class]) {
            [((PPProfileTextViewCell *)cell).textView becomeFirstResponder];
        }
    });
}

- (void)pp_presentCountryPicker
{
    NSMutableArray<CountryCodeModel *> *countries = [GM getMiddleEastCountriesForLanguage:[Language currentLanguageCode]];
    if (countries.count == 0) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    PPSelectOptionViewController *vc = [[PPSelectOptionViewController alloc]
        initWithOptions:countries
                  title:kLang(@"code_Palce")
                    row:nil
       presentationStyle:PPSelectOptionPresentationSheet
             completion:^(id _Nullable selectedObject) {
        PPDispatchMain(^{
            if (![selectedObject isKindOfClass:[CountryCodeModel class]]) {
                return;
            }
            [weakSelf pp_updateSelectedCountry:(CountryCodeModel *)selectedObject userInitiated:YES];
        });
    }];
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)pp_updateSelectedCountry:(CountryCodeModel *)country userInitiated:(BOOL)userInitiated
{
    if (![country isKindOfClass:CountryCodeModel.class]) {
        return;
    }

    self.selectedCountry = country;
    [self setformDataArray:@(country.ID) forKey:@"CountryID"];
    [self pp_refreshProfileHeaderContent];
    [self pp_reloadRowsAtIndexPaths:@[
        [NSIndexPath indexPathForRow:PPProfileContactRowCountry inSection:PPProfileSectionContact],
        [NSIndexPath indexPathForRow:PPProfileContactRowMobile inSection:PPProfileSectionContact]
    ]];

    if (userInitiated) {
        [self markFormAsEdited];
    }
}

#pragma mark - Addresses

- (void)listenToAddresses
{
    [self.addressListener remove];
    self.addressListener = nil;

    if (PPCurrentUser.Addresses.count > 0) {
        [self pp_applyLatestAddresses:PPCurrentUser.Addresses];
    }

    NSString *authenticatedUID = [PPADDRESS currentAuthenticatedUserID] ?: @"";
    if (authenticatedUID.length == 0) {
        [self pp_applyLatestAddresses:@[]];
        return;
    }

    __weak typeof(self) weakSelf = self;
    self.addressListener = [[PPAddressesManager sharedManager]
        listenToAddressesWithBlock:^(NSArray<PPAddressModel *> * _Nullable addresses, NSError * _Nullable error) {
        if (error) {
            BOOL isUnauthenticatedError = [error.domain isEqualToString:@"PPAddressesManager"] && error.code == 401;
            if (isUnauthenticatedError || [PPADDRESS currentAuthenticatedUserID].length == 0) {
                [weakSelf pp_applyLatestAddresses:@[]];
                return;
            }
            NSLog(@"Address listener error: %@", error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                [PPHUD showError:kLang(@"SomethingWentWrong") subtitle:error.localizedDescription ?: @""];
            });
            return;
        }
        [weakSelf pp_applyLatestAddresses:addresses ?: @[]];
    }];
}

- (void)pp_applyLatestAddresses:(NSArray<PPAddressModel *> *)addresses
{
    self.addresses = addresses ?: @[];
    UserModel *currentUser = UserManager.sharedManager.currentUser;
    if (currentUser) {
        currentUser.Addresses = self.addresses.mutableCopy;
        [UserManager.sharedManager cacheUser:currentUser];
    }
    [self pp_refreshProfileHeaderContent];
    [self debouncedReloadAddresses];
}

- (void)debouncedReloadAddresses
{
    static BOOL isScheduled = NO;
    if (isScheduled) {
        return;
    }
    isScheduled = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self reloadAddressesSection];
        isScheduled = NO;
    });
}

- (void)reloadAddressesSection
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:PPProfileSectionAddresses];
        if (self.tableView.window) {
            [self.tableView reloadSections:indexSet withRowAnimation:UITableViewRowAnimationNone];
        } else {
            [self.tableView reloadData];
        }
    });
}

- (void)openAddressFormForNew
{
    AddressFormVC *vc = [[AddressFormVC alloc] init];
    vc.delegate = self;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openAddressFormFor:(PPAddressModel *)address
{
    AddressFormVC *vc = [[AddressFormVC alloc] initWithAddress:address];
    vc.delegate = self;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)addressFormVC:(AddressFormVC *)controller didSaveAddress:(PPAddressModel *)address
{
    __weak typeof(self) weakSelf = self;
    [PPADDRESS getAllAddressesWithCompletion:^(NSArray<PPAddressModel *> * _Nonnull addresses, NSError * _Nullable error) {
        if (error) {
            return;
        }
        [weakSelf pp_applyLatestAddresses:addresses ?: @[]];
    }];
}

- (void)addressFormVC:(AddressFormVC *)controller didDeleteAddress:(PPAddressModel *)address
{
    __weak typeof(self) weakSelf = self;
    [PPADDRESS getAllAddressesWithCompletion:^(NSArray<PPAddressModel *> * _Nonnull addresses, NSError * _Nullable error) {
        if (error) {
            return;
        }
        [weakSelf pp_applyLatestAddresses:addresses ?: @[]];
    }];
}

#pragma mark - Avatar

- (void)didTapAddPhoto
{
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Camera")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            [self openCamera];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Photo_Library")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        [self openPhotoPicker];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    sheet.popoverPresentationController.sourceView = self.addPhotoBtn;
    sheet.popoverPresentationController.sourceRect = self.addPhotoBtn.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)openPhotoPicker
{
    if (@available(iOS 14.0, *)) {
        PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
        config.filter = [PHPickerFilter imagesFilter];
        config.selectionLimit = 1;

        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    } else {
        [self openLegacyPicker];
    }
}

- (void)openLegacyPicker
{
    [PPPermissionHelper requestPhotoLibraryPermissionFromViewController:self completion:^(BOOL granted) {
        if (!granted) {
            return;
        }

        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        [self presentViewController:picker animated:YES completion:nil];
    }];
}

- (void)openCamera
{
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        return;
    }

    [PPPermissionHelper requestCameraPermissionFromViewController:self completion:^(BOOL granted) {
        if (!granted) {
            return;
        }
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        picker.sourceType = UIImagePickerControllerSourceTypeCamera;
        [self presentViewController:picker animated:YES completion:nil];
    }];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) {
        return;
    }

    PHPickerResult *result = results.firstObject;
    if ([result.itemProvider canLoadObjectOfClass:[UIImage class]]) {
        [result.itemProvider loadObjectOfClass:[UIImage class] completionHandler:^(UIImage *image, NSError *error) {
            if (image && !error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self handlePickedImage:image];
                });
            }
        }];
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info
{
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:^{
        [self handlePickedImage:image];
    }];
}

- (void)handlePickedImage:(UIImage *)image
{
    [UIImage pp_presentCircularCropperWithImage:image fromController:self];
}

- (void)cropViewController:(TOCropViewController *)cropViewController
     didCropToCircularImage:(UIImage *)image
                   withRect:(CGRect)cropRect
                      angle:(NSInteger)angle
{
    [self updateAvatar:image];
    [cropViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)updateAvatar:(UIImage *)image
{
    [UIView transitionWithView:self.avatarIMV
                      duration:0.3
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        self.pendingAvatarImage = image;
        self.avatarIMV.imageView.image = image;
        self.avatarIMV.tintColor = nil;
        self.avatarIMV.backgroundColor = UIColor.clearColor;
        [self markFormAsEdited];
    } completion:nil];

    [PPFunc triggerLightHaptic];
}

#pragma mark - Save / Validation

- (void)updateUserData
{
    if (self.isSavingProfile) {
        return;
    }

    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser.uid.length) {
        [PPAlertHelper showErrorIn:self title:kLang(@"PleaseRegister") subtitle:@""];
        return;
    }

    [self.view endEditing:YES];

    NSString *firstName = [self pp_trimmedString:self.draftFirstName];
    NSString *lastName = [self pp_trimmedString:self.draftLastName];
    NSString *userName = [self pp_trimmedString:self.draftUserName];
    NSString *userEmail = [[self pp_trimmedString:self.draftUserEmail] lowercaseString];
    NSString *about = [self pp_trimmedString:self.draftUserAbout];

    if (userName.length == 0) {
        NSString *composed = [NSString stringWithFormat:@"%@ %@", firstName ?: @"", lastName ?: @""];
        userName = [self pp_trimmedString:composed];
    }
    if (userName.length == 0) {
        [self pp_showValidationErrorForField:PPProfileFieldKindUserName subtitle:kLang(@"UserName_Palce")];
        return;
    }

    if (![self pp_isValidEmail:userEmail]) {
        [self pp_showValidationErrorForField:PPProfileFieldKindEmail subtitle:kLang(@"UserEmail_Palce")];
        return;
    }

    CountryCodeModel *country = self.selectedCountry;
    if (!country) {
        NSInteger fallbackCountryID = PPCurrentUser.CountryID;
        if (fallbackCountryID > 0) {
            country = [[self.contriesArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", fallbackCountryID]] firstObject];
        }
        if (!country) {
            country = [self pp_countryWithISOCode:[GM getCurrentCountryFromCarrier]];
        }
        if (!country) {
            country = [self pp_countryWithISOCode:CitiesManager.shared.CurrentCountry.iso];
        }
        if (!country) {
            country = [self pp_countryWithISOCode:[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode]];
        }
    }
    if (!country && self.contriesArray.count > 0) {
        country = [self pp_qatarCountry];
    }
    if (!country || country.ID <= 0) {
        [self pp_showCountryValidationError];
        return;
    }
    self.selectedCountry = country;

    NSString *countryDialCode = [self pp_trimmedString:country.phoneCode];
    if (countryDialCode.length > 0 && ![countryDialCode hasPrefix:@"+"]) {
        countryDialCode = [@"+" stringByAppendingString:countryDialCode];
    }
    NSString *countryISOCode = [[self pp_trimmedString:country.isoCountryCode] uppercaseString];
    if (countryDialCode.length == 0 || countryISOCode.length != 2) {
        [self pp_showCountryValidationError];
        return;
    }

    NSString *rawMobileInput = [self pp_trimmedString:self.draftMobileLocal];
    NSString *normalizedMobile = [self pp_normalizedE164FromInput:rawMobileInput dialCode:countryDialCode];
    NSString *existingMobile = [self pp_trimmedString:PPCurrentUser.MobileNo];
    if (rawMobileInput.length == 0 && existingMobile.length > 0) {
        NSString *fallbackDialCode = [existingMobile hasPrefix:@"+"] ? @"" : countryDialCode;
        normalizedMobile = [self pp_normalizedE164FromInput:existingMobile dialCode:fallbackDialCode];
    }
    if (rawMobileInput.length > 0 && normalizedMobile.length == 0) {
        [self pp_showValidationErrorForField:PPProfileFieldKindMobile subtitle:kLang(@"MobileNo_Palce")];
        return;
    }
    NSInteger mobileDigitsCount = [[normalizedMobile stringByReplacingOccurrencesOfString:@"+" withString:@""] length];
    if (normalizedMobile.length > 0 && (mobileDigitsCount < 8 || mobileDigitsCount > 15)) {
        [self pp_showValidationErrorForField:PPProfileFieldKindMobile subtitle:kLang(@"MobileNo_Palce")];
        return;
    }
    if (normalizedMobile.length > 0 && countryDialCode.length > 0 && ![normalizedMobile hasPrefix:countryDialCode]) {
        CountryCodeModel *mobileCountry = [self pp_countryFromStoredMobileNumber:normalizedMobile];
        if (!mobileCountry) {
            [self pp_showCountryValidationError];
            return;
        }
        self.selectedCountry = mobileCountry;
        country = mobileCountry;
        countryDialCode = [self pp_trimmedString:mobileCountry.phoneCode];
        if (countryDialCode.length > 0 && ![countryDialCode hasPrefix:@"+"]) {
            countryDialCode = [@"+" stringByAppendingString:countryDialCode];
        }
        countryISOCode = [[self pp_trimmedString:mobileCountry.isoCountryCode] uppercaseString];
        if (countryDialCode.length == 0 || countryISOCode.length != 2) {
            [self pp_showCountryValidationError];
            return;
        }
        [self setformDataArray:@(mobileCountry.ID) forKey:@"CountryID"];
        [self pp_reloadRowsAtIndexPaths:@[
            [NSIndexPath indexPathForRow:PPProfileContactRowCountry inSection:PPProfileSectionContact],
            [NSIndexPath indexPathForRow:PPProfileContactRowMobile inSection:PPProfileSectionContact]
        ]];
    }

    NSString *currentEmail = [[self pp_trimmedString:authUser.email] lowercaseString];
    NSString *baselineEmail = @"";
    id baselineEmailValue = self.profileDraftBaseline[@"userEmail"];
    if ([baselineEmailValue isKindOfClass:NSString.class]) {
        baselineEmail = [[self pp_trimmedString:baselineEmailValue] lowercaseString];
    }
    BOOL emailFieldEdited = ![userEmail isEqualToString:baselineEmail];
    if (userEmail.length == 0) {
        userEmail = currentEmail;
    }
    BOOL emailChanged = emailFieldEdited && ![userEmail isEqualToString:currentEmail];
    if (emailChanged) {
        NSString *authProviderID = @"";
        for (id<FIRUserInfo> provider in authUser.providerData) {
            NSString *providerID = [[self pp_trimmedString:provider.providerID] lowercaseString];
            if (providerID.length == 0 || [providerID isEqualToString:@"firebase"]) {
                continue;
            }
            authProviderID = providerID;
            break;
        }

        if ([authProviderID isEqualToString:@"google.com"] || [authProviderID isEqualToString:@"apple.com"]) {
            [PPAlertHelper showWarningIn:self title:kLang(@"UserEmail_Palce") subtitle:kLang(@"profile_email_managed_by_provider")];
            return;
        }

        if ([authProviderID isEqualToString:@"password"]) {
            [PPAlertHelper showWarningIn:self title:kLang(@"UserEmail_Palce") subtitle:kLang(@"profile_email_reauth_required")];
            return;
        }
    }

    NSString *existingAuthMobile = [self pp_trimmedString:authUser.phoneNumber];
    NSString *baselineMobileForCompare = existingAuthMobile.length > 0 ? existingAuthMobile : existingMobile;
    NSString *baselineDialHint = [baselineMobileForCompare hasPrefix:@"+"] ? @"" : countryDialCode;
    NSString *baselineNormalizedMobile = [self pp_normalizedE164FromInput:baselineMobileForCompare dialCode:baselineDialHint];

    NSString *draftBaselineLocalMobile = @"";
    id draftBaselineMobileValue = self.profileDraftBaseline[@"mobileLocal"];
    if ([draftBaselineMobileValue isKindOfClass:NSString.class]) {
        draftBaselineLocalMobile = [self pp_trimmedString:draftBaselineMobileValue];
    }
    NSString *draftBaselineRawMobile = draftBaselineLocalMobile.length > 0 ? draftBaselineLocalMobile : existingMobile;
    NSString *draftBaselineDialHint = draftBaselineRawMobile.length > 0 && ![draftBaselineRawMobile hasPrefix:@"+"] ? countryDialCode : @"";
    NSString *draftBaselineNormalizedMobile = [self pp_normalizedE164FromInput:draftBaselineRawMobile dialCode:draftBaselineDialHint];
    BOOL mobileFieldEdited = ![normalizedMobile isEqualToString:draftBaselineNormalizedMobile];
    BOOL editedDataIncludesMobileNumber = (self.formDataArray[@"MobileNo"] != nil) || (self.formDataArray[kMobileNoRow] != nil);
    BOOL mobileChanged = mobileFieldEdited && normalizedMobile.length > 0 && ![normalizedMobile isEqualToString:baselineNormalizedMobile];
    BOOL authUsesPhoneProvider = [self pp_authUser:authUser hasProviderID:@"phone"];

    NSMutableDictionary<NSString *, id> *updates = [NSMutableDictionary dictionary];
    updates[@"FirstName"] = firstName ?: @"";
    updates[@"LastName"] = lastName ?: @"";
    updates[@"UserName"] = userName;
    updates[@"UserAbout"] = about ?: @"";
    updates[@"CountryID"] = @(country.ID);
    updates[@"CountryName"] = country.country ?: @"";
    updates[@"CountryDialCode"] = countryDialCode;
    updates[@"CountryIsoCode"] = countryISOCode;
    if (normalizedMobile.length > 0) {
        updates[@"MobileNo"] = normalizedMobile;
    }
    if (emailChanged) {
        updates[@"UserEmail"] = userEmail ?: @"";
        updates[@"email"] = userEmail ?: @"";
    }
    updates[FUUpdateKeyDisplayName] = userName;

    __weak typeof(self) weakSelf = self;
    void (^commitUpdates)(void) = ^{
        [UsrMgr updateCurrentUserProfileWithValues:updates completion:^(NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) {
                    return;
                }

                [self pp_setProfileSaving:NO];
                [PPHUD dismiss];

                if (error) {
                    NSLog(@"Profile update failed: %@", error.localizedDescription);
                    [PPAlertHelper showErrorIn:self title:kLang(@"StatusSaveFailed") subtitle:error.localizedDescription ?: @""];
                    return;
                }

                [UsrMgr reloadCurrentUserWithCompletion:^(UserModel * _Nullable user, NSError * _Nullable loadError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (user && !loadError) {
                            [UsrMgr cacheUser:user];
                        }
                        [self pp_syncDraftStateFromCurrentUser];
                        [PPHUD showSuccess:kLang(@"Saved")];
                        if ([self.delegate respondsToSelector:@selector(refereshAvatar)]) {
                            [self.delegate refereshAvatar];
                        }
                    });
                }];
            });
        }];
    };

    void (^performSavePipeline)(void) = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        [self pp_setProfileSaving:YES];
        [PPHUD showLoading:kLang(@"Saving")];

        if (self.pendingAvatarImage) {
            [self uploadAvatar:self.pendingAvatarImage forUserID:authUser.uid completion:^(NSURL * _Nullable url, NSError * _Nullable err) {
                if (url.absoluteString.length > 0) {
                    updates[FUUpdateKeyPhotoURL] = url.absoluteString;
                    updates[@"UserImageUrl"] = url.absoluteString;
                    updates[@"photoURL"] = url.absoluteString;
                } else if (err) {
                    NSLog(@"Avatar upload failed, continuing without new avatar: %@", err.localizedDescription);
                }
                commitUpdates();
            }];
            return;
        }

        commitUpdates();
    };

    if (authUsesPhoneProvider && editedDataIncludesMobileNumber && mobileChanged) {
        [self pp_presentPhoneVerificationForProfileMobileChange:normalizedMobile completion:^(NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) {
                    return;
                }

                if (error) {
                    [PPAlertHelper showErrorIn:self title:kLang(@"StatusSaveFailed") subtitle:error.localizedDescription ?: @""];
                    return;
                }

                if (PPCurrentUser) {
                    PPCurrentUser.MobileNo = normalizedMobile;
                }
                performSavePipeline();
            });
        }];
        return;
    }

    performSavePipeline();
}

- (void)pp_showValidationErrorForField:(PPProfileFieldKind)fieldKind subtitle:(NSString *)subtitle
{
    NSIndexPath *indexPath = [self pp_indexPathForFieldKind:fieldKind];
    if (indexPath) {
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UITableViewCell *badCell = [self.tableView cellForRowAtIndexPath:indexPath];
            [self animateCell:badCell];
        });
    }
    [PPAlertHelper showInfoIn:self title:kLang(@"PleaseFillFields") subtitle:subtitle ?: @""];
}

- (void)pp_showCountryValidationError
{
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:PPProfileContactRowCountry inSection:PPProfileSectionContact];
    [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UITableViewCell *badCell = [self.tableView cellForRowAtIndexPath:indexPath];
        [self animateCell:badCell];
    });
    [PPAlertHelper showInfoIn:self title:kLang(@"PleaseFillFields") subtitle:kLang(@"SelectCountry")];
}

- (void)animateCell:(UITableViewCell *)cell
{
    if (!cell) {
        return;
    }
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animation];
    animation.keyPath = @"position.x";
    animation.values = @[@0, @20, @-20, @10, @0];
    animation.keyTimes = @[@0, @(1 / 6.0), @(3 / 6.0), @(5 / 6.0), @1];
    animation.duration = 0.3;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    animation.additive = YES;
    [cell.layer addAnimation:animation forKey:@"shake"];
}

#pragma mark - Phone Verification / Upload

- (void)uploadAvatar:(UIImage *)image
           forUserID:(NSString *)userID
          completion:(void (^)(NSURL * _Nullable url, NSError * _Nullable error))completion
{
    if (!image || userID.length == 0) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"app.profile" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Missing image or user id"}]);
        }
        return;
    }

    NSData *jpeg = UIImageJPEGRepresentation(image, 0.82);
    if (!jpeg) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"app.profile" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Could not encode image"}]);
        }
        return;
    }

    NSString *fileName = [NSString stringWithFormat:@"avatar_%@", @((long long)(NSDate.date.timeIntervalSince1970 * 1000))];
    NSString *path = [NSString stringWithFormat:@"users/%@/%@.jpg", userID, fileName];

    FIRStorage *storage = [FIRStorage storage];
    FIRStorageReference *ref = [[storage reference] child:path];

    FIRStorageMetadata *meta = [FIRStorageMetadata new];
    meta.contentType = @"image/jpeg";

    [ref putData:jpeg metadata:meta completion:^(FIRStorageMetadata * _Nullable metadata, NSError * _Nullable error) {
        if (error) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }
        [ref downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error2) {
            if (completion) {
                completion(URL, error2);
            }
        }];
    }];
}

- (void)pp_presentPhoneVerificationForProfileMobileChange:(NSString *)newMobile
                                              completion:(void (^)(NSError * _Nullable error))completion
{
    NSString *safePhone = [self pp_trimmedString:newMobile];
    if (safePhone.length == 0) {
        if (completion) {
            NSError *invalidPhoneError = [NSError errorWithDomain:@"ProfileVC.PhoneUpdate"
                                                             code:1001
                                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"auth_phone_required_message")}];
            completion(invalidPhoneError);
        }
        return;
    }

    [PPHUD showLoading:kLang(@"auth_sending_code_title")];

    __weak typeof(self) weakSelf = self;
    __block NSString *currentVerificationID = @"";
    void (^sendCodeToPhone)(PPVerificationResendCompletion resendCompletion) = ^(PPVerificationResendCompletion resendCompletion) {
        [[FIRPhoneAuthProvider provider] verifyPhoneNumber:safePhone UIDelegate:nil completion:^(NSString * _Nullable verificationID, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error || verificationID.length == 0) {
                    if (resendCompletion) {
                        NSError *resolvedError = error ?: [NSError errorWithDomain:@"ProfileVC.PhoneUpdate"
                                                                              code:1002
                                                                          userInfo:@{NSLocalizedDescriptionKey: kLang(@"auth_sending_code_failed_title")}];
                        resendCompletion(NO, resolvedError);
                    }
                    return;
                }

                currentVerificationID = verificationID ?: @"";
                [[NSUserDefaults standardUserDefaults] setObject:currentVerificationID forKey:@"authVerificationID"];
                [[NSUserDefaults standardUserDefaults] synchronize];

                if (resendCompletion) {
                    resendCompletion(YES, nil);
                }
            });
        }];
    };

    sendCodeToPhone(^(BOOL success, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            if (completion) {
                NSError *deallocatedError = [NSError errorWithDomain:@"ProfileVC.PhoneUpdate"
                                                                code:1003
                                                            userInfo:@{NSLocalizedDescriptionKey: @"Session expired. Please try again."}];
                completion(deallocatedError);
            }
            return;
        }

        [PPHUD dismiss];

        if (!success) {
            if (completion) {
                completion(error);
            }
            return;
        }

        PPVerificationCodeViewController *vc = [[PPVerificationCodeViewController alloc] initWithPhone:safePhone];
        vc.onCodeVerificationRequested = ^(NSString *code, PPVerificationCodeCheckCompletion codeCompletion) {
            NSString *verificationID = currentVerificationID.length
                ? currentVerificationID
                : ([[NSUserDefaults standardUserDefaults] stringForKey:@"authVerificationID"] ?: @"");
            if (verificationID.length == 0) {
                NSError *missingVerificationError = [NSError errorWithDomain:@"ProfileVC.PhoneUpdate"
                                                                        code:1004
                                                                    userInfo:@{NSLocalizedDescriptionKey: kLang(@"invalid_code_message")}];
                if (codeCompletion) {
                    codeCompletion(NO, missingVerificationError);
                }
                return;
            }

            FIRUser *currentAuthUser = [FIRAuth auth].currentUser;
            if (!currentAuthUser) {
                NSError *authMissingError = [NSError errorWithDomain:@"ProfileVC.PhoneUpdate"
                                                                code:1005
                                                            userInfo:@{NSLocalizedDescriptionKey: kLang(@"PleaseRegister")}];
                if (codeCompletion) {
                    codeCompletion(NO, authMissingError);
                }
                return;
            }

            FIRPhoneAuthCredential *credential = [[FIRPhoneAuthProvider provider] credentialWithVerificationID:verificationID verificationCode:code ?: @""];
            [currentAuthUser updatePhoneNumberCredential:credential completion:^(NSError * _Nullable updateError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (updateError) {
                        if (codeCompletion) {
                            codeCompletion(NO, updateError);
                        }
                        return;
                    }

                    if (completion) {
                        completion(nil);
                    }
                    if (codeCompletion) {
                        codeCompletion(YES, nil);
                    }
                });
            }];
        };
        vc.onResendRequested = ^(PPVerificationResendCompletion resendCompletion) {
            sendCodeToPhone(resendCompletion);
        };

        [PPFunc presentSheetFrom:self sheetVC:vc detentStyle:PPSheetDetentStyleMediumOnly];
    });
}

#pragma mark - Logout / Language

- (void)logoutTapped
{
    NSString *lastSelectedLanguage = Language.currentLanguageCode;
    LeaveFeedbackViewController *feedbackVC = [[LeaveFeedbackViewController alloc] init];
    feedbackVC.onLogout = ^{
        [Language userSelectedLanguage:lastSelectedLanguage];
        [self applyLanguageChangeAndReloadUIFrom:self];
        [AppData stopAllListeners];
    };
    [PPFunc presentSheetFrom:self sheetVC:feedbackVC detentStyle:PPSheetDetentStyle70];
}

- (void)applyLanguageChangeAndReloadUIFrom:(UIViewController *)sourceVC
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [self keyWindow];
        if (!window) {
            return;
        }

        UIViewController *newRoot = [self buildRootController];
        if (!newRoot) {
            return;
        }

        [UIView transitionWithView:window
                          duration:0.35
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            BOOL old = [UIView areAnimationsEnabled];
            [UIView setAnimationsEnabled:NO];
            window.rootViewController = newRoot;
            [window makeKeyAndVisible];
            [UIView setAnimationsEnabled:old];
        } completion:nil];
    });
}

- (UIWindow *)keyWindow
{
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        if (window.isKeyWindow) {
            return window;
        }
    }
    return UIApplication.sharedApplication.windows.firstObject;
}

- (UIViewController *)buildRootController
{
    return [[PPRootTabBarController alloc] init];
}

#pragma mark - Navigation Guard

- (BOOL)navigationShouldPopOnBackButton
{
    if (!self.showingSave) {
        return YES;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"Confirm")
                                                                   message:kLang(@"changes_not_saved")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Discard")
                                              style:UIAlertActionStyleDestructive
                                            handler:^(__unused UIAlertAction *action) {
        self.showingSave = NO;
        [self.navigationController popViewControllerAnimated:YES];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
    return NO;
}

- (void)onBack
{
    if (self.showingSave) {
        [PPAlertHelper showConfirmationIn:self
                                    title:kLang(@"unsaved_changes_title")
                                 subtitle:kLang(@"unsaved_changes_message")
                            confirmButton:kLang(@"leave_button")
                             cancelButton:kLang(@"stay_button")
                                     icon:nil
                              confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
            if (!didConfirm) {
                return;
            }
            [super onBack];
        } cancelBlock:nil];
        return;
    }

    [super onBack];
}

#pragma mark - Helpers

- (NSString *)pp_trimmedString:(id)value
{
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (BOOL)pp_isValidEmail:(NSString *)email
{
    if (email.length == 0) {
        return YES;
    }
    NSString *pattern = @"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES[c] %@", pattern];
    return [predicate evaluateWithObject:email];
}

- (NSString *)pp_digitsOnlyString:(NSString *)value
{
    NSString *raw = [self pp_trimmedString:value];
    if (raw.length == 0) {
        return @"";
    }

    NSMutableString *digits = [NSMutableString string];
    NSCharacterSet *digitSet = NSCharacterSet.decimalDigitCharacterSet;
    for (NSUInteger i = 0; i < raw.length; i++) {
        unichar ch = [raw characterAtIndex:i];
        if (ch >= '0' && ch <= '9') {
            [digits appendFormat:@"%c", (char)ch];
            continue;
        }
        if (ch >= 0x0660 && ch <= 0x0669) {
            [digits appendFormat:@"%c", (char)('0' + (ch - 0x0660))];
            continue;
        }
        if (ch >= 0x06F0 && ch <= 0x06F9) {
            [digits appendFormat:@"%c", (char)('0' + (ch - 0x06F0))];
            continue;
        }
        if (ch >= 0xFF10 && ch <= 0xFF19) {
            [digits appendFormat:@"%c", (char)('0' + (ch - 0xFF10))];
            continue;
        }
        if ([digitSet characterIsMember:ch]) {
            NSString *scalar = [NSString stringWithCharacters:&ch length:1];
            NSInteger numeric = [scalar integerValue];
            if (numeric >= 0 && numeric <= 9) {
                [digits appendFormat:@"%ld", (long)numeric];
            }
        }
    }
    return digits;
}

- (CountryCodeModel *)pp_countryFromStoredMobileNumber:(NSString *)mobile
{
    NSString *trimmed = [self pp_trimmedString:mobile];
    if (trimmed.length == 0 || ![trimmed hasPrefix:@"+"]) {
        return nil;
    }

    CountryCodeModel *best = nil;
    NSUInteger bestLength = 0;
    for (CountryCodeModel *candidate in self.contriesArray ?: @[]) {
        NSString *dial = [self pp_trimmedString:candidate.phoneCode];
        if (dial.length == 0 || ![dial hasPrefix:@"+"]) {
            continue;
        }
        if ([trimmed hasPrefix:dial] && dial.length > bestLength) {
            best = candidate;
            bestLength = dial.length;
        }
    }
    return best;
}

- (CountryCodeModel *)pp_countryWithISOCode:(NSString *)isoCode
{
    NSString *trimmedISO = [[self pp_trimmedString:isoCode] uppercaseString];
    if (trimmedISO.length != 2) {
        return nil;
    }

    for (CountryCodeModel *candidate in self.contriesArray ?: @[]) {
        NSString *candidateISO = [[self pp_trimmedString:candidate.isoCountryCode] uppercaseString];
        if ([candidateISO isEqualToString:trimmedISO]) {
            return candidate;
        }
    }
    return nil;
}

- (CountryCodeModel *)pp_qatarCountry
{
    CountryCodeModel *qatar = [self pp_countryWithISOCode:@"QA"];
    return qatar ?: self.contriesArray.firstObject;
}

- (NSString *)pp_localPhonePartFromE164:(NSString *)mobile dialCode:(NSString *)dialCode
{
    NSString *trimmedMobile = [self pp_trimmedString:mobile];
    NSString *trimmedDialCode = [self pp_trimmedString:dialCode];
    if (trimmedMobile.length == 0 || trimmedDialCode.length == 0) {
        return trimmedMobile;
    }

    NSString *dialDigits = [trimmedDialCode stringByReplacingOccurrencesOfString:@"+" withString:@""];
    NSString *mobileDigits = [[trimmedMobile stringByReplacingOccurrencesOfString:@"+" withString:@""]
        stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (dialDigits.length > 0 && [mobileDigits hasPrefix:dialDigits]) {
        return [mobileDigits substringFromIndex:dialDigits.length];
    }
    return trimmedMobile;
}

- (NSString *)pp_normalizedE164FromInput:(id)input dialCode:(NSString *)dialCode
{
    NSString *raw = [self pp_trimmedString:input];
    if (raw.length == 0) {
        return @"";
    }

    NSString *digits = [self pp_digitsOnlyString:raw];
    if (digits.length == 0) {
        return @"";
    }

    NSString *dialDigits = [[self pp_trimmedString:dialCode] stringByReplacingOccurrencesOfString:@"+" withString:@""];
    if (dialDigits.length > 0) {
        if ([digits hasPrefix:dialDigits] || [raw hasPrefix:@"+"]) {
            return [NSString stringWithFormat:@"+%@", digits];
        }
        return [NSString stringWithFormat:@"+%@%@", dialDigits, digits];
    }
    return [NSString stringWithFormat:@"+%@", digits];
}

- (BOOL)pp_authUser:(FIRUser *)authUser hasProviderID:(NSString *)providerID
{
    NSString *targetProviderID = [[self pp_trimmedString:providerID] lowercaseString];
    if (!authUser || targetProviderID.length == 0) {
        return NO;
    }

    for (id<FIRUserInfo>provider in authUser.providerData) {
        NSString *candidate = [[self pp_trimmedString:provider.providerID] lowercaseString];
        if ([candidate isEqualToString:targetProviderID]) {
            return YES;
        }
    }
    return NO;
}

@end
