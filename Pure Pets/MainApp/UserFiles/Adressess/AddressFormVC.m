//
//  AddressFormVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/10/2025.
//

#import "AddressFormVC.h"
#import "CountryModel.h"
#import "CityModel.h"
#import "GM.h"
#import "LocationPickerViewController.h"
#import "CountryCodeModel.h"
#import "PPFormEngine.h"
#import "PPSelectOptionViewController.h"
//#import "PPButtonHelper.h"
@import FirebaseAuth;
@import CoreLocation;
#import <float.h>
#import <math.h>


typedef NS_ENUM(NSInteger, PPAddressSectionKind) {
    PPAddressSectionKindRecipient = 0,
    PPAddressSectionKindStreet,
    PPAddressSectionKindGeography,
    PPAddressSectionKindPreferences,
    PPAddressSectionKindDanger
};

typedef NS_ENUM(NSInteger, PPAddressFieldKind) {
    PPAddressFieldKindFullName = 1,
    PPAddressFieldKindPhoneNumber,
    PPAddressFieldKindAddressLine1,
    PPAddressFieldKindAddressLine2,
    PPAddressFieldKindPostalCode,
    PPAddressFieldKindCountry,
    PPAddressFieldKindCity,
    PPAddressFieldKindState,
    PPAddressFieldKindLocation
};

static NSString *const PPAddressFormFieldFullName = @"address.fullName";
static NSString *const PPAddressFormFieldPhoneCode = @"address.phoneCode";
static NSString *const PPAddressFormFieldPhone = @"address.phone";
static NSString *const PPAddressFormFieldAddressLine1 = @"address.line1";
static NSString *const PPAddressFormFieldAddressLine2 = @"address.line2";
static NSString *const PPAddressFormFieldPostalCode = @"address.postalCode";
static NSString *const PPAddressFormFieldCountry = @"address.country";
static NSString *const PPAddressFormFieldCity = @"address.city";
static NSString *const PPAddressFormFieldState = @"address.state";
static NSString *const PPAddressFormFieldLocation = @"address.location";

static const CGFloat kPPAddressCellHorizontalInset = PPSpaceBase;
static const CGFloat kPPAddressCellVerticalInset   = PPSpaceXS;

static UIFont *PPAddressScaledFont(UIFont *font, UIFontTextStyle textStyle)
{
    if (!font) {
        return [UIFont preferredFontForTextStyle:textStyle];
    }
    if (font.fontDescriptor.fontAttributes[UIFontDescriptorTextStyleAttribute] != nil) {
        return font;
    }
    return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:font];
}

static inline UISemanticContentAttribute PPAddressCurrentSemanticAttribute(void) {
    return Language.isRTL
        ? UISemanticContentAttributeForceRightToLeft
        : UISemanticContentAttributeForceLeftToRight;
}

@interface PPAddressBaseCell : UITableViewCell
@end

@implementation PPAddressBaseCell

- (void)setFrame:(CGRect)frame
{
    frame = UIEdgeInsetsInsetRect(frame, UIEdgeInsetsMake(kPPAddressCellVerticalInset * 0.5,
                                                           kPPAddressCellHorizontalInset,
                                                           kPPAddressCellVerticalInset * 0.5,
                                                           kPPAddressCellHorizontalInset));
    [super setFrame:frame];
}

@end

@interface PPAddressTextFieldCell : PPAddressBaseCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITextField *textField;
- (void)configureWithTitle:(NSString *)title
                      text:(NSString *)text
               placeholder:(NSString *)placeholder
              keyboardType:(UIKeyboardType)keyboardType
           textContentType:(UITextContentType)textContentType
             returnKeyType:(UIReturnKeyType)returnKeyType
    autocapitalizationType:(UITextAutocapitalizationType)autocapitalizationType
                 fieldKind:(PPAddressFieldKind)fieldKind
                    target:(id)target
                    action:(SEL)action
                  delegate:(id<UITextFieldDelegate>)delegate;
@end

@implementation PPAddressTextFieldCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = PPAddressCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPAddressCurrentSemanticAttribute();

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = PPAddressScaledFont([GM boldFontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:PPFontSubheadline weight:UIFontWeightSemibold], UIFontTextStyleSubheadline);
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.adjustsFontForContentSizeCategory = YES;
    [self.contentView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    UITextField *textField = [[UITextField alloc] init];
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    textField.borderStyle = UITextBorderStyleNone;
    textField.backgroundColor = UIColor.clearColor;
    textField.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    textField.font = PPAddressScaledFont([GM MidFontWithSize:PPFontBody] ?: [UIFont systemFontOfSize:PPFontBody weight:UIFontWeightMedium], UIFontTextStyleBody);
    textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.adjustsFontForContentSizeCategory = YES;
    textField.semanticContentAttribute = PPAddressCurrentSemanticAttribute();
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
        [textField.heightAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin]
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
                 fieldKind:(PPAddressFieldKind)fieldKind
                    target:(id)target
                    action:(SEL)action
                  delegate:(id<UITextFieldDelegate>)delegate
{
    self.semanticContentAttribute = PPAddressCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPAddressCurrentSemanticAttribute();
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.titleLabel.accessibilityElementsHidden = YES;

    self.textField.text = text ?: @"";
    self.textField.placeholder = placeholder ?: @"";
    self.textField.accessibilityLabel = title ?: placeholder ?: @"";
    self.textField.accessibilityHint = placeholder ?: @"";
    self.textField.tag = fieldKind;
    self.textField.delegate = delegate;
    self.textField.keyboardType = keyboardType;
    self.textField.textContentType = textContentType;
    self.textField.returnKeyType = returnKeyType;
    self.textField.autocapitalizationType = autocapitalizationType;
    self.textField.textAlignment = fieldKind == PPAddressFieldKindPhoneNumber
        ? NSTextAlignmentLeft
        : Language.alignmentForCurrentLanguage;
    self.textField.semanticContentAttribute = fieldKind == PPAddressFieldKindPhoneNumber
        ? UISemanticContentAttributeForceLeftToRight
        : PPAddressCurrentSemanticAttribute();

    [self.textField removeTarget:nil action:NULL forControlEvents:UIControlEventEditingChanged];
    if (target && action) {
        [self.textField addTarget:target action:action forControlEvents:UIControlEventEditingChanged];
    }
}

@end

#pragma mark - PPAddressPhoneCell

@interface PPAddressPhoneCell : PPAddressBaseCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *countryCodeButton;
@property (nonatomic, strong) UITextField *phoneTextField;
@property (nonatomic, assign) PPAddressFieldKind fieldKind;
- (void)configureWithTitle:(NSString *)title
             countryCodeTitle:(NSString *)countryCodeTitle
                    phoneText:(NSString *)phoneText
                 placeholder:(NSString *)placeholder
                  fieldKind:(PPAddressFieldKind)fieldKind
                     target:(id)target
              countryAction:(SEL)countryAction
               phoneAction:(SEL)phoneAction
                   delegate:(id<UITextFieldDelegate>)delegate;
@end

@implementation PPAddressPhoneCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    _titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    _titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.contentView addSubview:_titleLabel];

    // Country code picker button
    UIButtonConfiguration *btnCfg;
    btnCfg = [UIButtonConfiguration tintedButtonConfiguration];
    btnCfg.contentInsets = NSDirectionalEdgeInsetsMake(PPSpaceSM, PPSpaceMD, PPSpaceSM, PPSpaceMD);
    btnCfg.baseForegroundColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    btnCfg.baseBackgroundColor = [(AppPrimaryClr ?: UIColor.systemOrangeColor) colorWithAlphaComponent:0.10];
    _countryCodeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _countryCodeButton.configuration = btnCfg;
    _countryCodeButton.translatesAutoresizingMaskIntoConstraints = NO;
    _countryCodeButton.backgroundColor = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.10 : 0.94];
    _countryCodeButton.layer.cornerRadius = PPCornerSmall;
    _countryCodeButton.clipsToBounds = YES;
    _countryCodeButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    _countryCodeButton.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    [self.contentView addSubview:_countryCodeButton];
    [_countryCodeButton.widthAnchor constraintGreaterThanOrEqualToConstant:88].active = YES;
    [_countryCodeButton.heightAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin].active = YES;

    // Phone text field
    _phoneTextField = [[UITextField alloc] init];
    _phoneTextField.translatesAutoresizingMaskIntoConstraints = NO;
    _phoneTextField.borderStyle = UITextBorderStyleNone;
    _phoneTextField.backgroundColor = UIColor.clearColor;
    _phoneTextField.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    _phoneTextField.font = PPAddressScaledFont([GM MidFontWithSize:PPFontBody] ?: [UIFont systemFontOfSize:PPFontBody weight:UIFontWeightMedium], UIFontTextStyleBody);
    _phoneTextField.keyboardType = UIKeyboardTypeASCIICapableNumberPad;
    _phoneTextField.textContentType = UITextContentTypeTelephoneNumber;
    _phoneTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _phoneTextField.adjustsFontForContentSizeCategory = YES;
    _phoneTextField.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    _phoneTextField.textAlignment = NSTextAlignmentLeft;
    [self.contentView addSubview:_phoneTextField];

    [NSLayoutConstraint activateConstraints:@[
        [_titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14.0],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],

        [_countryCodeButton.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_countryCodeButton.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:8.0],
        [_countryCodeButton.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0],

        [_phoneTextField.leadingAnchor constraintEqualToAnchor:_countryCodeButton.trailingAnchor constant:10.0],
        [_phoneTextField.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
        [_phoneTextField.centerYAnchor constraintEqualToAnchor:_countryCodeButton.centerYAnchor],
        [_phoneTextField.heightAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin]
    ]];

    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [_countryCodeButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [_phoneTextField removeTarget:nil action:NULL forControlEvents:UIControlEventEditingChanged];
}

- (void)configureWithTitle:(NSString *)title
             countryCodeTitle:(NSString *)countryCodeTitle
                    phoneText:(NSString *)phoneText
                 placeholder:(NSString *)placeholder
                  fieldKind:(PPAddressFieldKind)fieldKind
                     target:(id)target
              countryAction:(SEL)countryAction
               phoneAction:(SEL)phoneAction
                   delegate:(id<UITextFieldDelegate>)delegate
{
    self.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    self.contentView.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.titleLabel.accessibilityElementsHidden = YES;

    self.fieldKind = fieldKind;
    NSAttributedString *attributedCode = [[NSAttributedString alloc] initWithString:countryCodeTitle ?: @""
                                                                         attributes:@{
        NSFontAttributeName: [GM boldFontWithSize:16] ?: [UIFont boldSystemFontOfSize:16],
        NSForegroundColorAttributeName: AppPrimaryClr ?: UIColor.systemOrangeColor
    }];
    [self.countryCodeButton setAttributedTitle:attributedCode forState:UIControlStateNormal];
    self.countryCodeButton.accessibilityLabel = kLang(@"Country") ?: @"Country code";
    self.countryCodeButton.accessibilityValue = countryCodeTitle ?: @"";

    self.phoneTextField.text = phoneText ?: @"";
    self.phoneTextField.placeholder = placeholder ?: @"";
    self.phoneTextField.accessibilityLabel = title ?: placeholder ?: @"";
    self.phoneTextField.accessibilityHint = placeholder ?: @"";
    self.phoneTextField.tag = fieldKind;
    self.phoneTextField.delegate = delegate;

    [self.countryCodeButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    if (target && countryAction) {
        [self.countryCodeButton addTarget:target action:countryAction forControlEvents:UIControlEventTouchUpInside];
    }

    [self.phoneTextField removeTarget:nil action:NULL forControlEvents:UIControlEventEditingChanged];
    if (target && phoneAction) {
        [self.phoneTextField addTarget:target action:phoneAction forControlEvents:UIControlEventEditingChanged];
    }
}

@end

@interface PPAddressSelectorCell : PPAddressBaseCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *valueLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UIImageView *chevronView;
- (void)configureWithTitle:(NSString *)title
                     value:(NSString *)value
               placeholder:(NSString *)placeholder
                    detail:(NSString *)detail;
@end

@implementation PPAddressSelectorCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = PPAddressCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPAddressCurrentSemanticAttribute();

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = PPAddressScaledFont([GM boldFontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:PPFontSubheadline weight:UIFontWeightSemibold], UIFontTextStyleSubheadline);
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.adjustsFontForContentSizeCategory = YES;
    [self.contentView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    UILabel *valueLabel = [[UILabel alloc] init];
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.font = PPAddressScaledFont([GM MidFontWithSize:PPFontBody] ?: [UIFont systemFontOfSize:PPFontBody weight:UIFontWeightMedium], UIFontTextStyleBody);
    valueLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    valueLabel.numberOfLines = 2;
    valueLabel.textAlignment = Language.alignmentForCurrentLanguage;
    valueLabel.adjustsFontForContentSizeCategory = YES;
    [self.contentView addSubview:valueLabel];
    self.valueLabel = valueLabel;

    UILabel *detailLabel = [[UILabel alloc] init];
    detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    detailLabel.font = PPAddressScaledFont([GM MidFontWithSize:PPFontFootnote] ?: [UIFont systemFontOfSize:PPFontFootnote weight:UIFontWeightMedium], UIFontTextStyleFootnote);
    detailLabel.textColor = [UIColor secondaryLabelColor];
    detailLabel.numberOfLines = 2;
    detailLabel.textAlignment = Language.alignmentForCurrentLanguage;
    detailLabel.adjustsFontForContentSizeCategory = YES;
    [self.contentView addSubview:detailLabel];
    self.detailLabel = detailLabel;

    UIImageView *chevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down"]];
    chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    chevronView.tintColor = [[UIColor secondaryLabelColor] colorWithAlphaComponent:0.8];
    chevronView.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:chevronView];
    self.chevronView = chevronView;

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],

        [chevronView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [chevronView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [chevronView.widthAnchor constraintEqualToConstant:14.0],
        [chevronView.heightAnchor constraintEqualToConstant:14.0],

        [valueLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [valueLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [valueLabel.trailingAnchor constraintEqualToAnchor:chevronView.leadingAnchor constant:-12.0],

        [detailLabel.topAnchor constraintEqualToAnchor:valueLabel.bottomAnchor constant:4.0],
        [detailLabel.leadingAnchor constraintEqualToAnchor:valueLabel.leadingAnchor],
        [detailLabel.trailingAnchor constraintEqualToAnchor:valueLabel.trailingAnchor],
        [detailLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-18.0]
    ]];

    return self;
}

- (void)configureWithTitle:(NSString *)title
                     value:(NSString *)value
               placeholder:(NSString *)placeholder
                    detail:(NSString *)detail
{
    self.semanticContentAttribute = PPAddressCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPAddressCurrentSemanticAttribute();
    NSString *trimmedValue = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL hasValue = trimmedValue.length > 0;

    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;

    self.valueLabel.text = hasValue ? trimmedValue : (placeholder ?: @"");
    self.valueLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.valueLabel.textColor = hasValue
        ? (AppPrimaryTextClr ?: UIColor.labelColor)
        : [[UIColor secondaryLabelColor] colorWithAlphaComponent:0.95];

    self.detailLabel.text = detail ?: @"";
    self.detailLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.detailLabel.hidden = detail.length == 0;

    NSMutableArray<NSString *> *accessibilityParts = [NSMutableArray arrayWithObject:title ?: @""];
    [accessibilityParts addObject:hasValue ? trimmedValue : (placeholder ?: @"")];
    if (detail.length > 0) {
        [accessibilityParts addObject:detail];
    }
    self.accessibilityLabel = [accessibilityParts componentsJoinedByString:@", "];
    self.accessibilityTraits = UIAccessibilityTraitButton;
}

@end

@interface PPAddressSwitchCell : PPAddressBaseCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UISwitch *toggleSwitch;
- (void)configureWithTitle:(NSString *)title
                  subtitle:(NSString *)subtitle
                        on:(BOOL)isOn
                    target:(id)target
                    action:(SEL)action;
@end

@implementation PPAddressSwitchCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = PPAddressCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPAddressCurrentSemanticAttribute();

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = PPAddressScaledFont([GM boldFontWithSize:PPFontHeadline] ?: [UIFont systemFontOfSize:PPFontHeadline weight:UIFontWeightSemibold], UIFontTextStyleHeadline);
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.adjustsFontForContentSizeCategory = YES;
    [self.contentView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = PPAddressScaledFont([GM MidFontWithSize:PPFontFootnote] ?: [UIFont systemFontOfSize:PPFontFootnote weight:UIFontWeightMedium], UIFontTextStyleFootnote);
    subtitleLabel.textColor = [UIColor secondaryLabelColor];
    subtitleLabel.numberOfLines = 2;
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.adjustsFontForContentSizeCategory = YES;
    [self.contentView addSubview:subtitleLabel];
    self.subtitleLabel = subtitleLabel;

    UISwitch *toggleSwitch = [[UISwitch alloc] init];
    toggleSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    toggleSwitch.onTintColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    [self.contentView addSubview:toggleSwitch];
    self.toggleSwitch = toggleSwitch;

    [NSLayoutConstraint activateConstraints:@[
        [toggleSwitch.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [toggleSwitch.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],

        [titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:18.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:toggleSwitch.leadingAnchor constant:-14.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:5.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-18.0],

        [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:(PPTouchTargetMin + PPSpaceXXL)],
    ]];

    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [self.toggleSwitch removeTarget:nil action:NULL forControlEvents:UIControlEventValueChanged];
}

- (void)configureWithTitle:(NSString *)title
                  subtitle:(NSString *)subtitle
                        on:(BOOL)isOn
                    target:(id)target
                    action:(SEL)action
{
    self.semanticContentAttribute = PPAddressCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPAddressCurrentSemanticAttribute();
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.subtitleLabel.text = subtitle ?: @"";
    self.subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.toggleSwitch.on = isOn;
    self.toggleSwitch.accessibilityLabel = title ?: @"";

    [self.toggleSwitch removeTarget:nil action:NULL forControlEvents:UIControlEventValueChanged];
    if (target && action) {
        [self.toggleSwitch addTarget:target action:action forControlEvents:UIControlEventValueChanged];
    }
}

@end

@interface PPAddressActionCell : PPAddressBaseCell
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
- (void)configureWithTitle:(NSString *)title
                  iconName:(NSString *)iconName
               destructive:(BOOL)destructive;
@end

@implementation PPAddressActionCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = PPAddressCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPAddressCurrentSemanticAttribute();

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:iconView];
    self.iconView = iconView;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = PPAddressScaledFont([GM boldFontWithSize:PPFontHeadline] ?: [UIFont systemFontOfSize:PPFontHeadline weight:UIFontWeightSemibold], UIFontTextStyleHeadline);
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.adjustsFontForContentSizeCategory = YES;
    [self.contentView addSubview:titleLabel];
    self.titleLabel = titleLabel;

    [NSLayoutConstraint activateConstraints:@[
        [iconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPSpaceBase],
        [iconView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:18.0],
        [iconView.heightAnchor constraintEqualToConstant:18.0],

        [titleLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:10.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPSpaceBase],
        [titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:16.0],
        [titleLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-16.0],

        [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin],
    ]];

    return self;
}

- (void)configureWithTitle:(NSString *)title
                  iconName:(NSString *)iconName
               destructive:(BOOL)destructive
{
    self.semanticContentAttribute = PPAddressCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPAddressCurrentSemanticAttribute();
    UIColor *tintColor = destructive ? UIColor.systemRedColor : (AppPrimaryClr ?: UIColor.systemOrangeColor);
    self.iconView.tintColor = tintColor;
    self.iconView.image = [UIImage systemImageNamed:iconName ?: @"trash"];
    self.titleLabel.text = title ?: @"";
    self.titleLabel.textColor = tintColor;
    self.accessibilityLabel = title ?: @"";
    self.accessibilityTraits = UIAccessibilityTraitButton;
}

@end

@interface PPAddressOptionsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating>
- (instancetype)initWithTitle:(NSString *)title
                      options:(NSArray *)options
               selectedOption:(nullable id)selectedOption
                titleProvider:(NSString * _Nonnull (^)(id option))titleProvider
             selectionHandler:(void (^)(id option))selectionHandler;
@end

@interface PPAddressOptionsViewController ()
@property (nonatomic, copy) NSArray *allOptions;
@property (nonatomic, copy) NSArray *filteredOptions;
@property (nonatomic, strong) id selectedOption;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, copy) NSString *(^titleProvider)(id option);
@property (nonatomic, copy) void (^selectionHandler)(id option);
@end

@implementation PPAddressOptionsViewController

- (instancetype)initWithTitle:(NSString *)title
                      options:(NSArray *)options
               selectedOption:(id)selectedOption
                titleProvider:(NSString * _Nonnull (^)(id option))titleProvider
             selectionHandler:(void (^)(id option))selectionHandler
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) {
        return nil;
    }

    self.title = title ?: @"";
    self.allOptions = options ?: @[];
    self.filteredOptions = self.allOptions;
    self.selectedOption = selectedOption;
    self.titleProvider = [titleProvider copy];
    self.selectionHandler = [selectionHandler copy];
    return self;
}
- (UIColor *)pp_canvasColor
{
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
        }
        return [UIColor colorWithRed:0.969 green:0.961 blue:0.949 alpha:1.0];
    }];
}
- (void)viewDidLoad
{
    [super viewDidLoad];
    UIColor *canvasColor = [self pp_canvasColor];

    self.view.backgroundColor = canvasColor;
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.backgroundColor = UIColor.clearColor;
    tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    if (@available(iOS 15.0, *)) {
        tableView.sectionHeaderTopPadding = 0.0;
    }
    [self.view addSubview:tableView];
    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [tableView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    self.tableView = tableView;

    UISearchController *searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    searchController.searchResultsUpdater = self;
    searchController.obscuresBackgroundDuringPresentation = NO;
    searchController.hidesNavigationBarDuringPresentation = NO;
    searchController.searchBar.placeholder = kLang(@"Search") ?: @"Search";
    self.navigationItem.searchController = searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;
    self.searchController = searchController;
}

- (NSArray *)pp_displayedOptions
{
    BOOL hasSearchText = self.searchController.isActive && self.searchController.searchBar.text.length > 0;
    return hasSearchText ? self.filteredOptions : self.allOptions;
}

- (NSString *)pp_titleForOption:(id)option
{
    if (!option) {
        return @"";
    }
    if (self.titleProvider) {
        return self.titleProvider(option) ?: @"";
    }
    return [option description];
}

- (BOOL)pp_option:(id)lhs matchesOption:(id)rhs
{
    if (lhs == rhs) {
        return YES;
    }
    if (!lhs || !rhs) {
        return NO;
    }
    if ([lhs isKindOfClass:CountryModel.class] && [rhs isKindOfClass:CountryModel.class]) {
        return ((CountryModel *)lhs).countryID == ((CountryModel *)rhs).countryID;
    }
    if ([lhs isKindOfClass:CityModel.class] && [rhs isKindOfClass:CityModel.class]) {
        return ((CityModel *)lhs).cityID == ((CityModel *)rhs).cityID;
    }
    if ([lhs isKindOfClass:StateModel.class] && [rhs isKindOfClass:StateModel.class]) {
        return ((StateModel *)lhs).stateID == ((StateModel *)rhs).stateID;
    }
    return [lhs isEqual:rhs];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
    NSString *query = [[searchController.searchBar.text ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    if (query.length == 0) {
        self.filteredOptions = self.allOptions;
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            NSString *title = [[self pp_titleForOption:evaluatedObject] lowercaseString];
            return [title containsString:query];
        }];
        self.filteredOptions = [self.allOptions filteredArrayUsingPredicate:predicate];
    }
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self pp_displayedOptions].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"PPAddressOptionsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }

    NSArray *options = [self pp_displayedOptions];
    id option = options[indexPath.row];
    cell.textLabel.text = [self pp_titleForOption:option];
    cell.textLabel.font = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    cell.textLabel.textAlignment = Language.alignmentForCurrentLanguage;
    cell.textLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    cell.backgroundColor = UIColor.clearColor;
    cell.accessoryType = [self pp_option:option matchesOption:self.selectedOption]
        ? UITableViewCellAccessoryCheckmark
        : UITableViewCellAccessoryNone;
    cell.tintColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray *options = [self pp_displayedOptions];
    if (indexPath.row >= options.count) {
        return;
    }

    id option = options[indexPath.row];
    if (self.selectionHandler) {
        self.selectionHandler(option);
    }

    if (self.navigationController) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

@end

@interface AddressFormVC () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, CLLocationManagerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIScrollView *formScrollView;
@property (nonatomic, strong) UIStackView *formStackView;
@property (nonatomic, strong) PPFormEngineView *recipientFormView;
@property (nonatomic, strong) PPFormEngineView *streetFormView;
@property (nonatomic, strong) PPFormEngineView *geographyFormView;
@property (nonatomic, strong) UISwitch *defaultSwitch;
@property (nonatomic, strong) UIButton *deleteButton;
@property (nonatomic, strong) NSArray<CountryModel *> *countriesArray;
@property (nonatomic, strong) NSArray<CityModel *> *citiesArray;
@property (nonatomic, strong) NSArray<StateModel *> *statesArray;
@property (nonatomic, strong) CountryModel *selectedCountry;
@property (nonatomic, strong) StateModel *selectedState;
@property (nonatomic, strong) CityModel *selectedCity;
@property (nonatomic, copy) NSString *selectedLocationName;
@property (nonatomic, copy) NSString *selectedLocationPoints;

@property (nonatomic, copy) NSString *draftFullName;
@property (nonatomic, copy) NSString *draftPhoneNumber;
@property (nonatomic, copy) NSString *draftPhoneDigits;
@property (nonatomic, copy) NSString *currentPhoneCode;
@property (nonatomic, strong) CountryCodeModel *autoDetectedCountry;
@property (nonatomic, copy) NSString *draftAddressLine1;
@property (nonatomic, copy) NSString *draftAddressLine2;
@property (nonatomic, copy) NSString *draftPostalCode;
@property (nonatomic, assign) BOOL draftIsDefault;

@property (nonatomic, assign) BOOL isSaving;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLGeocoder *reverseGeocoder;
@property (nonatomic, assign) CLLocationCoordinate2D currentDeviceCoordinate;
@property (nonatomic, assign) BOOL didApplyInitialLocation;
@property (nonatomic, strong) CountryModel *resolvedCountry;
@property (nonatomic, assign) BOOL didShowLocationPermissionAlert;

@property (nonatomic, strong) UIView *headerRoot;
@property (nonatomic, strong) UIView *headerCardView;
@property (nonatomic, strong) UIView *headerGradientBar;
@property (nonatomic, strong) UILabel *headerEyebrowLabel;
@property (nonatomic, strong) UILabel *headerTitleLabel;
@property (nonatomic, strong) UILabel *headerSubtitleLabel;
@property (nonatomic, strong) UILabel *headerMetaLabel;
@property (nonatomic, strong) UIView *backgroundGlowViewTop;
@property (nonatomic, strong) UIView *backgroundGlowViewBottom;

@property (nonatomic, strong) UIBarButtonItem *saveBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *leadingBarButtonItem;
@property (nonatomic, assign) NSUInteger activeSaveToken;
@end

@implementation AddressFormVC

#pragma mark - Init

- (instancetype)init
{
    return [self initWithAddress:nil];
}

- (instancetype)initWithAddress:(PPAddressModel *)address
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) {
        return nil;
    }

    _address = address;
    _addressFormPresent = AddressFormPresentPush;
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self) {
        return nil;
    }

    _addressFormPresent = AddressFormPresentPush;
    return self;
}

#pragma mark - Appearance

- (UIColor *)pp_canvasColor
{
    return AppBackgroundClr ?: UIColor.systemBackgroundColor;
}

- (UIColor *)pp_surfaceColor
{
    return AppSurfColor ?: UIColor.secondarySystemBackgroundColor;
}

- (UIColor *)pp_surfaceBorderColor
{
    return [UIColor ppSurfaceBorder] ?: [UIColor separatorColor];
}

- (void)pp_applyCanvasBackground
{
    UIColor *canvasColor = [self pp_canvasColor];
    self.view.backgroundColor = canvasColor;
    self.view.opaque = YES;
    self.navigationController.view.backgroundColor = canvasColor;
    self.formScrollView.backgroundColor = UIColor.clearColor;
}

- (NSString *)pp_localizedAddressStringForKey:(NSString *)key fallback:(NSString *)fallback
{
    NSString *value = key.length ? kLang(key) : nil;
    if (![value isKindOfClass:NSString.class] || value.length == 0 || [value isEqualToString:key]) {
        return fallback ?: @"";
    }
    return value;
}

- (void)pp_setupBackdrop
{
    if (self.backgroundGlowViewTop || self.backgroundGlowViewBottom) {
        return;
    }

    UIView *topGlow = [[UIView alloc] init];
    topGlow.translatesAutoresizingMaskIntoConstraints = NO;
    topGlow.userInteractionEnabled = NO;
    topGlow.backgroundColor = [[UIColor ppMineralBeige] colorWithAlphaComponent:0.22];
    topGlow.layer.cornerCurve = kCACornerCurveContinuous;

    UIView *bottomGlow = [[UIView alloc] init];
    bottomGlow.translatesAutoresizingMaskIntoConstraints = NO;
    bottomGlow.userInteractionEnabled = NO;
    bottomGlow.backgroundColor = [[UIColor ppSoftRose] colorWithAlphaComponent:0.14];
    bottomGlow.layer.cornerCurve = kCACornerCurveContinuous;

    [self.view insertSubview:topGlow belowSubview:self.formScrollView];
    [self.view insertSubview:bottomGlow belowSubview:self.formScrollView];

    [NSLayoutConstraint activateConstraints:@[
        [topGlow.widthAnchor constraintEqualToConstant:(PPSpace4XL * 4.0)],
        [topGlow.heightAnchor constraintEqualToConstant:(PPSpace4XL * 4.0)],
        [topGlow.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:-PPSpaceXXL],
        [topGlow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:PPSpace4XL],

        [bottomGlow.widthAnchor constraintEqualToConstant:(PPSpace4XL * 3.5)],
        [bottomGlow.heightAnchor constraintEqualToConstant:(PPSpace4XL * 3.5)],
        [bottomGlow.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:PPSpaceBase * 3.0],
        [bottomGlow.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-PPSpace4XL]
    ]];

    self.backgroundGlowViewTop = topGlow;
    self.backgroundGlowViewBottom = bottomGlow;
}

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.currentDeviceCoordinate = kCLLocationCoordinate2DInvalid;
    self.reverseGeocoder = [[CLGeocoder alloc] init];
    self.countriesArray = CitiesManager.shared.countries ?: @[];
    self.resolvedCountry = [self pp_resolvedCountryForFormLoad];

    [self pp_prepareDraftState];
    [self pp_setupHeaderView];
    [self pp_buildFormView];
    [self pp_setupBackdrop];
    [self pp_applyCanvasBackground];
    [self pp_refreshFormValuesAndStates];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_keyboardWillChangeFrame:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];

    if (!self.address) {
        [self pp_applyResolvedCountryDefaultsIfNeeded];
        [self pp_startPrefillFromCurrentLocationIfNeeded];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.formScrollView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    [self pp_configureNavigationItems];
    [self pp_applyCanvasBackground];
    [self pp_refreshFormValuesAndStates];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [PPHUD dismiss];
    [self.locationManager stopUpdatingLocation];
    [self.reverseGeocoder cancelGeocode];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)pp_keyboardWillChangeFrame:(NSNotification *)notification
{
    NSValue *frameValue = notification.userInfo[UIKeyboardFrameEndUserInfoKey];
    if (![frameValue isKindOfClass:NSValue.class]) return;

    CGRect keyboardFrame = [self.view convertRect:frameValue.CGRectValue fromView:nil];
    CGFloat overlap = CGRectGetHeight(CGRectIntersection(self.view.bounds, keyboardFrame));
    CGFloat keyboardInset = MAX(0.0, overlap - self.view.safeAreaInsets.bottom);
    UIEdgeInsets contentInset = self.formScrollView.contentInset;
    contentInset.bottom = PPSpaceXXL + keyboardInset;

    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    UIViewAnimationOptions options = (UIViewAnimationOptions)(curve << 16) | UIViewAnimationOptionBeginFromCurrentState;
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:options
                     animations:^{
        self.formScrollView.contentInset = contentInset;
        self.formScrollView.verticalScrollIndicatorInsets = contentInset;
    } completion:nil];
}

- (void)pp_keyboardWillHide:(NSNotification *)notification
{
    UIEdgeInsets contentInset = self.formScrollView.contentInset;
    contentInset.bottom = PPSpaceXXL;
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView animateWithDuration:duration animations:^{
        self.formScrollView.contentInset = contentInset;
        self.formScrollView.verticalScrollIndicatorInsets = contentInset;
    }];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    self.backgroundGlowViewTop.layer.cornerRadius = CGRectGetWidth(self.backgroundGlowViewTop.bounds) * 0.5;
    self.backgroundGlowViewBottom.layer.cornerRadius = CGRectGetWidth(self.backgroundGlowViewBottom.bounds) * 0.5;
}

- (BOOL)textField:(UITextField *)textField
shouldChangeCharactersInRange:(NSRange)range
 replacementString:(NSString *)string
{
    (void)range;
    PPFormFieldRowView *phoneRow = [self.recipientFormView rowForIdentifier:PPAddressFormFieldPhone];
    if (textField != phoneRow.textField || string.length == 0) {
        return YES;
    }

    NSCharacterSet *nonDigits = NSCharacterSet.decimalDigitCharacterSet.invertedSet;
    return [string rangeOfCharacterFromSet:nonDigits].location == NSNotFound;
}

#pragma mark - Setup

- (void)pp_buildFormView
{
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.backgroundColor = UIColor.clearColor;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    scrollView.semanticContentAttribute = PPAddressCurrentSemanticAttribute();
    scrollView.contentInset = UIEdgeInsetsMake(PPSpaceXS, 0.0, PPSpaceXXL, 0.0);
    scrollView.scrollIndicatorInsets = scrollView.contentInset;

    UIStackView *stackView = [[UIStackView alloc] init];
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.alignment = UIStackViewAlignmentFill;
    stackView.distribution = UIStackViewDistributionFill;
    stackView.spacing = PPSpaceLG;
    stackView.layoutMarginsRelativeArrangement = YES;
    stackView.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(PPSpaceSM,
                                                                      PPSpaceBase,
                                                                      PPSpaceXXL,
                                                                      PPSpaceBase);
    stackView.semanticContentAttribute = PPAddressCurrentSemanticAttribute();
    [scrollView addSubview:stackView];

    [self.view addSubview:scrollView];
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],

        [stackView.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
        [stackView.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
        [stackView.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
        [stackView.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor],
        [stackView.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor]
    ]];

    self.formScrollView = scrollView;
    self.formStackView = stackView;

    [stackView addArrangedSubview:self.headerRoot];

    [stackView addArrangedSubview:[self pp_sectionHeaderViewWithTitle:
                                   [self pp_localizedAddressStringForKey:@"Recipient" fallback:@"Recipient"]
                                                               subtitle:
                                   [self pp_localizedAddressStringForKey:@"RecipientSubtitle" fallback:@"Who receives the order and which number should delivery call?"]
                                                             tintColor:AppPrimaryClr ?: UIColor.systemOrangeColor]];
    self.recipientFormView = [[PPFormEngineView alloc] initWithStyle:[self pp_addressFormStyle]];
    [stackView addArrangedSubview:self.recipientFormView];

    [stackView addArrangedSubview:[self pp_sectionHeaderViewWithTitle:
                                   [self pp_localizedAddressStringForKey:@"StreetDetails" fallback:@"Street details"]
                                                               subtitle:
                                   [self pp_localizedAddressStringForKey:@"StreetDetailsSubtitle" fallback:@"Add the lines couriers need to find the exact door."]
                                                             tintColor:AppPrimaryClr ?: UIColor.systemOrangeColor]];
    self.streetFormView = [[PPFormEngineView alloc] initWithStyle:[self pp_addressFormStyle]];
    [stackView addArrangedSubview:self.streetFormView];

    [stackView addArrangedSubview:[self pp_sectionHeaderViewWithTitle:
                                   [self pp_localizedAddressStringForKey:@"AreaAndMap" fallback:@"Area and map"]
                                                               subtitle:
                                   [self pp_localizedAddressStringForKey:@"AreaAndMapSubtitle" fallback:@"Country, city, area, and the map pin should all point to the same place."]
                                                             tintColor:AppPrimaryClr ?: UIColor.systemOrangeColor]];
    self.geographyFormView = [[PPFormEngineView alloc] initWithStyle:[self pp_addressFormStyle]];
    [stackView addArrangedSubview:self.geographyFormView];

    [stackView addArrangedSubview:[self pp_preferenceView]];
    if (self.address) {
        [stackView addArrangedSubview:[self pp_deleteAddressView]];
    }

    [self pp_buildAddressFormFields];
}

- (void)pp_setupHeaderView
{
    UIView *headerRoot = [[UIView alloc] init];
    headerRoot.translatesAutoresizingMaskIntoConstraints = NO;
    headerRoot.backgroundColor = UIColor.clearColor;

    UIView *cardView = [[UIView alloc] init];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    cardView.backgroundColor = [self pp_surfaceColor];
    PPApplyContinuousCorners(cardView, PPCornerHero);
    cardView.layer.borderWidth = 1.0;
    [cardView pp_setBorderColor:[self pp_surfaceBorderColor]];
    PPApplyCardShadow(cardView);
    [headerRoot addSubview:cardView];

    UIColor *brandClr = AppPrimaryClr ?: UIColor.systemOrangeColor;

    UIView *accentBar = [[UIView alloc] init];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = brandClr;
    PPApplyContinuousCorners(accentBar, PPCornerPill);
    accentBar.accessibilityElementsHidden = YES;
    [cardView addSubview:accentBar];

    UIView *iconBadge = [[UIView alloc] init];
    iconBadge.translatesAutoresizingMaskIntoConstraints = NO;
    iconBadge.backgroundColor = [brandClr colorWithAlphaComponent:0.10];
    PPApplyContinuousCorners(iconBadge, PPCornerCard);
    iconBadge.layer.masksToBounds = YES;
    iconBadge.layer.borderWidth = 1.0;
    [iconBadge pp_setBorderColor:[brandClr colorWithAlphaComponent:0.16]];
    [cardView addSubview:iconBadge];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"mappin.and.ellipse"]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = brandClr;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.accessibilityElementsHidden = YES;
    [iconBadge addSubview:iconView];

    UILabel *eyebrowLabel = [[UILabel alloc] init];
    eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowLabel.font = PPAddressScaledFont([GM boldFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:PPFontCaption1 weight:UIFontWeightSemibold], UIFontTextStyleCaption1);
    eyebrowLabel.textColor = brandClr;
    eyebrowLabel.textAlignment = Language.alignmentForCurrentLanguage;
    eyebrowLabel.adjustsFontForContentSizeCategory = YES;
    [cardView addSubview:eyebrowLabel];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = PPAddressScaledFont([GM boldFontWithSize:PPFontTitle1] ?: [UIFont systemFontOfSize:PPFontTitle1 weight:UIFontWeightBold], UIFontTextStyleTitle1);
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.numberOfLines = 2;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.adjustsFontForContentSizeCategory = YES;
    [cardView addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = PPAddressScaledFont([GM MidFontWithSize:PPFontCallout] ?: [UIFont systemFontOfSize:PPFontCallout weight:UIFontWeightMedium], UIFontTextStyleCallout);
    subtitleLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.adjustsFontForContentSizeCategory = YES;
    [cardView addSubview:subtitleLabel];

    PPInsetLabel *metaLabel = [[PPInsetLabel alloc] init];
    metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    metaLabel.font = PPAddressScaledFont([GM MidFontWithSize:PPFontFootnote] ?: [UIFont systemFontOfSize:PPFontFootnote weight:UIFontWeightSemibold], UIFontTextStyleFootnote);
    metaLabel.textColor = brandClr;
    metaLabel.numberOfLines = 2;
    metaLabel.textAlignment = Language.alignmentForCurrentLanguage;
    metaLabel.adjustsFontForContentSizeCategory = YES;
    metaLabel.backgroundColor = [[UIColor ppSoftRose] colorWithAlphaComponent:0.16];
    PPApplyContinuousCorners(metaLabel, PPCornerSmall);
    metaLabel.layer.masksToBounds = YES;
    metaLabel.layer.borderWidth = 1.0;
    [metaLabel pp_setBorderColor:[brandClr colorWithAlphaComponent:0.14]];
    metaLabel.textInsets = UIEdgeInsetsMake(PPSpaceXS, PPSpaceSM, PPSpaceXS, PPSpaceSM);

    [cardView addSubview:metaLabel];

    [NSLayoutConstraint activateConstraints:@[
        [cardView.topAnchor constraintEqualToAnchor:headerRoot.topAnchor constant:PPSpaceSM],
        [cardView.leadingAnchor constraintEqualToAnchor:headerRoot.leadingAnchor],
        [cardView.trailingAnchor constraintEqualToAnchor:headerRoot.trailingAnchor],
        [cardView.bottomAnchor constraintEqualToAnchor:headerRoot.bottomAnchor constant:-PPSpaceMD],

        [accentBar.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:PPSpaceXL],
        [accentBar.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:PPSpaceXL],
        [accentBar.widthAnchor constraintEqualToConstant:(PPSpaceXL + PPSpaceSM)],
        [accentBar.heightAnchor constraintEqualToConstant:PPSpaceXS],

        [iconBadge.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:PPSpaceLG],
        [iconBadge.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-PPSpaceXL],
        [iconBadge.widthAnchor constraintEqualToConstant:(PPSpaceXL * 2.0)],
        [iconBadge.heightAnchor constraintEqualToConstant:(PPSpaceXL * 2.0)],

        [iconView.centerXAnchor constraintEqualToAnchor:iconBadge.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconBadge.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:PPSpaceXL],
        [iconView.heightAnchor constraintEqualToConstant:PPSpaceXL],

        [eyebrowLabel.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:PPSpaceMD],
        [eyebrowLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:PPSpaceXL],
        [eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:iconBadge.leadingAnchor constant:-PPSpaceMD],

        [titleLabel.topAnchor constraintEqualToAnchor:eyebrowLabel.bottomAnchor constant:PPSpaceSM],
        [titleLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:PPSpaceXL],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:iconBadge.leadingAnchor constant:-PPSpaceMD],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:PPSpaceSM],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

        [metaLabel.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:PPSpaceMD],
        [metaLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [metaLabel.trailingAnchor constraintLessThanOrEqualToAnchor:titleLabel.trailingAnchor],
        [metaLabel.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-PPSpaceXL],
        [metaLabel.heightAnchor constraintGreaterThanOrEqualToConstant:(PPSpaceXL + PPSpaceSM)]
    ]];

    self.headerRoot = headerRoot;
    self.headerCardView = cardView;
    self.headerGradientBar = accentBar;
    self.headerEyebrowLabel = eyebrowLabel;
    self.headerTitleLabel = titleLabel;
    self.headerSubtitleLabel = subtitleLabel;
    self.headerMetaLabel = metaLabel;

    CGSize fittingSize = [headerRoot systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    headerRoot.frame = CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.bounds), fittingSize.height);
}

- (PPFormStyle *)pp_addressFormStyle
{
    PPFormStyle *style = [PPFormStyle defaultStyle];
    UIColor *brandColor = AppPrimaryClr ?: UIColor.systemOrangeColor;

    style.cardBackgroundColor = [self pp_surfaceColor];
    style.fieldBackgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:0.08 alpha:1.0];
        }
        return [UIColor colorWithWhite:1.0 alpha:0.54];
    }];
    style.accentColor = brandColor;
    style.primaryTextColor = AppPrimaryTextClr ?: UIColor.labelColor;
    style.secondaryTextColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    style.errorColor = UIColor.systemRedColor;
    style.cardBorderColor = [self pp_surfaceBorderColor];
    style.fieldBorderColor = [brandColor colorWithAlphaComponent:0.13];
    style.shadowColor = UIColor.blackColor;

    style.titleFont = PPAddressScaledFont([GM boldFontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:PPFontSubheadline weight:UIFontWeightSemibold], UIFontTextStyleSubheadline);
    style.inputFont = PPAddressScaledFont([GM MidFontWithSize:PPFontBody] ?: [UIFont systemFontOfSize:PPFontBody weight:UIFontWeightMedium], UIFontTextStyleBody);
    style.placeholderFont = PPAddressScaledFont([GM MidFontWithSize:PPFontCallout] ?: [UIFont systemFontOfSize:PPFontCallout weight:UIFontWeightMedium], UIFontTextStyleCallout);
    style.errorFont = PPAddressScaledFont([GM MidFontWithSize:PPFontFootnote] ?: [UIFont systemFontOfSize:PPFontFootnote weight:UIFontWeightMedium], UIFontTextStyleFootnote);

    style.stackSpacing = PPSpaceSM;
    style.cardCornerRadius = PPCornerCard;
    style.fieldCornerRadius = PPCornerMedium;
    style.cardBorderWidth = 1.0 / UIScreen.mainScreen.scale;
    style.fieldBorderWidth = 1.0 / UIScreen.mainScreen.scale;
    style.shadowOpacity = 0.02;
    style.shadowRadius = PPSpaceXL;
    style.shadowOffset = CGSizeMake(0.0, PPSpaceSM);
    style.accentLeading = PPSpaceMD;
    style.accentTop = PPSpaceLG;
    style.accentWidth = PPSpaceXS;
    style.accentHeight = PPSpaceXL;
    style.titleLeadingFromAccent = PPSpaceSM;
    style.titleTrailing = PPSpaceMD;
    style.titleToFieldSpacing = PPSpaceSM;
    style.fieldLeading = PPSpaceMD;
    style.fieldTrailing = PPSpaceMD;
    style.fieldTopInset = PPSpaceMD;
    style.fieldHorizontalInset = PPSpaceMD;
    style.fieldBottomInset = PPSpaceMD;
    style.rowBottomInset = PPSpaceMD;
    style.minimumSingleLineFieldHeight = PPTouchTargetMin;
    style.minimumTextViewFieldHeight = 120.0;
    return style;
}

- (void)pp_buildAddressFormFields
{
    __weak typeof(self) weakSelf = self;

    PPFormFieldConfig *fullName = [PPFormFieldConfig fieldWithIdentifier:PPAddressFormFieldFullName
                                                                     title:kLang(@"FullName") ?: @"Full name"
                                                               placeholder:kLang(@"FullNamePlaceholder") ?: @"Enter your full name"
                                                                 inputType:PPFormInputTypeText];
    fullName.required = YES;
    fullName.textChangeBlock = ^(PPFormFieldConfig *config, NSString *value) {
        (void)config;
        weakSelf.draftFullName = value ?: @"";
    };

    PPFormFieldConfig *phoneCode = [PPFormFieldConfig fieldWithIdentifier:PPAddressFormFieldPhoneCode
                                                                      title:kLang(@"PhoneCountryCode") ?: @"Phone country code"
                                                                placeholder:kLang(@"TapToSelect") ?: @"Tap to select"
                                                                  inputType:PPFormInputTypePicker];
    phoneCode.required = YES;
    phoneCode.pickerTapBlock = ^(PPFormFieldConfig *config, PPFormFieldRowView *row) {
        (void)config;
        (void)row;
        [weakSelf pp_presentPhoneCodeOptions];
    };

    PPFormFieldConfig *phone = [PPFormFieldConfig fieldWithIdentifier:PPAddressFormFieldPhone
                                                                  title:kLang(@"MobileNo_Palce") ?: @"Phone number"
                                                            placeholder:kLang(@"MobileNo_Palce") ?: @"Add a reachable phone number"
                                                              inputType:PPFormInputTypePhone];
    phone.required = YES;
    phone.textChangeBlock = ^(PPFormFieldConfig *config, NSString *value) {
        (void)config;
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        NSString *digits = [self pp_digitsOnlyValue:value];
        self.draftPhoneDigits = digits;
        self.draftPhoneNumber = [NSString stringWithFormat:@"%@%@", self.currentPhoneCode ?: @"+974", digits];
    };

    PPFormFieldConfig *addressLine1 = [PPFormFieldConfig fieldWithIdentifier:PPAddressFormFieldAddressLine1
                                                                         title:kLang(@"AddressLine1") ?: @"Address line 1"
                                                                   placeholder:kLang(@"AddressLine1Placeholder") ?: @"Street address, building, apartment"
                                                                     inputType:PPFormInputTypeText];
    addressLine1.required = YES;
    addressLine1.textChangeBlock = ^(PPFormFieldConfig *config, NSString *value) {
        (void)config;
        weakSelf.draftAddressLine1 = value ?: @"";
    };

    PPFormFieldConfig *addressLine2 = [PPFormFieldConfig fieldWithIdentifier:PPAddressFormFieldAddressLine2
                                                                         title:kLang(@"AddressLine2Optional") ?: @"Address line 2 (optional)"
                                                                   placeholder:kLang(@"AddressLine2Placeholder") ?: @"Apartment, suite, unit, floor (optional)"
                                                                     inputType:PPFormInputTypeText];
    addressLine2.textChangeBlock = ^(PPFormFieldConfig *config, NSString *value) {
        (void)config;
        weakSelf.draftAddressLine2 = value ?: @"";
    };

    PPFormFieldConfig *postalCode = [PPFormFieldConfig fieldWithIdentifier:PPAddressFormFieldPostalCode
                                                                       title:kLang(@"PostalCode") ?: @"Postal code"
                                                                 placeholder:kLang(@"PostalCodePlaceholder") ?: @"Postal or ZIP code"
                                                                   inputType:PPFormInputTypeText];
    postalCode.required = YES;
    postalCode.keyboardType = UIKeyboardTypeASCIICapable;
    postalCode.textChangeBlock = ^(PPFormFieldConfig *config, NSString *value) {
        (void)config;
        weakSelf.draftPostalCode = value ?: @"";
    };

    PPFormFieldConfig *country = [PPFormFieldConfig fieldWithIdentifier:PPAddressFormFieldCountry
                                                                    title:kLang(@"Country") ?: @"Country"
                                                              placeholder:kLang(@"TapToSelect") ?: @"Tap to select"
                                                                inputType:PPFormInputTypePicker];
    country.required = YES;
    country.pickerTapBlock = ^(PPFormFieldConfig *config, PPFormFieldRowView *row) {
        (void)config;
        (void)row;
        [weakSelf pp_presentCountryOptions];
    };

    PPFormFieldConfig *city = [PPFormFieldConfig fieldWithIdentifier:PPAddressFormFieldCity
                                                                 title:kLang(@"City") ?: @"City"
                                                           placeholder:kLang(@"TapToSelect") ?: @"Tap to select"
                                                             inputType:PPFormInputTypePicker];
    city.required = YES;
    city.pickerTapBlock = ^(PPFormFieldConfig *config, PPFormFieldRowView *row) {
        (void)config;
        (void)row;
        [weakSelf pp_presentCityOptions];
    };

    PPFormFieldConfig *state = [PPFormFieldConfig fieldWithIdentifier:PPAddressFormFieldState
                                                                  title:kLang(@"State") ?: @"Area"
                                                            placeholder:kLang(@"TapToSelect") ?: @"Tap to select"
                                                              inputType:PPFormInputTypePicker];
    state.required = YES;
    state.pickerTapBlock = ^(PPFormFieldConfig *config, PPFormFieldRowView *row) {
        (void)config;
        (void)row;
        [weakSelf pp_presentStateOptions];
    };

    PPFormFieldConfig *location = [PPFormFieldConfig fieldWithIdentifier:PPAddressFormFieldLocation
                                                                     title:kLang(@"MapLocation") ?: @"Map location"
                                                               placeholder:kLang(@"TapToSelect") ?: @"Tap to select"
                                                                 inputType:PPFormInputTypePicker];
    location.pickerTapBlock = ^(PPFormFieldConfig *config, PPFormFieldRowView *row) {
        (void)config;
        (void)row;
        [weakSelf pp_openLocationPicker];
    };

    [self.recipientFormView setFields:@[fullName, phoneCode, phone]];
    [self.streetFormView setFields:@[addressLine1, addressLine2, postalCode]];
    [self.geographyFormView setFields:@[country, city, state, location]];

    [self pp_configureAddressFormRows];
    [self pp_refreshFormValuesAndStates];
}

- (void)pp_configureAddressFormRows
{
    NSDictionary<NSString *, PPFormEngineView *> *forms = @{
        @"recipient": self.recipientFormView,
        @"street": self.streetFormView,
        @"geography": self.geographyFormView
    };

    for (PPFormEngineView *form in forms.allValues) {
        for (PPFormFieldConfig *config in form.fields) {
            PPFormFieldRowView *row = [form rowForIdentifier:config.identifier];
            if (!row) {
                continue;
            }

            row.titleLabel.adjustsFontForContentSizeCategory = YES;
            // PPFormStyle stores the Dynamic Type-scaled font. Re-scaling it
            // through UIFontMetrics raises NSInvalidArgumentException.
            row.titleLabel.font = form.style.titleFont;
            row.accessibilityLabel = config.title;
            row.accessibilityHint = config.placeholder;

            if (row.textField) {
                row.externalTextFieldDelegate = self;
                row.textField.adjustsFontForContentSizeCategory = YES;
                row.textField.accessibilityLabel = config.title;
                row.textField.accessibilityHint = config.placeholder;
                row.textField.returnKeyType = UIReturnKeyNext;
                row.textField.autocorrectionType = UITextAutocorrectionTypeNo;
                row.textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
            }

            if (row.pickerButton) {
                row.pickerButton.accessibilityLabel = config.title;
                row.pickerButton.accessibilityHint = config.placeholder;
                row.pickerButton.accessibilityTraits = UIAccessibilityTraitButton;
            }
        }
    }

    PPFormFieldRowView *fullNameRow = [self.recipientFormView rowForIdentifier:PPAddressFormFieldFullName];
    fullNameRow.textField.textContentType = UITextContentTypeName;
    fullNameRow.textField.returnKeyType = UIReturnKeyNext;
    fullNameRow.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;

    PPFormFieldRowView *phoneRow = [self.recipientFormView rowForIdentifier:PPAddressFormFieldPhone];
    phoneRow.textField.textContentType = UITextContentTypeTelephoneNumber;
    phoneRow.textField.keyboardType = UIKeyboardTypeASCIICapableNumberPad;
    phoneRow.textField.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    phoneRow.textField.textAlignment = NSTextAlignmentLeft;

    PPFormFieldRowView *addressLine1Row = [self.streetFormView rowForIdentifier:PPAddressFormFieldAddressLine1];
    addressLine1Row.textField.textContentType = UITextContentTypeFullStreetAddress;
    addressLine1Row.textField.returnKeyType = UIReturnKeyNext;
    addressLine1Row.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;

    PPFormFieldRowView *addressLine2Row = [self.streetFormView rowForIdentifier:PPAddressFormFieldAddressLine2];
    addressLine2Row.textField.textContentType = UITextContentTypeFullStreetAddress;
    addressLine2Row.textField.returnKeyType = UIReturnKeyNext;
    addressLine2Row.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;

    PPFormFieldRowView *postalCodeRow = [self.streetFormView rowForIdentifier:PPAddressFormFieldPostalCode];
    postalCodeRow.textField.textContentType = UITextContentTypePostalCode;
    postalCodeRow.textField.returnKeyType = UIReturnKeyDone;
    postalCodeRow.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
}

- (UIView *)pp_preferenceView
{
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [self pp_surfaceColor];
    PPApplyContinuousCorners(card, PPCornerCard);
    card.layer.borderWidth = 1.0;
    [card pp_setBorderColor:[self pp_surfaceBorderColor]];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = PPAddressScaledFont([GM boldFontWithSize:PPFontHeadline] ?: [UIFont systemFontOfSize:PPFontHeadline weight:UIFontWeightSemibold], UIFontTextStyleHeadline);
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.text = kLang(@"DefaultShippingAddress") ?: @"Default shipping address";
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.adjustsFontForContentSizeCategory = YES;
    [card addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = PPAddressScaledFont([GM MidFontWithSize:PPFontFootnote] ?: [UIFont systemFontOfSize:PPFontFootnote weight:UIFontWeightMedium], UIFontTextStyleFootnote);
    subtitleLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    subtitleLabel.text = kLang(@"DefaultShippingAddressSubtitle") ?: @"Use this address automatically when checkout opens.";
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.adjustsFontForContentSizeCategory = YES;
    [card addSubview:subtitleLabel];

    UISwitch *defaultSwitch = [[UISwitch alloc] init];
    defaultSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    defaultSwitch.onTintColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    defaultSwitch.accessibilityLabel = kLang(@"DefaultShippingAddress") ?: @"Default shipping address";
    defaultSwitch.accessibilityHint = kLang(@"DefaultShippingAddressSubtitle") ?: @"Use this address automatically when checkout opens.";
    [defaultSwitch addTarget:self action:@selector(pp_defaultSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [card addSubview:defaultSwitch];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:PPSpaceLG],
        [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:PPSpaceLG],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:defaultSwitch.leadingAnchor constant:-PPSpaceMD],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:PPSpaceXS],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:defaultSwitch.leadingAnchor constant:-PPSpaceMD],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-PPSpaceLG],

        [defaultSwitch.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [defaultSwitch.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-PPSpaceLG]
    ]];

    self.defaultSwitch = defaultSwitch;
    return card;
}

- (UIView *)pp_deleteAddressView
{
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;

    UIButtonConfiguration *configuration = [UIButtonConfiguration tintedButtonConfiguration];
    configuration.title = kLang(@"DeleteAddress") ?: @"Delete address";
    configuration.image = [UIImage systemImageNamed:@"trash"];
    configuration.imagePadding = PPSpaceSM;
    configuration.baseForegroundColor = UIColor.systemRedColor;
    configuration.baseBackgroundColor = [UIColor.systemRedColor colorWithAlphaComponent:0.10];
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(PPSpaceMD, PPSpaceLG, PPSpaceMD, PPSpaceLG);
    UIButton *deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    deleteButton.translatesAutoresizingMaskIntoConstraints = NO;
    deleteButton.configuration = configuration;
    deleteButton.accessibilityLabel = kLang(@"DeleteAddress") ?: @"Delete address";
    deleteButton.accessibilityHint = kLang(@"DangerZoneSubtitle") ?: @"Remove this saved address permanently.";
    deleteButton.accessibilityTraits = UIAccessibilityTraitButton;
    [deleteButton addTarget:self action:@selector(showDeleteConfirmation) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:deleteButton];

    [NSLayoutConstraint activateConstraints:@[
        [deleteButton.topAnchor constraintEqualToAnchor:container.topAnchor],
        [deleteButton.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [deleteButton.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [deleteButton.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [deleteButton.heightAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin]
    ]];

    self.deleteButton = deleteButton;
    return container;
}

- (void)pp_prepareDraftState
{
    NSString *preferredName = self.address.fullName.length > 0
        ? self.address.fullName
        : (PPCurrentUser.UserName.length > 0 ? PPCurrentUser.UserName : ([FIRAuth auth].currentUser.displayName ?: @""));
    NSString *preferredPhone = self.address.phoneNumber.length > 0
        ? self.address.phoneNumber
        : (PPCurrentUser.MobileNo.length > 0 ? PPCurrentUser.MobileNo : ([FIRAuth auth].currentUser.phoneNumber ?: @""));

    self.draftFullName = [self pp_trimmedString:preferredName];
    self.draftPhoneNumber = [self pp_trimmedString:preferredPhone];
    [self pp_parsePhoneNumber:self.draftPhoneNumber];
    self.draftAddressLine1 = [self pp_trimmedString:self.address.addressLine1];
    self.draftAddressLine2 = [self pp_trimmedString:self.address.addressLine2];
    self.draftPostalCode = [self pp_trimmedString:self.address.postalCode];
    self.draftIsDefault = self.address ? self.address.isDefault : (!self.address && PPCurrentUser.Addresses.count == 0);
    self.selectedLocationName = [self pp_trimmedString:self.address.locatioName];
    self.selectedLocationPoints = [self pp_trimmedString:self.address.locationPoints];

    if (self.address) {
        self.selectedCity = [CitiesManager.shared cityByID:self.address.cityID];
        self.selectedState = [CitiesManager.shared stateByID:self.address.stateID];
        self.selectedCountry = self.selectedCity.country ?: self.resolvedCountry ?: [self pp_qatarCountry];
        [self pp_applyCountry:self.selectedCountry preferredCity:self.selectedCity preferredState:self.selectedState];
    } else {
        self.selectedCountry = self.resolvedCountry ?: [self pp_qatarCountry];
        self.citiesArray = [self pp_citiesForCountryOrQatar:self.selectedCountry];
        self.statesArray = @[];
    }
}
 
- (void)pp_configureNavigationItems
{
    NSString *screenTitle = self.address ? (kLang(@"EditAddress") ?: @"Edit address") : (kLang(@"AddAddress") ?: @"Add address");
    self.navigationItem.title = screenTitle;

    NSDictionary *titleAttrs = @{ NSForegroundColorAttributeName: (AppPrimaryTextClr ?: UIColor.labelColor) };
    self.navigationController.navigationBar.titleTextAttributes = titleAttrs;

    NSString *leadingImageName = self.addressFormPresent == AddressFormPresentSheet
        ? @"xmark"
        : (PPChevronName ?: @"chevron.backward");
    self.leadingBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:leadingImageName]
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(pp_handleLeadingAction)];
    self.leadingBarButtonItem.accessibilityLabel = self.addressFormPresent == AddressFormPresentSheet
        ? (kLang(@"Cancel") ?: @"Cancel")
        : (kLang(@"Back") ?: @"Back");
    
    UIButton *sav = [PPButtonHelper pp_buttonWithTitle:kLang(@"Save") font:[GM fontWithSize:17] imageName:@"" target:self config:[UIButtonConfiguration tintedButtonConfiguration] action:@selector(saveButtonPressed:)];
    sav.accessibilityLabel = kLang(@"Save") ?: @"Save";
    sav.accessibilityHint = kLang(@"SaveAddressHint") ?: @"Saves this address for delivery and checkout.";
    self.saveBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:sav];

    self.navigationItem.leftBarButtonItem = self.leadingBarButtonItem;
    self.navigationItem.rightBarButtonItem = self.saveBarButtonItem;
    [self pp_setSavingState:self.isSaving];
}

- (void)pp_handleLeadingAction
{
    if (self.addressFormPresent == AddressFormPresentSheet) {
        if (self.navigationController.presentingViewController) {
            [self.navigationController dismissViewControllerAnimated:YES completion:nil];
        } else {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
        return;
    }

    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (NSString *)pp_formTitleText
{
    return self.address
        ? [self pp_localizedAddressStringForKey:@"EditAddress" fallback:@"Edit address"]
        : [self pp_localizedAddressStringForKey:@"AddAddress" fallback:@"Add address"];
}

- (NSString *)pp_formSubtitleText
{
    if (self.address) {
        return [self pp_localizedAddressStringForKey:@"AddressFormEditSubtitle"
                                            fallback:@"Update your delivery details, map pin, and checkout preferences."];
    }
    return [self pp_localizedAddressStringForKey:@"AddressFormAddSubtitle"
                                        fallback:@"Create a delivery address with the right country, city, area, and map pin."];
}

- (NSString *)pp_headerMetaText
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSString *cityName = [self pp_localizedCityName:self.selectedCity];
    NSString *countryName = [self pp_localizedCountryName:self.selectedCountry];
    if (cityName.length > 0) {
        [parts addObject:cityName];
    }
    if (countryName.length > 0) {
        [parts addObject:countryName];
    }
    if (parts.count > 0) {
        return [parts componentsJoinedByString:@"  •  "];
    }
    if (self.selectedLocationName.length > 0) {
        return self.selectedLocationName;
    }
    return [self pp_localizedAddressStringForKey:@"AddressHeroMetaFallback" fallback:@"Delivery details ready"];
}

- (void)pp_refreshHeaderContent
{
    self.headerEyebrowLabel.text = [self pp_localizedAddressStringForKey:@"AddressHeroEyebrow" fallback:@"Delivery destination"];
    self.headerTitleLabel.text = [self pp_formTitleText];
    self.headerSubtitleLabel.text = [self pp_formSubtitleText];

    NSString *metaText = [self pp_headerMetaText];
    self.headerMetaLabel.text = metaText.length > 0 ? [NSString stringWithFormat:@"  %@  ", metaText] : @"";
}

#pragma mark - Data Helpers

- (NSString *)pp_trimmedString:(id)value
{
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)pp_digitsOnlyValue:(NSString *)value
{
    NSCharacterSet *digits = [NSCharacterSet decimalDigitCharacterSet];
    NSMutableString *result = [NSMutableString string];
    NSString *safeValue = value ?: @"";
    for (NSUInteger index = 0; index < safeValue.length; index++) {
        unichar character = [safeValue characterAtIndex:index];
        if ([digits characterIsMember:character]) {
            [result appendFormat:@"%C", character];
        }
    }
    return result.copy;
}

- (NSString *)pp_phoneCodeDisplayText
{
    NSString *code = self.currentPhoneCode.length > 0 ? self.currentPhoneCode : @"+974";
    NSString *flag = self.autoDetectedCountry.flag ?: @"";
    return flag.length > 0 ? [NSString stringWithFormat:@"%@ %@", flag, code] : code;
}

- (void)pp_refreshFormValuesAndStates
{
    [self pp_refreshHeaderContent];

    if (!self.recipientFormView || !self.streetFormView || !self.geographyFormView) {
        return;
    }

    [self.recipientFormView setValue:self.draftFullName ?: @"" forIdentifier:PPAddressFormFieldFullName];
    [self.recipientFormView setValue:[self pp_phoneCodeDisplayText] forIdentifier:PPAddressFormFieldPhoneCode];
    [self.recipientFormView setValue:self.draftPhoneDigits ?: @"" forIdentifier:PPAddressFormFieldPhone];

    [self.streetFormView setValue:self.draftAddressLine1 ?: @"" forIdentifier:PPAddressFormFieldAddressLine1];
    [self.streetFormView setValue:self.draftAddressLine2 ?: @"" forIdentifier:PPAddressFormFieldAddressLine2];
    [self.streetFormView setValue:self.draftPostalCode ?: @"" forIdentifier:PPAddressFormFieldPostalCode];

    [self.geographyFormView setValue:[self pp_localizedCountryName:self.selectedCountry] forIdentifier:PPAddressFormFieldCountry];
    [self.geographyFormView setValue:[self pp_localizedCityName:self.selectedCity] forIdentifier:PPAddressFormFieldCity];
    [self.geographyFormView setValue:[self pp_localizedStateName:self.selectedState] forIdentifier:PPAddressFormFieldState];
    [self.geographyFormView setValue:self.selectedLocationName ?: @"" forIdentifier:PPAddressFormFieldLocation];

    [self.geographyFormView setFieldEnabled:(self.selectedCountry != nil) identifier:PPAddressFormFieldCity];
    [self.geographyFormView setFieldEnabled:(self.selectedCity != nil) identifier:PPAddressFormFieldState];
    [self.defaultSwitch setOn:self.draftIsDefault animated:NO];
}

- (CountryModel *)pp_qatarCountry
{
    return [CitiesManager.shared qatarCountry];
}

- (NSArray<CountryModel *> *)pp_availableCountries
{
    NSArray<CountryModel *> *countries = self.countriesArray ?: CitiesManager.shared.countries;
    if (countries.count > 0) {
        return countries;
    }
    CountryModel *fallback = [self pp_qatarCountry];
    return fallback ? @[fallback] : @[];
}

- (NSString *)pp_localizedCountryName:(CountryModel *)country
{
    if (![country isKindOfClass:CountryModel.class]) {
        return @"";
    }
    if (Language.isRTL && country.arName.length > 0) {
        return country.arName;
    }
    if (country.enName.length > 0) {
        return country.enName;
    }
    return country.name ?: @"";
}

- (NSString *)pp_localizedCityName:(CityModel *)city
{
    if (![city isKindOfClass:CityModel.class]) {
        return @"";
    }
    if (Language.isRTL && city.arName.length > 0) {
        return city.arName;
    }
    if (city.enName.length > 0) {
        return city.enName;
    }
    return city.name ?: @"";
}

- (NSString *)pp_localizedStateName:(StateModel *)state
{
    if (![state isKindOfClass:StateModel.class]) {
        return @"";
    }
    if (Language.isRTL && state.arName.length > 0) {
        return state.arName;
    }
    return state.enName ?: @"";
}

- (NSArray<CityModel *> *)pp_citiesForCountryOrQatar:(CountryModel *)country
{
    NSArray<CityModel *> *cities = country.cities ?: @[];
    if (cities.count > 0) {
        return cities;
    }
    return [self pp_qatarCountry].cities ?: @[];
}

- (CountryModel *)pp_countryFromUserCountryID:(NSInteger)countryID
{
    if (countryID <= 0) {
        return nil;
    }

    NSArray<CountryCodeModel *> *countries = [GM getMiddleEastCountriesForLanguage:[Language currentLanguageCode]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.ID == %ld", countryID];
    CountryCodeModel *matchedCountry = [[countries filteredArrayUsingPredicate:predicate] firstObject];
    if (matchedCountry.isoCountryCode.length == 0) {
        return nil;
    }
    return [CitiesManager.shared countryWithCode:matchedCountry.isoCountryCode];
}

- (CountryModel *)pp_countryFromPhoneNumber:(NSString *)phoneNumber
{
    NSString *trimmedPhone = [self pp_trimmedString:phoneNumber];
    if (trimmedPhone.length == 0 || ![trimmedPhone hasPrefix:@"+"]) {
        return nil;
    }

    CountryModel *best = nil;
    NSUInteger bestLength = 0;
    for (CountryModel *country in CitiesManager.shared.countries ?: @[]) {
        NSString *dialCode = [self pp_trimmedString:country.countryCode];
        if (dialCode.length == 0) {
            continue;
        }
        if (![dialCode hasPrefix:@"+"]) {
            dialCode = [@"+" stringByAppendingString:dialCode];
        }
        if ([trimmedPhone hasPrefix:dialCode] && dialCode.length > bestLength) {
            best = country;
            bestLength = dialCode.length;
        }
    }
    return best;
}

- (CountryModel *)pp_resolvedCountryForFormLoad
{
    if (self.address.cityID > 0) {
        CityModel *addressCity = [CitiesManager.shared cityByID:self.address.cityID];
        if (addressCity.country) {
            return addressCity.country;
        }
    }

    CountryModel *country = [self pp_countryFromUserCountryID:PPCurrentUser.CountryID];
    if (!country) {
        country = [self pp_countryFromPhoneNumber:PPCurrentUser.MobileNo];
    }
    if (!country) {
        country = [self pp_countryFromPhoneNumber:[FIRAuth auth].currentUser.phoneNumber];
    }
    if (!country) {
        country = [CitiesManager.shared countryWithCode:[GM getCurrentCountryFromCarrier]];
    }
    if (!country) {
        country = [CitiesManager.shared countryWithCode:[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode]];
    }
    if (!country) {
        country = CitiesManager.shared.CurrentCountry;
    }
    return country ?: [self pp_qatarCountry];
}

- (void)pp_applyResolvedCountryDefaultsIfNeeded
{
    CountryModel *country = self.resolvedCountry ?: [self pp_qatarCountry];
    [self pp_applyCountry:country preferredCity:self.selectedCity preferredState:self.selectedState];
}

- (NSString *)pp_normalizedComparableName:(NSString *)value
{
    NSString *trimmed = [[self pp_trimmedString:value] lowercaseString];
    if (trimmed.length == 0) {
        return @"";
    }

    NSCharacterSet *stripSet = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
    NSArray<NSString *> *parts = [trimmed componentsSeparatedByCharactersInSet:stripSet];
    return [[parts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]] componentsJoinedByString:@""];
}

- (CityModel *)pp_cityMatchingPlacemark:(CLPlacemark *)placemark inCities:(NSArray<CityModel *> *)cities
{
    NSArray<NSString *> *candidateNames = @[
        placemark.locality ?: @"",
        placemark.subAdministrativeArea ?: @"",
        placemark.administrativeArea ?: @"",
    ];

    for (NSString *candidateName in candidateNames) {
        NSString *normalizedCandidate = [self pp_normalizedComparableName:candidateName];
        if (normalizedCandidate.length == 0) {
            continue;
        }

        for (CityModel *city in cities ?: @[]) {
            NSArray<NSString *> *cityNames = @[city.enName ?: @"", city.arName ?: @""];
            for (NSString *cityName in cityNames) {
                NSString *normalizedCity = [self pp_normalizedComparableName:cityName];
                if (normalizedCity.length == 0) {
                    continue;
                }
                if ([normalizedCandidate isEqualToString:normalizedCity] ||
                    [normalizedCandidate containsString:normalizedCity] ||
                    [normalizedCity containsString:normalizedCandidate]) {
                    return city;
                }
            }
        }
    }

    return nil;
}

- (StateModel *)pp_stateMatchingPlacemark:(CLPlacemark *)placemark inStates:(NSArray<StateModel *> *)states
{
    NSArray<NSString *> *candidateNames = @[
        placemark.subLocality ?: @"",
        placemark.thoroughfare ?: @"",
        placemark.name ?: @"",
    ];

    for (NSString *candidateName in candidateNames) {
        NSString *normalizedCandidate = [self pp_normalizedComparableName:candidateName];
        if (normalizedCandidate.length == 0) {
            continue;
        }

        for (StateModel *state in states ?: @[]) {
            NSArray<NSString *> *stateNames = @[state.enName ?: @"", state.arName ?: @""];
            for (NSString *stateName in stateNames) {
                NSString *normalizedState = [self pp_normalizedComparableName:stateName];
                if (normalizedState.length == 0) {
                    continue;
                }
                if ([normalizedCandidate isEqualToString:normalizedState] ||
                    [normalizedCandidate containsString:normalizedState] ||
                    [normalizedState containsString:normalizedCandidate]) {
                    return state;
                }
            }
        }
    }

    return nil;
}

- (BOOL)pp_isValidCoordinate:(CLLocationCoordinate2D)coordinate
{
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        return NO;
    }
    return !(fabs(coordinate.latitude) < 0.000001 && fabs(coordinate.longitude) < 0.000001);
}

- (CityModel *)pp_nearestCityForCoordinate:(CLLocationCoordinate2D)coordinate
{
    if (![self pp_isValidCoordinate:coordinate]) {
        return nil;
    }

    NSArray<CityModel *> *cities = self.citiesArray ?: @[];
    if (cities.count == 0) {
        cities = [self pp_citiesForCountryOrQatar:self.resolvedCountry];
    }
    if (cities.count == 0) {
        return nil;
    }

    CLLocation *target = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
    CityModel *nearestCity = nil;
    CLLocationDistance bestDistance = DBL_MAX;

    for (CityModel *city in cities) {
        CLLocationCoordinate2D cityCoordinate = CLLocationCoordinate2DMake(city.latitude, city.longitude);
        if (![self pp_isValidCoordinate:cityCoordinate]) {
            continue;
        }

        CLLocation *cityLocation = [[CLLocation alloc] initWithLatitude:cityCoordinate.latitude longitude:cityCoordinate.longitude];
        CLLocationDistance distance = [target distanceFromLocation:cityLocation];
        if (distance < bestDistance) {
            bestDistance = distance;
            nearestCity = city;
        }
    }

    return nearestCity ?: cities.firstObject;
}

- (StateModel *)pp_defaultStateForCity:(CityModel *)city
{
    if (![city isKindOfClass:CityModel.class]) {
        return nil;
    }
    return city.states.firstObject;
}

- (void)pp_reloadRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    (void)indexPaths;
    [self pp_refreshFormValuesAndStates];
}

- (NSIndexPath *)pp_indexPathForFieldKind:(PPAddressFieldKind)fieldKind
{
    switch (fieldKind) {
        case PPAddressFieldKindFullName:
            return [NSIndexPath indexPathForRow:0 inSection:0];
        case PPAddressFieldKindPhoneNumber:
            return [NSIndexPath indexPathForRow:1 inSection:0];
        case PPAddressFieldKindAddressLine1:
            return [NSIndexPath indexPathForRow:0 inSection:1];
        case PPAddressFieldKindAddressLine2:
            return [NSIndexPath indexPathForRow:1 inSection:1];
        case PPAddressFieldKindPostalCode:
            return [NSIndexPath indexPathForRow:2 inSection:1];
        case PPAddressFieldKindCountry:
            return [NSIndexPath indexPathForRow:0 inSection:2];
        case PPAddressFieldKindCity:
            return [NSIndexPath indexPathForRow:1 inSection:2];
        case PPAddressFieldKindState:
            return [NSIndexPath indexPathForRow:2 inSection:2];
        case PPAddressFieldKindLocation:
            return [NSIndexPath indexPathForRow:3 inSection:2];
    }
}

- (void)pp_reloadGeographyRows
{
    [self pp_reloadRowsAtIndexPaths:@[
        [self pp_indexPathForFieldKind:PPAddressFieldKindCountry],
        [self pp_indexPathForFieldKind:PPAddressFieldKindCity],
        [self pp_indexPathForFieldKind:PPAddressFieldKindState],
        [self pp_indexPathForFieldKind:PPAddressFieldKindLocation]
    ]];
}

- (void)pp_applyCountry:(CountryModel *)country
          preferredCity:(CityModel *)preferredCity
         preferredState:(StateModel *)preferredState
{
    CountryModel *resolvedCountry = [country isKindOfClass:CountryModel.class] ? country : [self pp_qatarCountry];
    self.resolvedCountry = resolvedCountry;
    self.selectedCountry = resolvedCountry;
    self.countriesArray = [self pp_availableCountries];
    self.citiesArray = [self pp_citiesForCountryOrQatar:resolvedCountry];

    CityModel *resolvedCity = preferredCity;
    if (![resolvedCity isKindOfClass:CityModel.class] || ![self.citiesArray containsObject:resolvedCity]) {
        resolvedCity = [CitiesManager.shared defaultCityForCountry:resolvedCountry];
    }
    if (![resolvedCity isKindOfClass:CityModel.class]) {
        resolvedCity = self.citiesArray.firstObject;
    }
    if (![resolvedCity isKindOfClass:CityModel.class]) {
        self.selectedCity = nil;
        self.statesArray = @[];
        self.selectedState = nil;
        [self pp_reloadGeographyRows];
        [self pp_refreshHeaderContent];
        return;
    }

    [self pp_applyCity:resolvedCity state:preferredState];
}

- (void)pp_applyCity:(CityModel *)city state:(StateModel *)state
{
    if (![city isKindOfClass:CityModel.class]) {
        return;
    }

    self.resolvedCountry = city.country ?: self.resolvedCountry ?: [self pp_qatarCountry];
    self.selectedCountry = self.resolvedCountry;
    self.countriesArray = [self pp_availableCountries];
    self.citiesArray = [self pp_citiesForCountryOrQatar:self.resolvedCountry];
    self.selectedCity = city;
    self.statesArray = city.states ?: @[];

    StateModel *resolvedState = state;
    if (![resolvedState isKindOfClass:StateModel.class] || ![self.statesArray containsObject:resolvedState]) {
        resolvedState = [self pp_defaultStateForCity:city];
    }
    self.selectedState = resolvedState;

    [self pp_reloadGeographyRows];
    [self pp_refreshHeaderContent];
}

- (void)pp_applyCoordinateToForm:(CLLocationCoordinate2D)coordinate
                   suggestedTitle:(NSString *)suggestedTitle
{
    if (![self pp_isValidCoordinate:coordinate]) {
        return;
    }

    self.didApplyInitialLocation = YES;
    self.currentDeviceCoordinate = coordinate;
    self.selectedLocationPoints = [NSString stringWithFormat:@"%f, %f", coordinate.latitude, coordinate.longitude];
    self.selectedLocationName = suggestedTitle.length > 0
        ? suggestedTitle
        : [NSString stringWithFormat:@"%.6f, %.6f", coordinate.latitude, coordinate.longitude];

    CityModel *nearestCity = [self pp_nearestCityForCoordinate:coordinate];
    if (nearestCity) {
        [self pp_applyCity:nearestCity state:[self pp_defaultStateForCity:nearestCity]];
    } else {
        [self pp_reloadRowsAtIndexPaths:@[[self pp_indexPathForFieldKind:PPAddressFieldKindLocation]]];
        [self pp_refreshHeaderContent];
    }
}

- (NSString *)pp_titleFromPlacemark:(CLPlacemark *)placemark
{
    if (!placemark) {
        return @"";
    }

    NSString *primary = placemark.subLocality ?: placemark.locality ?: placemark.thoroughfare ?: @"";
    NSString *secondary = placemark.locality ?: placemark.administrativeArea ?: placemark.country ?: @"";
    if ([primary isEqualToString:secondary]) {
        secondary = @"";
    }
    if (primary.length > 0 && secondary.length > 0) {
        return [NSString stringWithFormat:@"%@, %@", primary, secondary];
    }
    return primary.length > 0 ? primary : secondary;
}

- (NSString *)titleFromAddress:(GMSAddress *)address
{
    if (!address) {
        return @"";
    }

    NSString *primary = address.subLocality ?: address.locality ?: address.thoroughfare ?: @"";
    NSString *secondary = address.locality ?: address.administrativeArea ?: address.country ?: @"";
    if ([primary isEqualToString:secondary]) {
        secondary = @"";
    }
    if (primary.length > 0 && secondary.length > 0) {
        return [NSString stringWithFormat:@"%@, %@", primary, secondary];
    }
    return primary.length > 0 ? primary : secondary;
}

- (void)pp_reverseGeocodeCoordinateForRowTitle:(CLLocationCoordinate2D)coordinate
{
    if (![self pp_isValidCoordinate:coordinate]) {
        return;
    }
    if (!self.reverseGeocoder) {
        self.reverseGeocoder = [[CLGeocoder alloc] init];
    }
    if (self.reverseGeocoder.isGeocoding) {
        [self.reverseGeocoder cancelGeocode];
    }

    CLLocation *location = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
    __weak typeof(self) weakSelf = self;
    [self.reverseGeocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        if (error || placemarks.count == 0) {
            return;
        }

        CLPlacemark *placemark = placemarks.firstObject;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }

            CountryModel *placemarkCountry = [CitiesManager.shared countryWithCode:placemark.ISOcountryCode];
            if (!placemarkCountry) {
                placemarkCountry = self.resolvedCountry ?: [self pp_qatarCountry];
            }
            self.resolvedCountry = placemarkCountry ?: [self pp_qatarCountry];
            self.selectedCountry = self.resolvedCountry;
            self.citiesArray = [self pp_citiesForCountryOrQatar:self.resolvedCountry];

            CityModel *matchedCity = [self pp_cityMatchingPlacemark:placemark inCities:self.citiesArray];
            if (!matchedCity) {
                matchedCity = [self pp_nearestCityForCoordinate:coordinate];
            }
            if (matchedCity) {
                StateModel *matchedState = [self pp_stateMatchingPlacemark:placemark inStates:matchedCity.states];
                [self pp_applyCity:matchedCity state:matchedState];
            }

            NSString *resolvedTitle = [self pp_titleFromPlacemark:placemark];
            if (resolvedTitle.length == 0 && matchedCity) {
                resolvedTitle = [self pp_localizedCityName:matchedCity];
            }
            if (resolvedTitle.length == 0 && self.resolvedCountry) {
                resolvedTitle = [self pp_localizedCountryName:self.resolvedCountry];
            }
            if (resolvedTitle.length > 0) {
                self.selectedLocationName = resolvedTitle;
            }

            [self pp_reloadGeographyRows];
            [self pp_refreshHeaderContent];
        });
    }];
}

- (void)pp_openLocationPicker
{
    LocationPickerViewController *pickerVC = [[LocationPickerViewController alloc] init];
    CLLocationCoordinate2D initialCoordinate = kCLLocationCoordinate2DInvalid;
    if (self.selectedLocationPoints.length > 0) {
        NSArray<NSString *> *parts = [self.selectedLocationPoints componentsSeparatedByString:@","];
        if (parts.count >= 2) {
            double latitude = [parts[0] doubleValue];
            double longitude = [parts[1] doubleValue];
            CLLocationCoordinate2D parsed = CLLocationCoordinate2DMake(latitude, longitude);
            if ([self pp_isValidCoordinate:parsed]) {
                initialCoordinate = parsed;
            }
        }
    }
    if (![self pp_isValidCoordinate:initialCoordinate] && [self pp_isValidCoordinate:self.currentDeviceCoordinate]) {
        initialCoordinate = self.currentDeviceCoordinate;
    }
    if ([self pp_isValidCoordinate:initialCoordinate]) {
        pickerVC.initialCoordinate = initialCoordinate;
    }

    __weak typeof(self) weakSelf = self;
    pickerVC.onLocationConfirmed = ^(GMSAddress *gmsAddress) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !gmsAddress) {
            return;
        }

        CLLocationCoordinate2D coordinate = gmsAddress.coordinate;
        NSString *resolvedTitle = [self titleFromAddress:gmsAddress];
        [self pp_applyCoordinateToForm:coordinate suggestedTitle:resolvedTitle];
        [self pp_reverseGeocodeCoordinateForRowTitle:coordinate];
    };
    pickerVC.onCoordinateConfirmed = ^(CLLocationCoordinate2D coordinate, NSString *locationTitle) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        [self pp_applyCoordinateToForm:coordinate suggestedTitle:locationTitle];
        [self pp_reverseGeocodeCoordinateForRowTitle:coordinate];
    };

    if (self.navigationController) {
        [self.navigationController pushViewController:pickerVC animated:YES];
    } else {
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:pickerVC];
        [self presentViewController:navigationController animated:YES completion:nil];
    }
}

- (void)pp_pushOptionsControllerWithTitle:(NSString *)title
                                  options:(NSArray *)options
                           selectedOption:(id)selectedOption
                            titleProvider:(NSString * _Nonnull (^)(id option))titleProvider
                         selectionHandler:(void (^)(id option))selectionHandler
{
    if (options.count == 0) {
        [PPHUD showInfo:kLang(@"address_no_options_available") ?: @"No options available"];
        return;
    }

    __weak typeof(self) weakSelf = self;
    PPSelectOptionViewController *picker = [[PPSelectOptionViewController alloc]
        initWithOptions:options
                  title:title ?: @""
                    row:nil
       presentationStyle:PPSelectOptionPresentationSheet
         showSearchBar:YES
             completion:^(id _Nullable selectedObject) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !selectedObject) {
            return;
        }
        if (selectionHandler) {
            selectionHandler(selectedObject);
        }
    }];

    picker.allOptions = options;
    picker.filteredOptions = options;
    picker.selectedOption = selectedOption;
    picker.optionTitleProvider = titleProvider;
    picker.optionCellBackgroundColor = [self pp_surfaceColor];
    picker.usesCompactOptionIcons = YES;
    picker.usesCompactPremiumHero = YES;
    picker.preferredPremiumDetentFraction = 0.82;
    [picker configurePremiumHeroWithEyebrow:kLang(@"AddressHeroEyebrow") ?: @"Delivery destination"
                                      title:title ?: @""
                                   subtitle:kLang(@"TapToSelect") ?: @"Choose one option"
                                  symbolName:@"mappin.and.ellipse"
                                  badgeText:nil];
    picker.premiumHeroAccentColor = AppPrimaryClr ?: UIColor.systemOrangeColor;

    UINavigationController *sheetNavigationController = [[UINavigationController alloc] initWithRootViewController:picker];
    [PPFunc presentSheetFrom:self
                     sheetVC:sheetNavigationController
                 detentStyle:PPSheetDetentStyle80];
}

- (void)pp_presentPhoneCodeOptions
{
    NSArray<CountryCodeModel *> *options = [GM getMiddleEastCountriesForLanguage:[Language currentLanguageCode]];
    if (options.count == 0) {
        [PPHUD showInfo:kLang(@"address_no_options_available") ?: @"No phone countries available"];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self pp_pushOptionsControllerWithTitle:kLang(@"PhoneCountryCode") ?: @"Phone country code"
                                    options:options
                             selectedOption:self.autoDetectedCountry
                              titleProvider:^NSString * _Nonnull(CountryCodeModel *option) {
        NSString *country = option.country ?: @"";
        NSString *code = option.phoneCode ?: @"";
        return code.length > 0 ? [NSString stringWithFormat:@"%@ %@", country, code] : country;
    } selectionHandler:^(CountryCodeModel *option) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || ![option isKindOfClass:CountryCodeModel.class]) {
            return;
        }

        NSString *safeCode = option.phoneCode.length > 0 ? option.phoneCode : (self.currentPhoneCode ?: @"+974");
        self.autoDetectedCountry = option;
        self.currentPhoneCode = [safeCode hasPrefix:@"+"] ? safeCode : [@"+" stringByAppendingString:safeCode];
        self.draftPhoneNumber = [NSString stringWithFormat:@"%@%@", self.currentPhoneCode, self.draftPhoneDigits ?: @"" ];
        [self pp_refreshFormValuesAndStates];
    }];
}

- (void)pp_presentCountryOptions
{
    NSArray<CountryModel *> *options = [self pp_availableCountries];
    if (options.count == 0) {
        [PPHUD showInfo:kLang(@"TapToSelect") ?: @"No countries available"];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self pp_pushOptionsControllerWithTitle:kLang(@"Country") ?: @"Country"
                                    options:options
                             selectedOption:self.selectedCountry
                              titleProvider:^NSString * _Nonnull(CountryModel *option) {
        return [weakSelf pp_localizedCountryName:option];
    } selectionHandler:^(CountryModel *option) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || ![option isKindOfClass:CountryModel.class]) {
            return;
        }
        [self pp_applyCountry:option preferredCity:nil preferredState:nil];
    }];
}

- (void)pp_presentCityOptions
{
    if (!self.selectedCountry) {
        [PPHUD showInfo:kLang(@"TapToSelect") ?: @"Select a country first"];
        return;
    }
    if (self.citiesArray.count == 0) {
        self.citiesArray = [self pp_citiesForCountryOrQatar:self.selectedCountry];
    }
    if (self.citiesArray.count == 0) {
        [PPHUD showInfo:kLang(@"TapToSelect") ?: @"No cities available"];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self pp_pushOptionsControllerWithTitle:kLang(@"City") ?: @"City"
                                    options:self.citiesArray
                             selectedOption:self.selectedCity
                              titleProvider:^NSString * _Nonnull(CityModel *option) {
        return [weakSelf pp_localizedCityName:option];
    } selectionHandler:^(CityModel *option) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || ![option isKindOfClass:CityModel.class]) {
            return;
        }
        [self pp_applyCity:option state:nil];
    }];
}

- (void)pp_presentStateOptions
{
    if (!self.selectedCity) {
        [PPHUD showInfo:kLang(@"TapToSelect") ?: @"Select a city first"];
        return;
    }
    if (self.statesArray.count == 0) {
        self.statesArray = self.selectedCity.states ?: @[];
    }
    if (self.statesArray.count == 0) {
        [PPHUD showInfo:kLang(@"TapToSelect") ?: @"No areas available"];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self pp_pushOptionsControllerWithTitle:kLang(@"State") ?: @"State"
                                    options:self.statesArray
                             selectedOption:self.selectedState
                              titleProvider:^NSString * _Nonnull(StateModel *option) {
        return [weakSelf pp_localizedStateName:option];
    } selectionHandler:^(StateModel *option) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || ![option isKindOfClass:StateModel.class]) {
            return;
        }
        self.selectedState = option;
        [self pp_reloadRowsAtIndexPaths:@[[self pp_indexPathForFieldKind:PPAddressFieldKindState]]];
    }];
}

#pragma mark - Table Structure

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.address ? 5 : 4;
}

- (PPAddressSectionKind)pp_sectionKindForSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return PPAddressSectionKindRecipient;
        case 1:
            return PPAddressSectionKindStreet;
        case 2:
            return PPAddressSectionKindGeography;
        case 3:
            return PPAddressSectionKindPreferences;
        default:
            return PPAddressSectionKindDanger;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch ([self pp_sectionKindForSection:section]) {
        case PPAddressSectionKindRecipient:
            return 2;
        case PPAddressSectionKindStreet:
            return 3;
        case PPAddressSectionKindGeography:
            return 4;
        case PPAddressSectionKindPreferences:
            return 1;
        case PPAddressSectionKindDanger:
            return self.address ? 1 : 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch ([self pp_sectionKindForSection:indexPath.section]) {
        case PPAddressSectionKindRecipient: {
            if (indexPath.row == 0) {
                PPAddressTextFieldCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPAddressTextFieldCell" forIndexPath:indexPath];
                [cell configureWithTitle:kLang(@"FullName") ?: @"Full name"
                                    text:self.draftFullName
                             placeholder:kLang(@"FullNamePlaceholder") ?: @"Who should receive this order?"
                            keyboardType:UIKeyboardTypeDefault
                         textContentType:UITextContentTypeName
                           returnKeyType:UIReturnKeyNext
                  autocapitalizationType:UITextAutocapitalizationTypeWords
                               fieldKind:PPAddressFieldKindFullName
                                  target:self
                                  action:@selector(pp_textFieldEditingChanged:)
                                delegate:self];
                return cell;
            } else {
                PPAddressPhoneCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPAddressPhoneCell" forIndexPath:indexPath];
                NSString *flag = self.autoDetectedCountry.flag ?: @"";
                NSString *codeTitle = flag.length > 0
                    ? [NSString stringWithFormat:@"%@ %@", flag, self.currentPhoneCode]
                    : (self.currentPhoneCode ?: @"+974");
                [cell configureWithTitle:kLang(@"MobileNo_Palce") ?: @"Phone number"
                        countryCodeTitle:codeTitle
                               phoneText:self.draftPhoneDigits
                             placeholder:kLang(@"MobileNo_Palce") ?: @"Add a reachable phone number"
                               fieldKind:PPAddressFieldKindPhoneNumber
                                  target:self
                           countryAction:@selector(pp_showAddressCountryCodePicker)
                            phoneAction:@selector(pp_phoneFieldChanged:)
                                delegate:self];
                return cell;
            }
        }

        case PPAddressSectionKindStreet: {
            PPAddressTextFieldCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPAddressTextFieldCell" forIndexPath:indexPath];
            if (indexPath.row == 0) {
                [cell configureWithTitle:kLang(@"AddressLine1") ?: @"Address line 1"
                                    text:self.draftAddressLine1
                             placeholder:kLang(@"AddressLine1Placeholder") ?: @"Street, building, or house number"
                            keyboardType:UIKeyboardTypeDefault
                         textContentType:UITextContentTypeFullStreetAddress
                           returnKeyType:UIReturnKeyNext
                  autocapitalizationType:UITextAutocapitalizationTypeWords
                               fieldKind:PPAddressFieldKindAddressLine1
                                  target:self
                                  action:@selector(pp_textFieldEditingChanged:)
                                delegate:self];
            } else if (indexPath.row == 1) {
                [cell configureWithTitle:kLang(@"AddressLine2Optional") ?: @"Address line 2"
                                    text:self.draftAddressLine2
                             placeholder:kLang(@"AddressLine2Placeholder") ?: @"Apartment, suite, landmark, or notes"
                            keyboardType:UIKeyboardTypeDefault
                         textContentType:UITextContentTypeFullStreetAddress
                           returnKeyType:UIReturnKeyNext
                  autocapitalizationType:UITextAutocapitalizationTypeWords
                               fieldKind:PPAddressFieldKindAddressLine2
                                  target:self
                                  action:@selector(pp_textFieldEditingChanged:)
                                delegate:self];
            } else {
                [cell configureWithTitle:kLang(@"PostalCode") ?: @"Postal code"
                                    text:self.draftPostalCode
                             placeholder:kLang(@"PostalCodePlaceholder") ?: @"Postal or zip code"
                            keyboardType:UIKeyboardTypeDefault
                         textContentType:UITextContentTypePostalCode
                           returnKeyType:UIReturnKeyDone
                  autocapitalizationType:UITextAutocapitalizationTypeNone
                               fieldKind:PPAddressFieldKindPostalCode
                                  target:self
                                  action:@selector(pp_textFieldEditingChanged:)
                                delegate:self];
            }
            return cell;
        }

        case PPAddressSectionKindGeography: {
            PPAddressSelectorCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPAddressSelectorCell" forIndexPath:indexPath];
            if (indexPath.row == 0) {
                [cell configureWithTitle:kLang(@"Country") ?: @"Country"
                                   value:[self pp_localizedCountryName:self.selectedCountry]
                             placeholder:kLang(@"TapToSelect") ?: @"Tap to select"
                                  detail:kLang(@"SelectCountryTitle") ?: @"Country controls the available cities and areas."];
            } else if (indexPath.row == 1) {
                NSString *detail = self.selectedCountry
                    ? ([NSString stringWithFormat:@"%@ %@", kLang(@"Country") ?: @"Country:", [self pp_localizedCountryName:self.selectedCountry]])
                    : (kLang(@"TapToSelect") ?: @"Select a country first");
                [cell configureWithTitle:kLang(@"City") ?: @"City"
                                   value:[self pp_localizedCityName:self.selectedCity]
                             placeholder:kLang(@"TapToSelect") ?: @"Tap to select"
                                  detail:detail];
            } else if (indexPath.row == 2) {
                NSString *detail = self.selectedCity
                    ? [self pp_localizedCityName:self.selectedCity]
                    : (kLang(@"TapToSelect") ?: @"Select a city first");
                [cell configureWithTitle:kLang(@"State") ?: @"Area"
                                   value:[self pp_localizedStateName:self.selectedState]
                             placeholder:kLang(@"TapToSelect") ?: @"Tap to select"
                                  detail:detail];
            } else {
                NSString *locationDetail = self.selectedLocationPoints.length > 0
                    ? self.selectedLocationPoints
                    : (kLang(@"MapLocation") ?: @"Pin the exact drop-off point for couriers.");
                [cell configureWithTitle:kLang(@"MapLocation") ?: @"Map location"
                                   value:self.selectedLocationName
                             placeholder:kLang(@"TapToSelect") ?: @"Tap to select"
                                  detail:locationDetail];
            }
            return cell;
        }

        case PPAddressSectionKindPreferences: {
            PPAddressSwitchCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPAddressSwitchCell" forIndexPath:indexPath];
            [cell configureWithTitle:kLang(@"DefaultShippingAddress") ?: @"Default shipping address"
                            subtitle:kLang(@"DefaultShippingAddressSubtitle") ?: @"Use this address automatically when checkout opens."
                                  on:self.draftIsDefault
                              target:self
                              action:@selector(pp_defaultSwitchChanged:)];
            return cell;
        }

        case PPAddressSectionKindDanger: {
            PPAddressActionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPAddressActionCell" forIndexPath:indexPath];
            [cell configureWithTitle:kLang(@"DeleteAddress") ?: @"Delete address" iconName:@"trash" destructive:YES];
            return cell;
        }
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL isDangerSection = [self pp_sectionKindForSection:indexPath.section] == PPAddressSectionKindDanger;
    UIColor *surfaceColor = isDangerSection
        ? [[UIColor systemRedColor] colorWithAlphaComponent:0.08]
        : [self pp_surfaceColor];
    UIColor *borderColor = isDangerSection
        ? [[UIColor systemRedColor] colorWithAlphaComponent:0.18]
        : [self pp_surfaceBorderColor];

    cell.backgroundColor = UIColor.clearColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.contentView.backgroundColor = surfaceColor;
    PPApplyContinuousCorners(cell.contentView, PPCornerMedium);
    cell.contentView.layer.masksToBounds = YES;
    cell.contentView.layer.borderWidth = 1.0;
    [cell.contentView pp_setBorderColor:borderColor];
    cell.layer.shadowOpacity = 0.0;
    cell.layer.masksToBounds = YES;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    PPAddressSectionKind sectionKind = [self pp_sectionKindForSection:indexPath.section];
    return sectionKind == PPAddressSectionKindGeography || sectionKind == PPAddressSectionKindDanger;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    PPAddressSectionKind sectionKind = [self pp_sectionKindForSection:indexPath.section];
    if (sectionKind == PPAddressSectionKindDanger) {
        [self showDeleteConfirmation];
        return;
    }
    if (sectionKind != PPAddressSectionKindGeography) {
        return;
    }

    switch (indexPath.row) {
        case 0:
            [self pp_presentCountryOptions];
            break;
        case 1:
            [self pp_presentCityOptions];
            break;
        case 2:
            [self pp_presentStateOptions];
            break;
        default:
            [self pp_openLocationPicker];
            break;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section
{
    return section == 0 ? (PPSpace4XL + PPSpaceXL) : (PPSpace4XL + PPSpaceXXL);
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return PPSpaceMD;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForFooterInSection:(NSInteger)section
{
    return PPSpaceMD;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    return [UIView new];
}

- (NSArray<NSString *> *)pp_sectionHeaderContentForSectionKind:(PPAddressSectionKind)sectionKind
{
    switch (sectionKind) {
        case PPAddressSectionKindRecipient:
            return @[
                [self pp_localizedAddressStringForKey:@"Recipient" fallback:@"Recipient"],
                [self pp_localizedAddressStringForKey:@"RecipientSubtitle" fallback:@"Who receives the order and which number should delivery call?"]
            ];
        case PPAddressSectionKindStreet:
            return @[
                [self pp_localizedAddressStringForKey:@"StreetDetails" fallback:@"Street details"],
                [self pp_localizedAddressStringForKey:@"StreetDetailsSubtitle" fallback:@"Add the lines couriers need to find the exact door."]
            ];
        case PPAddressSectionKindGeography:
            return @[
                [self pp_localizedAddressStringForKey:@"AreaAndMap" fallback:@"Area and map"],
                [self pp_localizedAddressStringForKey:@"AreaAndMapSubtitle" fallback:@"Country, city, area, and the map pin should all point to the same place."]
            ];
        case PPAddressSectionKindPreferences:
            return @[
                [self pp_localizedAddressStringForKey:@"DeliveryPreferences" fallback:@"Delivery preferences"],
                [self pp_localizedAddressStringForKey:@"DeliveryPreferencesSubtitle" fallback:@"Choose how this address should behave at checkout."]
            ];
        case PPAddressSectionKindDanger:
            return @[
                [self pp_localizedAddressStringForKey:@"DangerZone" fallback:@"Danger zone"],
                [self pp_localizedAddressStringForKey:@"DangerZoneSubtitle" fallback:@"Remove this saved address permanently."]
            ];
    }
}

- (UIView *)pp_sectionHeaderViewWithTitle:(NSString *)title subtitle:(NSString *)subtitle tintColor:(UIColor *)tintColor
{
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = UIColor.clearColor;

    UIView *accentBar = [[UIView alloc] init];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = tintColor ?: (AppPrimaryClr ?: UIColor.systemOrangeColor);
    PPApplyContinuousCorners(accentBar, PPCornerPill);
    [container addSubview:accentBar];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = PPAddressScaledFont([GM boldFontWithSize:PPFontHeadline] ?: [UIFont systemFontOfSize:PPFontHeadline weight:UIFontWeightSemibold], UIFontTextStyleHeadline);
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.text = title ?: @"";
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.adjustsFontForContentSizeCategory = YES;
    [container addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = PPAddressScaledFont([GM MidFontWithSize:PPFontFootnote] ?: [UIFont systemFontOfSize:PPFontFootnote weight:UIFontWeightMedium], UIFontTextStyleFootnote);
    subtitleLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    subtitleLabel.text = subtitle ?: @"";
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.adjustsFontForContentSizeCategory = YES;
    [container addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [accentBar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [accentBar.topAnchor constraintEqualToAnchor:container.topAnchor constant:PPSpaceLG],
        [accentBar.widthAnchor constraintEqualToConstant:PPSpaceXL],
        [accentBar.heightAnchor constraintEqualToConstant:PPSpaceXS],

        [titleLabel.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:PPSpaceSM],
        [titleLabel.leadingAnchor constraintEqualToAnchor:accentBar.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:PPSpaceXS],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-PPSpaceMD]
    ]];

    return container;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    PPAddressSectionKind sectionKind = [self pp_sectionKindForSection:section];
    NSArray<NSString *> *content = [self pp_sectionHeaderContentForSectionKind:sectionKind];
    UIColor *tintColor = sectionKind == PPAddressSectionKindDanger
        ? UIColor.systemRedColor
        : (AppPrimaryClr ?: UIColor.systemOrangeColor);
    return [self pp_sectionHeaderViewWithTitle:content.firstObject subtitle:content.lastObject tintColor:tintColor];
}

#pragma mark - Editing

- (void)pp_textFieldEditingChanged:(UITextField *)textField
{
    NSString *value = textField.text ?: @"";
    switch ((PPAddressFieldKind)textField.tag) {
        case PPAddressFieldKindFullName:
            self.draftFullName = value;
            break;
        case PPAddressFieldKindPhoneNumber:
            self.draftPhoneNumber = value;
            break;
        case PPAddressFieldKindAddressLine1:
            self.draftAddressLine1 = value;
            break;
        case PPAddressFieldKindAddressLine2:
            self.draftAddressLine2 = value;
            break;
        case PPAddressFieldKindPostalCode:
            self.draftPostalCode = value;
            break;
        default:
            break;
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    PPFormFieldRowView *fullNameRow = [self.recipientFormView rowForIdentifier:PPAddressFormFieldFullName];
    PPFormFieldRowView *phoneRow = [self.recipientFormView rowForIdentifier:PPAddressFormFieldPhone];
    PPFormFieldRowView *addressLine1Row = [self.streetFormView rowForIdentifier:PPAddressFormFieldAddressLine1];
    PPFormFieldRowView *addressLine2Row = [self.streetFormView rowForIdentifier:PPAddressFormFieldAddressLine2];
    PPFormFieldRowView *postalCodeRow = [self.streetFormView rowForIdentifier:PPAddressFormFieldPostalCode];

    if (textField == fullNameRow.textField) {
        [self pp_focusFieldIdentifier:PPAddressFormFieldPhone];
        return NO;
    }
    if (textField == phoneRow.textField) {
        [self pp_focusFieldIdentifier:PPAddressFormFieldAddressLine1];
        return NO;
    }
    if (textField == addressLine1Row.textField) {
        [self pp_focusFieldIdentifier:PPAddressFormFieldAddressLine2];
        return NO;
    }
    if (textField == addressLine2Row.textField) {
        [self pp_focusFieldIdentifier:PPAddressFormFieldPostalCode];
        return NO;
    }

    if (textField == postalCodeRow.textField) {
        [textField resignFirstResponder];
        return YES;
    }

    [textField resignFirstResponder];
    return YES;
}

- (PPFormEngineView *)pp_formViewForFieldIdentifier:(NSString *)identifier
{
    if ([self.recipientFormView rowForIdentifier:identifier]) {
        return self.recipientFormView;
    }
    if ([self.streetFormView rowForIdentifier:identifier]) {
        return self.streetFormView;
    }
    if ([self.geographyFormView rowForIdentifier:identifier]) {
        return self.geographyFormView;
    }
    return nil;
}

- (void)pp_focusFieldIdentifier:(NSString *)identifier
{
    PPFormEngineView *form = [self pp_formViewForFieldIdentifier:identifier];
    PPFormFieldRowView *row = [form rowForIdentifier:identifier];
    if (!form || !row) {
        return;
    }

    [self.formScrollView layoutIfNeeded];
    CGRect rowRect = [row convertRect:row.bounds toView:self.formScrollView];
    rowRect = CGRectInset(rowRect, 0.0, -PPSpaceLG);
    [self.formScrollView scrollRectToVisible:rowRect animated:!UIAccessibilityIsReduceMotionEnabled()];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [row.textField becomeFirstResponder];
    });
}

- (void)pp_focusFieldKind:(PPAddressFieldKind)fieldKind
{
    NSString *identifier = nil;
    switch (fieldKind) {
        case PPAddressFieldKindFullName: identifier = PPAddressFormFieldFullName; break;
        case PPAddressFieldKindPhoneNumber: identifier = PPAddressFormFieldPhone; break;
        case PPAddressFieldKindAddressLine1: identifier = PPAddressFormFieldAddressLine1; break;
        case PPAddressFieldKindAddressLine2: identifier = PPAddressFormFieldAddressLine2; break;
        case PPAddressFieldKindPostalCode: identifier = PPAddressFormFieldPostalCode; break;
        default: break;
    }
    if (identifier.length > 0) {
        [self pp_focusFieldIdentifier:identifier];
    }
}

- (void)pp_defaultSwitchChanged:(UISwitch *)sender
{
    self.draftIsDefault = sender.isOn;
}

#pragma mark - Validation and Save

- (void)pp_syncDraftFromForm
{
    if (!self.recipientFormView || !self.streetFormView) {
        return;
    }

    self.draftFullName = [self pp_trimmedString:[self.recipientFormView valueForIdentifier:PPAddressFormFieldFullName]];
    self.draftPhoneDigits = [self pp_digitsOnlyValue:[self.recipientFormView valueForIdentifier:PPAddressFormFieldPhone]];
    self.draftPhoneNumber = [NSString stringWithFormat:@"%@%@", self.currentPhoneCode ?: @"+974", self.draftPhoneDigits ?: @"" ];
    self.draftAddressLine1 = [self pp_trimmedString:[self.streetFormView valueForIdentifier:PPAddressFormFieldAddressLine1]];
    self.draftAddressLine2 = [self pp_trimmedString:[self.streetFormView valueForIdentifier:PPAddressFormFieldAddressLine2]];
    self.draftPostalCode = [self pp_trimmedString:[self.streetFormView valueForIdentifier:PPAddressFormFieldPostalCode]];
}

- (BOOL)pp_validateAddressForm
{
    [self pp_syncDraftFromForm];
    [self.recipientFormView validate];
    [self.streetFormView validate];
    [self.geographyFormView validate];

    if (self.draftFullName.length == 0) {
        [self pp_showValidationErrorForIdentifier:PPAddressFormFieldFullName
                                         subtitle:kLang(@"FullNamePlaceholder") ?: @"Full name is required"];
        return NO;
    }
    if (self.draftPhoneDigits.length == 0) {
        [self pp_showValidationErrorForIdentifier:PPAddressFormFieldPhone
                                         subtitle:kLang(@"MobileNo_Palce") ?: @"Phone number is required"];
        return NO;
    }
    if (self.draftAddressLine1.length == 0) {
        [self pp_showValidationErrorForIdentifier:PPAddressFormFieldAddressLine1
                                         subtitle:kLang(@"AddressLine1Placeholder") ?: @"Address line 1 is required"];
        return NO;
    }
    if (!self.selectedCountry) {
        [self.geographyFormView setErrorText:kLang(@"SelectCountryTitle") ?: @"Select a country"
                             forIdentifier:PPAddressFormFieldCountry];
        [self pp_showValidationErrorForIdentifier:PPAddressFormFieldCountry
                                         subtitle:kLang(@"SelectCountryTitle") ?: @"Select a country"];
        return NO;
    }
    if (self.selectedCity.cityID <= 0) {
        [self.geographyFormView setErrorText:kLang(@"TapToSelect") ?: @"Select a city"
                             forIdentifier:PPAddressFormFieldCity];
        [self pp_showValidationErrorForIdentifier:PPAddressFormFieldCity
                                         subtitle:kLang(@"TapToSelect") ?: @"Select a city"];
        return NO;
    }
    if (self.selectedState.stateID <= 0) {
        [self.geographyFormView setErrorText:kLang(@"TapToSelect") ?: @"Select an area"
                             forIdentifier:PPAddressFormFieldState];
        [self pp_showValidationErrorForIdentifier:PPAddressFormFieldState
                                         subtitle:kLang(@"TapToSelect") ?: @"Select an area"];
        return NO;
    }
    if (self.draftPostalCode.length == 0) {
        [self pp_showValidationErrorForIdentifier:PPAddressFormFieldPostalCode
                                         subtitle:kLang(@"PostalCodePlaceholder") ?: @"Postal code is required"];
        return NO;
    }
    return YES;
}

- (void)animateFormRow:(PPFormFieldRowView *)row
{
    if (!row || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    CAKeyframeAnimation *animation = [CAKeyframeAnimation animation];
    animation.keyPath = @"position.x";
    animation.values = @[@0, @20, @-20, @10, @0];
    animation.keyTimes = @[@0, @(1 / 6.0), @(3 / 6.0), @(5 / 6.0), @1];
    animation.duration = 0.3;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    animation.additive = YES;
    [row.layer addAnimation:animation forKey:@"shake"];
}

- (void)pp_showValidationErrorForIdentifier:(NSString *)identifier subtitle:(NSString *)subtitle
{
    PPFormEngineView *form = [self pp_formViewForFieldIdentifier:identifier];
    PPFormFieldRowView *row = [form rowForIdentifier:identifier];
    if (form && row) {
        if (subtitle.length > 0) {
            [form setErrorText:subtitle forIdentifier:identifier];
        }
        [self pp_focusFieldIdentifier:identifier];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self animateFormRow:row];
        });
    }
    NSString *message = subtitle.length > 0 ? subtitle : (kLang(@"PleaseFillFields") ?: @"Please fill the required fields");
    [PPHUD showInfo:message];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, message);
}

- (void)pp_setSavingState:(BOOL)isSaving
{
    self.isSaving = isSaving;
    self.saveBarButtonItem.enabled = !isSaving;
    self.leadingBarButtonItem.enabled = !isSaving;
    self.formScrollView.userInteractionEnabled = !isSaving;
    self.defaultSwitch.enabled = !isSaving;
    self.deleteButton.enabled = !isSaving;
}

- (void)pp_closeAfterPersistence
{
    if (self.addressFormPresent == AddressFormPresentSheet) {
        if (self.navigationController.presentingViewController) {
            [self.navigationController dismissViewControllerAnimated:YES completion:nil];
        } else {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
        return;
    }

    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else if (self.navigationController.presentingViewController) {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)saveButtonPressed:(id)sender
{
    if (self.isSaving) {
        return;
    }

    [self.view endEditing:YES];

    if (![self pp_validateAddressForm]) {
        return;
    }

    NSString *fullName = [self pp_trimmedString:self.draftFullName];
    NSString *phoneNumber = [self pp_trimmedString:self.draftPhoneNumber];
    NSString *addressLine1 = [self pp_trimmedString:self.draftAddressLine1];
    NSString *addressLine2 = [self pp_trimmedString:self.draftAddressLine2];
    NSString *postalCode = [self pp_trimmedString:self.draftPostalCode];

    [self pp_setSavingState:YES];
    [PPHUD showLoading:kLang(@"Saving") ?: @"Saving"];
    self.activeSaveToken += 1;
    NSUInteger saveToken = self.activeSaveToken;

    BOOL isNewAddress = self.address == nil;
    PPAddressModel *addressToSave = self.address ?: [[PPAddressModel alloc] init];
    NSString *fallbackPhone = PPCurrentUser.MobileNo.length > 0
        ? PPCurrentUser.MobileNo
        : ([FIRAuth auth].currentUser.phoneNumber ?: @"");

    addressToSave.fullName = fullName;
    addressToSave.phoneNumber = phoneNumber.length > 0 ? phoneNumber : fallbackPhone;
    addressToSave.addressLine1 = addressLine1;
    addressToSave.addressLine2 = addressLine2.length > 0 ? addressLine2 : nil;
    addressToSave.cityID = self.selectedCity.cityID;
    addressToSave.stateID = self.selectedState.stateID;
    addressToSave.locatioName = self.selectedLocationName ?: @"";
    addressToSave.locationPoints = self.selectedLocationPoints ?: @"";
    addressToSave.postalCode = postalCode;
    addressToSave.isDefault = self.draftIsDefault;

    NSString *currentUID = [PPAddressesManager.sharedManager currentAuthenticatedUserID];
    if (currentUID.length > 0) {
        addressToSave.userID = currentUID;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.isSaving || self.activeSaveToken != saveToken) {
            return;
        }

        self.activeSaveToken += 1;
        [self pp_setSavingState:NO];
        [PPHUD dismiss];
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"StatusSaveFailed") ?: @"Save failed"
                          subtitle:kLang(@"save_timeout_message") ?: @"Saving is taking too long. Please check your connection and try again."];
    });

    void (^handleResult)(PPAddressModel * _Nullable, NSError * _Nullable) =
    ^(PPAddressModel * _Nullable savedAddress, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            if (self.activeSaveToken != saveToken) {
                return;
            }

            [self pp_setSavingState:NO];
            [PPHUD dismiss];

            if (error || !savedAddress) {
                [PPAlertHelper showErrorIn:self
                                     title:kLang(@"StatusSaveFailed") ?: @"Save failed"
                                  subtitle:error.localizedDescription ?: (kLang(@"SomethingWentWrong") ?: @"Something went wrong")];
                return;
            }

            if ([self.delegate respondsToSelector:@selector(addressFormVC:didSaveAddress:)]) {
                [self.delegate addressFormVC:self didSaveAddress:savedAddress];
            }

            [PPHUD showSuccess:kLang(@"Saved") ?: @"Saved"];
            [self pp_closeAfterPersistence];
        });
    };

    if (isNewAddress) {
        [[PPAddressesManager sharedManager] addAddress:addressToSave completion:handleResult];
    } else {
        [[PPAddressesManager sharedManager] updateAddress:addressToSave completion:handleResult];
    }
}

- (void)showDeleteConfirmation
{
    if (!self.address || self.address.documentID.length == 0) {
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"DeleteAddress") ?: @"Delete address"
                                                                   message:kLang(@"DeleteConfirmMessage") ?: @"Are you sure you want to delete this address?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel") ?: @"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Delete") ?: @"Delete"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(__unused UIAlertAction *action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        [self pp_setSavingState:YES];
        [PPHUD showLoading];
        [[PPAddressesManager sharedManager] deleteAddress:self.address completion:^(BOOL success, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self pp_setSavingState:NO];
                [PPHUD dismiss];
                if (!success || error) {
                    [PPAlertHelper showErrorIn:self
                                         title:kLang(@"DeleteFailed") ?: @"Delete failed"
                                      subtitle:error.localizedDescription ?: (kLang(@"SomethingWentWrong") ?: @"Something went wrong")];
                    return;
                }

                if ([self.delegate respondsToSelector:@selector(addressFormVC:didDeleteAddress:)]) {
                    [self.delegate addressFormVC:self didDeleteAddress:self.address];
                }

                [PPHUD showSuccess:kLang(@"AddressesDeleted") ?: @"Deleted"];
                [self pp_closeAfterPersistence];
            });
        }];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Location

- (void)pp_startPrefillFromCurrentLocationIfNeeded
{
    if (self.address || self.didApplyInitialLocation) {
        return;
    }

    if (!self.locationManager) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    }

    CLAuthorizationStatus status;
    if (@available(iOS 14.0, *)) {
        status = self.locationManager.authorizationStatus;
    } else {
        status = [CLLocationManager authorizationStatus];
    }

    if (status == kCLAuthorizationStatusNotDetermined) {
        [self.locationManager requestWhenInUseAuthorization];
        return;
    }
    if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
        [self pp_applyResolvedCountryDefaultsIfNeeded];
        [self pp_showLocationPermissionDeniedAlertIfNeeded];
        return;
    }

    CLLocation *cachedLocation = self.locationManager.location;
    if (cachedLocation && [self pp_isValidCoordinate:cachedLocation.coordinate]) {
        [self pp_applyCoordinateToForm:cachedLocation.coordinate suggestedTitle:nil];
        [self pp_reverseGeocodeCoordinateForRowTitle:cachedLocation.coordinate];
        return;
    }

    [self.locationManager startUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    CLLocation *location = locations.lastObject;
    if (!location || ![self pp_isValidCoordinate:location.coordinate]) {
        return;
    }

    [manager stopUpdatingLocation];
    [self pp_applyCoordinateToForm:location.coordinate suggestedTitle:nil];
    [self pp_reverseGeocodeCoordinateForRowTitle:location.coordinate];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    [manager stopUpdatingLocation];
    NSLog(@"[AddressFormVC] Current location failed: %@", error.localizedDescription ?: @"Unknown error");
    [self pp_applyResolvedCountryDefaultsIfNeeded];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [manager startUpdatingLocation];
    } else if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
        [self pp_applyResolvedCountryDefaultsIfNeeded];
        [self pp_showLocationPermissionDeniedAlertIfNeeded];
    }
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager API_AVAILABLE(ios(14.0))
{
    CLAuthorizationStatus status = manager.authorizationStatus;
    if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [manager startUpdatingLocation];
    } else if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
        [self pp_applyResolvedCountryDefaultsIfNeeded];
        [self pp_showLocationPermissionDeniedAlertIfNeeded];
    }
}

#pragma mark - Permission

- (void)pp_showLocationPermissionDeniedAlertIfNeeded
{
    if (self.didShowLocationPermissionAlert) {
        return;
    }
    self.didShowLocationPermissionAlert = YES;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"pp_perm_location_title")
                                                                   message:kLang(@"pp_perm_location_denied_message")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"pp_perm_open_settings")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
        if ([[UIApplication sharedApplication] canOpenURL:settingsURL]) {
            [[UIApplication sharedApplication] openURL:settingsURL options:@{} completionHandler:nil];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"pp_perm_not_now")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Trait Collection

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];

    if (![self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        return;
    }

    [self pp_applyCanvasBackground];

    [self.headerCardView pp_setBorderColor:[self pp_surfaceBorderColor]];

    for (PPFormEngineView *form in @[
        self.recipientFormView ?: [NSNull null],
        self.streetFormView ?: [NSNull null],
        self.geographyFormView ?: [NSNull null]
    ]) {
        if (![form isKindOfClass:PPFormEngineView.class]) {
            continue;
        }
        form.style = [self pp_addressFormStyle];
        for (PPFormFieldRowView *row in form.rowsByIdentifier.allValues) {
            row.titleLabel.textColor = form.style.primaryTextColor;
            row.titleLabel.font = form.style.titleFont;
        }
    }
}

#pragma mark - Country Code

- (void)pp_parsePhoneNumber:(NSString *)fullPhone
{
    NSString *trimmed = [self pp_trimmedString:fullPhone];
    self.draftPhoneDigits = @"";
    self.currentPhoneCode = @"+974";
    self.autoDetectedCountry = nil;

    if (trimmed.length == 0 || ![trimmed hasPrefix:@"+"]) {
        CountryModel *modelCountry = self.selectedCountry ?: [self pp_countryFromPhoneNumber:PPCurrentUser.MobileNo];
        if (modelCountry) {
            NSString *rawCode = [self pp_trimmedString:modelCountry.countryCode];
            if (rawCode.length > 0) {
                self.currentPhoneCode = [rawCode hasPrefix:@"+"] ? rawCode : [@"+" stringByAppendingString:rawCode];
                self.draftPhoneDigits = trimmed;
                return;
            }
        }
        self.draftPhoneDigits = trimmed;
        return;
    }

    CountryModel *matchedCountry = [self pp_countryFromPhoneNumber:trimmed];
    if (matchedCountry) {
        NSString *rawCode = [self pp_trimmedString:matchedCountry.countryCode];
        NSString *dialCode = rawCode.length > 0
            ? ([rawCode hasPrefix:@"+"] ? rawCode : [@"+" stringByAppendingString:rawCode])
            : @"+974";
        self.currentPhoneCode = dialCode;
        self.draftPhoneDigits = [trimmed substringFromIndex:dialCode.length];
        [self pp_matchCountryCodeModel:self.currentPhoneCode];
    } else {
        self.draftPhoneDigits = trimmed;
    }
}

- (void)pp_matchCountryCodeModel:(NSString *)phoneCode
{
    NSArray<CountryCodeModel *> *countries = [GM getMiddleEastCountriesForLanguage:[Language currentLanguageCode]];
    for (CountryCodeModel *code in countries) {
        if ([code.phoneCode isEqualToString:phoneCode]) {
            self.autoDetectedCountry = code;
            return;
        }
    }
}

- (void)pp_showAddressCountryCodePicker
{
    [self pp_presentPhoneCodeOptions];
}

- (void)pp_phoneFieldChanged:(UITextField *)textField
{
    NSString *raw = textField.text ?: @"";
    NSCharacterSet *digitsSet = [NSCharacterSet decimalDigitCharacterSet];
    NSMutableString *digits = [NSMutableString string];
    for (NSUInteger i = 0; i < raw.length; i++) {
        unichar ch = [raw characterAtIndex:i];
        if ([digitsSet characterIsMember:ch]) {
            [digits appendFormat:@"%C", ch];
        }
    }
    if (![textField.text isEqualToString:digits]) {
        textField.text = digits;
    }
    self.draftPhoneDigits = digits;
    self.draftPhoneNumber = [NSString stringWithFormat:@"%@%@", self.currentPhoneCode ?: @"+974", digits];
}

@end
