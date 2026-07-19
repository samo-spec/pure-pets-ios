//
//  NewCardForm.m
//  Pure Pets
//
//  Created by IQRQA on 12/14/16.
//  Rewritten: Modern UITableView form with AddNewAd card-style cells.
//

#import "NewCardForm.h"
#import "AppDelegate.h"
#import "PPCommerceFeedbackManager.h"
#import "PPSelectOptionViewController.h"
#import "PPModrenSegmrnted.h"
#import <Pure_Pets-Swift.h>

// =============================================================================
#pragma mark - Design Tokens
// =============================================================================

static NSString * const PPCardTextFieldCellID  = @"PPCardTextFieldCell";
static NSString * const PPCardSelectorCellID   = @"PPCardSelectorCell";
static NSString * const PPCardSwitchCellID     = @"PPCardSwitchCell";
static NSString * const PPCardTextViewCellID   = @"PPCardTextViewCell";
static NSString * const PPCardSegmentedCellID  = @"PPCardSegmentedCell";
static NSString * const PPCardImageCellID      = @"PPCardImageCell";

static const CGFloat kPPCardCellHorizontalInset = 20.0;
static const CGFloat kPPCardCellVerticalInset   = 10.0;

static NSString *const kNewCardDraftDefaultsPrefix   = @"pp.new_card_form.draft";
static NSString *const kNewCardDraftFormDataKey       = @"formData";
static NSString *const kNewCardDraftGalleryPathsKey   = @"galleryImagePaths";
static NSString *const kNewCardDraftDNAPathKey        = @"dnaImagePath";

static inline UIColor *PPCardFormAccentColor(void) {
    return AppPrimaryClr ?: UIColor.systemOrangeColor;
}
static inline UIColor *PPCardFormPrimaryTextColor(void) {
    return AppPrimaryTextClr ?: UIColor.labelColor;
}
static inline UIColor *PPCardFormSurfaceColor(void) {
    return [AppBackgroundClrLigter colorWithAlphaComponent:0.88];
}
static inline UIColor *PPCardFormBorderColor(void) {
    return [UIColor colorWithRed:0.25 green:0.17 blue:0.18 alpha:0.08];
}
static inline UIColor *PPCardFormCanvasColor(void) {
    return [UIColor colorWithRed:0.969 green:0.961 blue:0.949 alpha:1.0];
}
static inline UISemanticContentAttribute PPCardCurrentSemanticAttribute(void) {
    return Language.isRTL
        ? UISemanticContentAttributeForceRightToLeft
        : UISemanticContentAttributeForceLeftToRight;
}
static inline NSTextAlignment PPCardCurrentTextAlignment(void) {
    return Language.alignmentForCurrentLanguage;
}
static inline NSString *PPCardForwardSymbolName(void) {
    return Language.isRTL ? @"arrow.left" : @"arrow.right";
}

// =============================================================================
#pragma mark - PPCardBaseCell
// =============================================================================

@interface PPCardBaseCell : UITableViewCell
- (void)applyDisabledState:(BOOL)disabled;
@end

@implementation PPCardBaseCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.clipsToBounds = NO;
        self.contentView.clipsToBounds = NO;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.semanticContentAttribute = PPCardCurrentSemanticAttribute();
        self.contentView.semanticContentAttribute = PPCardCurrentSemanticAttribute();
    }
    return self;
}

- (void)setFrame:(CGRect)frame {
    frame.origin.x = kPPCardCellHorizontalInset;
    frame.size.width -= kPPCardCellHorizontalInset * 2.0;
    frame.origin.y += kPPCardCellVerticalInset * 0.5;
    frame.size.height -= kPPCardCellVerticalInset;
    if (frame.size.width  < 0.0) frame.size.width  = 0.0;
    if (frame.size.height < 0.0) frame.size.height = 0.0;
    [super setFrame:frame];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    // Keep shadowPath in sync with the content view's rounded rect to prevent jumping
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:self.contentView.frame cornerRadius:20.0];
    self.layer.shadowPath = path.CGPath;
}

- (void)applyDisabledState:(BOOL)disabled {
    self.contentView.alpha = disabled ? 0.58 : 1.0;
}

@end

// =============================================================================
#pragma mark - PPCardFormField
// =============================================================================

typedef NS_ENUM(NSInteger, PPCardFieldType) {
    PPCardFieldTypeText,
    PPCardFieldTypeInteger,
    PPCardFieldTypeSelector,
    PPCardFieldTypeSwitch,
    PPCardFieldTypeTextView,
    PPCardFieldTypeSegmented,
    PPCardFieldTypeImage
};

@interface PPCardFormField : NSObject
@property (nonatomic, copy)   NSString *tag;
@property (nonatomic, copy)   NSString *title;
@property (nonatomic, copy)   NSString *placeholder;
@property (nonatomic, strong) id value;
@property (nonatomic, assign) PPCardFieldType fieldType;
@property (nonatomic, assign) BOOL required;
@property (nonatomic, assign) BOOL disabled;
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, strong) NSArray *selectorOptions;
@property (nonatomic, copy)   NSString *selectorTitle;
@property (nonatomic, copy)   void(^onChangeBlock)(id oldValue, id newValue);
@end

@implementation PPCardFormField
- (instancetype)init {
    self = [super init];
    if (self) { _height = 56.0; _required = NO; _disabled = NO; }
    return self;
}
@end

// =============================================================================
#pragma mark - PPCardTextFieldCell
// =============================================================================

@interface PPCardTextFieldCell : PPCardBaseCell <UITextFieldDelegate>
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, copy) void(^onValueChanged)(NSString *text);
@end

@implementation PPCardTextFieldCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        _titleLabel.textColor = PPCardFormPrimaryTextColor();
        _titleLabel.textAlignment = PPCardCurrentTextAlignment();
        [self.contentView addSubview:_titleLabel];

        _textField = [[UITextField alloc] init];
        _textField.translatesAutoresizingMaskIntoConstraints = NO;
        _textField.font = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
        _textField.textColor = PPCardFormPrimaryTextColor();
        _textField.textAlignment = PPCardCurrentTextAlignment();
        _textField.semanticContentAttribute = PPCardCurrentSemanticAttribute();
        _textField.backgroundColor = UIColor.clearColor;
        _textField.delegate = self;
        _textField.returnKeyType = UIReturnKeyDone;
        _textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        [_textField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        [self.contentView addSubview:_textField];

        [NSLayoutConstraint activateConstraints:@[
            [_titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10.0],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
            [_titleLabel.heightAnchor constraintGreaterThanOrEqualToConstant:12.0],
            [_textField.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:8.0],
            [_textField.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_textField.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
            [_textField.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10.0],
            [_textField.heightAnchor constraintGreaterThanOrEqualToConstant:24.0]
        ]];
    }
    return self;
}

- (void)configureWithField:(PPCardFormField *)field {
    self.semanticContentAttribute = PPCardCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPCardCurrentSemanticAttribute();
    self.titleLabel.text = field.title;
    self.titleLabel.textAlignment = PPCardCurrentTextAlignment();
    self.textField.textAlignment = PPCardCurrentTextAlignment();
    self.textField.semanticContentAttribute = PPCardCurrentSemanticAttribute();
    UIColor *placeholderColor = [UIColor.placeholderTextColor colorWithAlphaComponent:0.75];
    self.textField.attributedPlaceholder = field.placeholder.length
        ? [[NSAttributedString alloc] initWithString:field.placeholder
                                          attributes:@{NSForegroundColorAttributeName: placeholderColor}]
        : nil;
    self.textField.enabled = !field.disabled;
    if (field.fieldType == PPCardFieldTypeInteger) {
        self.textField.keyboardType = UIKeyboardTypeNumberPad;
        self.textField.text = field.value ? [NSString stringWithFormat:@"%@", field.value] : @"";
    } else {
        self.textField.keyboardType = UIKeyboardTypeDefault;
        self.textField.text = [field.value isKindOfClass:NSString.class] ? field.value : @"";
    }
    self.textField.textColor = (self.textField.text.length > 0) ? PPCardFormAccentColor() : PPCardFormPrimaryTextColor();
    [self applyDisabledState:field.disabled];
}

- (void)textFieldDidChange:(UITextField *)textField {
    textField.textColor = (textField.text.length > 0) ? PPCardFormAccentColor() : PPCardFormPrimaryTextColor();
    if (self.onValueChanged) self.onValueChanged(textField.text);
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}
@end

// =============================================================================
#pragma mark - PPCardSelectorCell
// =============================================================================

@interface PPCardSelectorCell : PPCardBaseCell
@property (nonatomic, strong) UILabel *fieldTitleLabel;
@property (nonatomic, strong) UILabel *valueLabel;
@property (nonatomic, strong) UIImageView *chevronView;
@end

@implementation PPCardSelectorCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _fieldTitleLabel = [[UILabel alloc] init];
        _fieldTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _fieldTitleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        _fieldTitleLabel.textColor = PPCardFormPrimaryTextColor();
        _fieldTitleLabel.textAlignment = PPCardCurrentTextAlignment();
        [self.contentView addSubview:_fieldTitleLabel];

        _valueLabel = [[UILabel alloc] init];
        _valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _valueLabel.font = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
        _valueLabel.textColor = PPCardFormPrimaryTextColor();
        _valueLabel.textAlignment = PPCardCurrentTextAlignment();
        [self.contentView addSubview:_valueLabel];

        _chevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:PPCardForwardSymbolName()]];
        _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
        _chevronView.tintColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.62];
        _chevronView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_chevronView];

        [_fieldTitleLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
        [_valueLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        [_valueLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

        [NSLayoutConstraint activateConstraints:@[
            [_fieldTitleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14.0],
            [_fieldTitleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
            [_fieldTitleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
            [_fieldTitleLabel.heightAnchor constraintGreaterThanOrEqualToConstant:12.0],
            [_chevronView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:10.0],
            [_chevronView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
            [_chevronView.widthAnchor constraintEqualToConstant:14.0],
            [_chevronView.heightAnchor constraintEqualToConstant:14.0],
            [_valueLabel.leadingAnchor constraintEqualToAnchor:_fieldTitleLabel.leadingAnchor],
            [_valueLabel.topAnchor constraintEqualToAnchor:_fieldTitleLabel.bottomAnchor constant:8.0],
            [_valueLabel.trailingAnchor constraintEqualToAnchor:_chevronView.leadingAnchor constant:-12.0],
            [_valueLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0]
        ]];
    }
    return self;
}

- (void)configureWithField:(PPCardFormField *)field {
    self.semanticContentAttribute = PPCardCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPCardCurrentSemanticAttribute();
    self.fieldTitleLabel.text = field.title;
    self.fieldTitleLabel.textAlignment = PPCardCurrentTextAlignment();
    self.valueLabel.textAlignment = PPCardCurrentTextAlignment();
    self.chevronView.image = [UIImage systemImageNamed:PPCardForwardSymbolName()];
    NSString *displayValue = nil;
    if (field.value) {
        if ([field.value isKindOfClass:NSString.class]) {
            displayValue = (NSString *)field.value;
        } else if ([field.value respondsToSelector:@selector(formDisplayText)]) {
            displayValue = [field.value performSelector:@selector(formDisplayText)];
        } else {
            displayValue = [NSString stringWithFormat:@"%@", field.value];
        }
    }
    if (displayValue.length > 0) {
        self.valueLabel.text = displayValue;
        self.valueLabel.textColor = PPCardFormAccentColor();
    } else {
        self.valueLabel.text = field.placeholder ?: field.selectorTitle;
        self.valueLabel.textColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.68];
    }
    self.userInteractionEnabled = !field.disabled;
    [self applyDisabledState:field.disabled];
}
@end

// =============================================================================
#pragma mark - PPCardTextViewCell
// =============================================================================

@interface PPCardTextViewCell : PPCardBaseCell <UITextViewDelegate>
@property (nonatomic, strong) UILabel *fieldTitleLabel;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (nonatomic, copy) void(^onTextChanged)(NSString *text);
@end

@implementation PPCardTextViewCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _fieldTitleLabel = [[UILabel alloc] init];
        _fieldTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _fieldTitleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        _fieldTitleLabel.textColor = PPCardFormPrimaryTextColor();
        _fieldTitleLabel.textAlignment = PPCardCurrentTextAlignment();
        [self.contentView addSubview:_fieldTitleLabel];

        _textView = [[UITextView alloc] init];
        _textView.translatesAutoresizingMaskIntoConstraints = NO;
        _textView.font = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
        _textView.textColor = PPCardFormPrimaryTextColor();
        _textView.backgroundColor = UIColor.clearColor;
        _textView.textAlignment = PPCardCurrentTextAlignment();
        _textView.semanticContentAttribute = PPCardCurrentSemanticAttribute();
        _textView.textContainerInset = UIEdgeInsetsZero;
        _textView.textContainer.lineFragmentPadding = 0.0;
        _textView.delegate = self;
        _textView.scrollEnabled = NO;
        [self.contentView addSubview:_textView];

        _placeholderLabel = [[UILabel alloc] init];
        _placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _placeholderLabel.font = _textView.font;
        _placeholderLabel.textColor = [UIColor.placeholderTextColor colorWithAlphaComponent:0.72];
        _placeholderLabel.textAlignment = PPCardCurrentTextAlignment();
        [_textView addSubview:_placeholderLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_fieldTitleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14.0],
            [_fieldTitleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
            [_fieldTitleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
            [_fieldTitleLabel.heightAnchor constraintGreaterThanOrEqualToConstant:12.0],
            [_textView.topAnchor constraintEqualToAnchor:_fieldTitleLabel.bottomAnchor constant:8.0],
            [_textView.leadingAnchor constraintEqualToAnchor:_fieldTitleLabel.leadingAnchor],
            [_textView.trailingAnchor constraintEqualToAnchor:_fieldTitleLabel.trailingAnchor],
            [_textView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0],
            [_textView.heightAnchor constraintGreaterThanOrEqualToConstant:116.0],
            [_placeholderLabel.topAnchor constraintEqualToAnchor:_textView.topAnchor],
            [_placeholderLabel.leadingAnchor constraintEqualToAnchor:_textView.leadingAnchor constant:2.0],
            [_placeholderLabel.trailingAnchor constraintEqualToAnchor:_textView.trailingAnchor]
        ]];
    }
    return self;
}

- (void)configureWithField:(PPCardFormField *)field {
    self.semanticContentAttribute = PPCardCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPCardCurrentSemanticAttribute();
    self.fieldTitleLabel.text = field.title ?: kLang(@"enter_description");
    self.fieldTitleLabel.textAlignment = PPCardCurrentTextAlignment();
    self.textView.textAlignment = PPCardCurrentTextAlignment();
    self.textView.semanticContentAttribute = PPCardCurrentSemanticAttribute();
    self.textView.text = [field.value isKindOfClass:NSString.class] ? field.value : @"";
    self.placeholderLabel.text = field.placeholder;
    self.placeholderLabel.textAlignment = PPCardCurrentTextAlignment();
    self.placeholderLabel.hidden = (self.textView.text.length > 0);
    self.textView.editable = !field.disabled;
    [self applyDisabledState:field.disabled];
}

- (void)textViewDidChange:(UITextView *)textView {
    self.placeholderLabel.hidden = (textView.text.length > 0);
    if (self.onTextChanged) self.onTextChanged(textView.text);
}
@end

// =============================================================================
#pragma mark - PPCardSwitchCell
// =============================================================================

@interface PPCardSwitchCell : PPCardBaseCell
@property (nonatomic, strong) UILabel *fieldTitleLabel;
@property (nonatomic, strong) UISwitch *toggleSwitch;
@property (nonatomic, copy) void(^onSwitchChanged)(BOOL isOn);
@end

@implementation PPCardSwitchCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _fieldTitleLabel = [[UILabel alloc] init];
        _fieldTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _fieldTitleLabel.font = [GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
        _fieldTitleLabel.textColor = PPCardFormPrimaryTextColor();
        _fieldTitleLabel.textAlignment = PPCardCurrentTextAlignment();
        [self.contentView addSubview:_fieldTitleLabel];

        _toggleSwitch = [[UISwitch alloc] init];
        _toggleSwitch.translatesAutoresizingMaskIntoConstraints = NO;
        _toggleSwitch.onTintColor = PPCardFormAccentColor();
        [_toggleSwitch addTarget:self action:@selector(switchDidChange:) forControlEvents:UIControlEventValueChanged];
        [self.contentView addSubview:_toggleSwitch];

        [NSLayoutConstraint activateConstraints:@[
            [_fieldTitleLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_fieldTitleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
            [_toggleSwitch.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_toggleSwitch.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
            [_fieldTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_toggleSwitch.leadingAnchor constant:-12.0],
            [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:56.0]
        ]];
    }
    return self;
}

- (void)configureWithField:(PPCardFormField *)field {
    self.semanticContentAttribute = PPCardCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPCardCurrentSemanticAttribute();
    self.fieldTitleLabel.text = field.title;
    self.fieldTitleLabel.textAlignment = PPCardCurrentTextAlignment();
    BOOL isOn = NO;
    if ([field.value respondsToSelector:@selector(boolValue)]) {
        isOn = [field.value boolValue];
    }
    [self.toggleSwitch setOn:isOn animated:NO];
    self.userInteractionEnabled = !field.disabled;
    [self applyDisabledState:field.disabled];
}

- (void)switchDidChange:(UISwitch *)sender {
    if (self.onSwitchChanged) self.onSwitchChanged(sender.isOn);
}
@end

// =============================================================================
#pragma mark - PPCardSegmentedCell
// =============================================================================

@interface PPCardSegmentedCell : PPCardBaseCell
@property (nonatomic, strong) UILabel *fieldTitleLabel;
@property (nonatomic, strong) ModernSegmentedControlBridge *segmentedControl;
@property (nonatomic, copy) void(^onSegmentChanged)(NSInteger selectedIndex);
@end

@implementation PPCardSegmentedCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _fieldTitleLabel = [[UILabel alloc] init];
        _fieldTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _fieldTitleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        _fieldTitleLabel.textColor = PPCardFormPrimaryTextColor();
        _fieldTitleLabel.textAlignment = PPCardCurrentTextAlignment();
        [self.contentView addSubview:_fieldTitleLabel];

        PPModrenSegmrntedItem *femaleItem = [PPModrenSegmrntedItem itemWithTitle:kLang(@"Female") iconName:nil selectedIconName:nil];
        PPModrenSegmrntedItem *maleItem   = [PPModrenSegmrntedItem itemWithTitle:kLang(@"Male") iconName:nil selectedIconName:nil];
        _segmentedControl = [[ModernSegmentedControlBridge alloc] initWithItems:@[femaleItem, maleItem]];
        _segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
        _segmentedControl.selectedIndex = -1;
        _segmentedControl.selectedSegmentColor = PPCardFormAccentColor();
        _segmentedControl.selectedTextColor = UIColor.whiteColor;
        _segmentedControl.normalTextColor = PPCardFormPrimaryTextColor();
        _segmentedControl.normalFont = [GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
        _segmentedControl.selectedFont = [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightBold];
        [_segmentedControl addTarget:self action:@selector(segmentDidChange:) forControlEvents:UIControlEventValueChanged];
        [self.contentView addSubview:_segmentedControl];

        [NSLayoutConstraint activateConstraints:@[
            [_fieldTitleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10.0],
            [_fieldTitleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
            [_fieldTitleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
            [_segmentedControl.topAnchor constraintEqualToAnchor:_fieldTitleLabel.bottomAnchor constant:8.0],
            [_segmentedControl.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
            [_segmentedControl.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],
            [_segmentedControl.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10.0],
            [_segmentedControl.heightAnchor constraintEqualToConstant:44.0],
            [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:80.0]
        ]];
    }
    return self;
}

- (void)configureWithField:(PPCardFormField *)field {
    self.semanticContentAttribute = PPCardCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPCardCurrentSemanticAttribute();
    self.fieldTitleLabel.text = field.title;
    self.fieldTitleLabel.textAlignment = PPCardCurrentTextAlignment();
    if ([field.value respondsToSelector:@selector(integerValue)]) {
        NSInteger sexual = [field.value integerValue];
        if (sexual == 1) [self.segmentedControl setSelectedIndex:1 animated:NO];
        else if (sexual == 2) [self.segmentedControl setSelectedIndex:0 animated:NO];
        else self.segmentedControl.selectedIndex = -1;
    }
    [self applyDisabledState:field.disabled];
}

- (void)segmentDidChange:(ModernSegmentedControlBridge *)sender {
    if (self.onSegmentChanged) self.onSegmentChanged(sender.selectedIndex);
}
@end

// =============================================================================
#pragma mark - PPCardImageCell
// =============================================================================

@interface PPCardImageCell : PPCardBaseCell
@property (nonatomic, strong) UILabel *fieldTitleLabel;
@property (nonatomic, strong) UIImageView *thumbImageView;
@property (nonatomic, strong) UIImageView *chevronView;
@end

@implementation PPCardImageCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _fieldTitleLabel = [[UILabel alloc] init];
        _fieldTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _fieldTitleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        _fieldTitleLabel.textColor = PPCardFormPrimaryTextColor();
        _fieldTitleLabel.textAlignment = PPCardCurrentTextAlignment();
        [self.contentView addSubview:_fieldTitleLabel];

        _thumbImageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"plus.circle.fill"]];
        _thumbImageView.translatesAutoresizingMaskIntoConstraints = NO;
        _thumbImageView.tintColor = PPCardFormAccentColor();
        _thumbImageView.contentMode = UIViewContentModeScaleAspectFill;
        _thumbImageView.clipsToBounds = YES;
        _thumbImageView.layer.cornerRadius = 8.0;
        [self.contentView addSubview:_thumbImageView];

        _chevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:PPCardForwardSymbolName()]];
        _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
        _chevronView.tintColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.62];
        _chevronView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_chevronView];

        [NSLayoutConstraint activateConstraints:@[
            [_fieldTitleLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_fieldTitleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
            [_thumbImageView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_thumbImageView.trailingAnchor constraintEqualToAnchor:_chevronView.leadingAnchor constant:-8.0],
            [_thumbImageView.widthAnchor constraintEqualToConstant:40.0],
            [_thumbImageView.heightAnchor constraintEqualToConstant:40.0],
            [_chevronView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_chevronView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
            [_chevronView.widthAnchor constraintEqualToConstant:14.0],
            [_chevronView.heightAnchor constraintEqualToConstant:14.0],
            [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:60.0]
        ]];
    }
    return self;
}

- (void)configureWithField:(PPCardFormField *)field {
    self.semanticContentAttribute = PPCardCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPCardCurrentSemanticAttribute();
    self.fieldTitleLabel.text = field.title;
    self.fieldTitleLabel.textAlignment = PPCardCurrentTextAlignment();
    self.chevronView.image = [UIImage systemImageNamed:PPCardForwardSymbolName()];
    if ([field.value isKindOfClass:UIImage.class]) {
        self.thumbImageView.image = (UIImage *)field.value;
        self.thumbImageView.contentMode = UIViewContentModeScaleAspectFill;
    } else {
        self.thumbImageView.image = [UIImage systemImageNamed:@"plus.circle.fill"];
        self.thumbImageView.tintColor = PPCardFormAccentColor();
        self.thumbImageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    [self applyDisabledState:field.disabled];
}
@end

// =============================================================================
#pragma mark - MY_Media (backwards compat)
// =============================================================================

@interface MY_Media : NSObject
@property (nonatomic) FileType fileType;
@property (nonatomic) NSString *FileName;
@property (nonatomic) UIImage *imageFile;
@property (nonatomic) NSString *FileUrl;
@end

@implementation MY_Media
@end

// =============================================================================
#pragma mark - PPParrotColorSuggestionsView
// =============================================================================

/// Modern horizontal scrolling color chip suggestions for the bird color input.
/// Shows popular parrot color names as tappable capsules with a small color swatch.
@interface PPParrotColorSuggestionsView : UIView
@property (nonatomic, copy) void(^onColorSelected)(NSString *colorName);
@end

@implementation PPParrotColorSuggestionsView {
    UIScrollView *_scrollView;
}

typedef struct { const char *name; CGFloat r; CGFloat g; CGFloat b; } PPParrotColorDef;

static const PPParrotColorDef kParrotColors[] = {
    { "Green",      0.18, 0.72, 0.30 },
    { "Lutino",     0.98, 0.88, 0.22 },
    { "Blue",       0.20, 0.52, 0.88 },
    { "Albino",     0.92, 0.92, 0.92 },
    { "Yellow",     0.99, 0.82, 0.08 },
    { "Olive",      0.55, 0.60, 0.22 },
    { "Cobalt",     0.16, 0.30, 0.72 },
    { "Grey",       0.60, 0.62, 0.64 },
    { "Cinnamon",   0.72, 0.48, 0.28 },
    { "Violet",     0.52, 0.32, 0.78 },
    { "Pied",       0.45, 0.75, 0.38 },
    { "Turquoise",  0.18, 0.78, 0.76 },
    { "Mauve",      0.60, 0.48, 0.72 },
    { "White",      0.96, 0.96, 0.96 },
    { "Red",        0.88, 0.20, 0.18 },
    { "Orange",     0.95, 0.55, 0.15 },
    { "Spangle",    0.42, 0.68, 0.35 },
    { "Dark Green", 0.10, 0.50, 0.20 },
    { "Clearwing",  0.65, 0.85, 0.40 },
    { "Fallow",     0.78, 0.62, 0.42 },
};
static const NSUInteger kParrotColorsCount = sizeof(kParrotColors) / sizeof(kParrotColors[0]);

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, 52)];
    if (self) {
        self.backgroundColor = PPCardFormCanvasColor();

        // Thin separator line at top
        UIView *sep = [[UIView alloc] init];
        sep.translatesAutoresizingMaskIntoConstraints = NO;
        sep.backgroundColor = [UIColor.separatorColor colorWithAlphaComponent:0.3];
        [self addSubview:sep];

        _scrollView = [[UIScrollView alloc] init];
        _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.alwaysBounceHorizontal = YES;
        _scrollView.contentInset = UIEdgeInsetsMake(0, 14, 0, 14);
        [self addSubview:_scrollView];

        [NSLayoutConstraint activateConstraints:@[
            [sep.topAnchor constraintEqualToAnchor:self.topAnchor],
            [sep.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [sep.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [sep.heightAnchor constraintEqualToConstant:0.5],
            [_scrollView.topAnchor constraintEqualToAnchor:sep.bottomAnchor constant:4],
            [_scrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_scrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_scrollView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-4],
        ]];

        UIView *prevChip = nil;
        for (NSUInteger i = 0; i < kParrotColorsCount; i++) {
            PPParrotColorDef def = kParrotColors[i];
            NSString *name = [NSString stringWithUTF8String:def.name];
            UIColor *swatch = [UIColor colorWithRed:def.r green:def.g blue:def.b alpha:1.0];
            UIView *chip = [self pp_buildChipWithName:name swatchColor:swatch index:i];
            chip.translatesAutoresizingMaskIntoConstraints = NO;
            [_scrollView addSubview:chip];

            [NSLayoutConstraint activateConstraints:@[
                [chip.centerYAnchor constraintEqualToAnchor:_scrollView.centerYAnchor],
                [chip.heightAnchor constraintEqualToConstant:34],
                prevChip
                    ? [chip.leadingAnchor constraintEqualToAnchor:prevChip.trailingAnchor constant:8]
                    : [chip.leadingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.leadingAnchor],
            ]];
            prevChip = chip;
        }
        if (prevChip) {
            [prevChip.trailingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.trailingAnchor].active = YES;
        }
    }
    return self;
}

- (UIView *)pp_buildChipWithName:(NSString *)name swatchColor:(UIColor *)color index:(NSUInteger)idx {
    UIView *pill = [[UIView alloc] init];
    pill.backgroundColor = [PPCardFormSurfaceColor() colorWithAlphaComponent:0.94];
    pill.layer.cornerRadius = 17;
    pill.layer.borderWidth = 1.0;
    [pill pp_setBorderColor:PPCardFormBorderColor()];
    pill.clipsToBounds = YES;
    pill.tag = (NSInteger)idx;

    UIView *dot = [[UIView alloc] init];
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    dot.backgroundColor = color;
    dot.layer.cornerRadius = 7;
    dot.clipsToBounds = YES;
    [pill addSubview:dot];

    UILabel *lbl = [[UILabel alloc] init];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.text = name;
    lbl.font = [GM MidFontWithSize:13] ?: [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    lbl.textColor = PPCardFormPrimaryTextColor();
    [pill addSubview:lbl];

    [NSLayoutConstraint activateConstraints:@[
        [dot.leadingAnchor constraintEqualToAnchor:pill.leadingAnchor constant:10],
        [dot.centerYAnchor constraintEqualToAnchor:pill.centerYAnchor],
        [dot.widthAnchor constraintEqualToConstant:14],
        [dot.heightAnchor constraintEqualToConstant:14],
        [lbl.leadingAnchor constraintEqualToAnchor:dot.trailingAnchor constant:6],
        [lbl.centerYAnchor constraintEqualToAnchor:pill.centerYAnchor],
        [lbl.trailingAnchor constraintEqualToAnchor:pill.trailingAnchor constant:-12],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_chipTapped:)];
    [pill addGestureRecognizer:tap];
    pill.userInteractionEnabled = YES;

    return pill;
}

- (void)pp_chipTapped:(UITapGestureRecognizer *)gesture {
    NSUInteger idx = (NSUInteger)gesture.view.tag;
    if (idx >= kParrotColorsCount) return;
    NSString *name = [NSString stringWithUTF8String:kParrotColors[idx].name];

    // Subtle press feedback
    UIView *chip = gesture.view;
    [UIView animateWithDuration:0.08 animations:^{
        chip.transform = CGAffineTransformMakeScale(0.93, 0.93);
        chip.alpha = 0.7;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.12 animations:^{
            chip.transform = CGAffineTransformIdentity;
            chip.alpha = 1.0;
        }];
    }];

    if (self.onColorSelected) self.onColorSelected(name);
}

@end

// =============================================================================
#pragma mark - PPCardMultiSelectViewController
// =============================================================================

@interface PPCardMultiSelectViewController : UITableViewController
@property (nonatomic, copy)   NSArray<subKindItemsModel *> *allItems;
@property (nonatomic, strong) NSMutableArray<subKindItemsModel *> *selectedItems;
@property (nonatomic, copy)   NSString *headerTitle;
@property (nonatomic, copy)   void (^onDone)(NSArray<subKindItemsModel *> *selected);
@end

@implementation PPCardMultiSelectViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.headerTitle ?: @"";
    self.view.backgroundColor = PPCardFormCanvasColor();
    self.tableView.backgroundColor = PPCardFormCanvasColor();
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.contentInset = UIEdgeInsetsMake(12, 0, 32, 0);
    if (!self.selectedItems) self.selectedItems = [NSMutableArray array];

    UIButton *saveBtn = [PPButtonHelper pp_buttonWithTitle:kLang(@"done")
                                                      font:[GM fontWithSize:17]
                                                 imageName:@""
                                                    target:self
                                                    config:[UIButtonConfiguration tintedButtonConfiguration]
                                                    action:@selector(doneTapped)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:saveBtn];
}

- (void)doneTapped {
    if (self.onDone) self.onDone([self.selectedItems copy]);
    if (self.navigationController.presentingViewController) {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    } else if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.allItems.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    subKindItemsModel *item = self.allItems[indexPath.row];
    cell.textLabel.text = [item formDisplayText];
    cell.textLabel.font = [GM MidFontWithSize:16] ?: [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    cell.textLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    cell.textLabel.textAlignment = PPCardCurrentTextAlignment();
    cell.semanticContentAttribute = PPCardCurrentSemanticAttribute();
    cell.contentView.semanticContentAttribute = PPCardCurrentSemanticAttribute();
    cell.backgroundColor = PPCardFormSurfaceColor();
    cell.contentView.backgroundColor = PPCardFormSurfaceColor();
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    BOOL isSelected = NO;
    for (subKindItemsModel *sel in self.selectedItems) {
        if (sel.ID == item.ID) { isSelected = YES; break; }
    }
    cell.accessoryType = isSelected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.tintColor = PPCardFormAccentColor();
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    cell.contentView.layer.cornerRadius = 16.0;
    cell.contentView.layer.masksToBounds = YES;
    cell.contentView.layer.borderWidth = 1.0;
    [cell.contentView pp_setBorderColor:PPCardFormBorderColor()];
    // Use consistent inset via setFrame pattern instead of fragile CGRectInset
    CGRect f = cell.frame;
    f.origin.x = 20.0;
    f.size.width -= 40.0;
    f.origin.y += 4.0;
    f.size.height -= 8.0;
    if (f.size.width > 0 && f.size.height > 0) {
        cell.frame = f;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    subKindItemsModel *item = self.allItems[indexPath.row];
    NSInteger foundIdx = NSNotFound;
    for (NSInteger i = 0; i < (NSInteger)self.selectedItems.count; i++) {
        if (self.selectedItems[i].ID == item.ID) { foundIdx = i; break; }
    }
    if (foundIdx != NSNotFound) {
        [self.selectedItems removeObjectAtIndex:foundIdx];
    } else {
        [self.selectedItems addObject:item];
    }
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}

@end

// =============================================================================
#pragma mark - NewCardForm Private Interface
// =============================================================================

@interface NewCardForm () <UITableViewDataSource, UITableViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate> {
    NSString *userID;
    NSString *SubKindPlace;
    NSString *subSubKindPlace;
    NSString *ClassificationPlace;
    float topbarHeight;
    NSInteger birdSexual;
    int AttributeNoteAdded;
    long finishFlag;
    int initFlag;
    NSString *alertTitleLoad;
    NSString *alertSubtitleLoad;
    NSString *alertTitleError;
    NSString *alertSubtitleError;
    NSInteger formFinishupload;
    NSString *_alertWarningDataTitle;
    NSString *_alertWarningDataSubTitle;
    NSString *alertAddImagesTitle;
    NSString *alertAddImagesDesc;
    NSString *alertRingIDText;
    NSString *alertSubKindIDText;
    FIRStorage *storage;
    NSMutableArray *selectedImagesNames;
}

// -- Data --
@property (assign, nonatomic) NSInteger currentAdultHood;
@property (nonatomic, strong) NSMutableDictionary *formDataArray;
@property (nonatomic, strong) UIActivityIndicatorView *uploadProgressV;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, strong) FIRStorageReference *storageRef;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) NSUserDefaults *prefs;
@property (nonatomic, strong) NSString *alertTitleDone;
@property (nonatomic, strong) NSString *alertSubtitleDone;
@property (nonatomic, strong) NSString *alertWarningDataTitle;
@property (nonatomic, strong) NSString *alertWarningDataSubTitle;

@property NSArray *SubKindsArrayList;
@property NSArray *subSubKindsArrayList;
@property NSArray *subKindItemsArrayList;
@property NSMutableArray *selectedItemsArray;
@property NSMutableArray *selectedItemsLoadedArray;

@property NSArray<SubKindModel *> *SubKindsArrayLocal;
@property NSArray<subSubKindModel *> *subSubKindsArrayLocal;
@property NSMutableArray<subKindItemsModel *> *subKindItemsArrayLocal;
@property NSMutableArray<subKindItemsModel *> *LoadedItemsMaleArrayLocal;
@property NSMutableArray<subKindItemsModel *> *LoadedItemsFemaleArrayLocal;

@property NSArray<CardModel *> *fathersCardsArray;
@property NSArray<CardModel *> *mothersCardsArray;
@property NSMutableArray<subKindItemsModel *> *ItemsloveArray;
@property NSMutableArray<subKindItemsModel *> *ItemsSexualloveArray;
@property NSMutableArray<subKindItemsModel *> *globalItemsArray;
@property NSMutableArray *attributeArrayLocat;

@property (nonatomic, strong) NSArray<CardModel *> *CardsdataSource;
@property (nonatomic, strong) NSArray<CardModel *> *allCardsArray;
@property (nonatomic, strong) UIButton *closeBtnIB;
@property (nonatomic, strong) TTGSnackbar *snakBar;
@property NSMutableArray<MainKindsModel *> *MainKindsArray;
@property (nonatomic, strong) GSIndeterminateProgressView *uploadProgressView;
@property (nonatomic, strong) NSMutableArray *imagesFromStorage;
@property (nonatomic, strong) FileUploadManager *uploadManager;
@property (nonatomic, assign) BOOL didChangeImages;
@property (nonatomic, assign) BOOL isHydratingImages;
@property (nonatomic, assign) BOOL isSaving;
@property (nonatomic, assign) BOOL isHydratingFormData;
@property (nonatomic, assign) BOOL hasUserModifiedForm;
@property SubKindModel *selectedSubKindModel;

// -- Table View --
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<NSMutableArray<PPCardFormField *> *> *formSections;

// -- Selected state --
@property (nonatomic, strong) NSDate *selectedBirthDate;
@property (nonatomic, assign) BOOL isDateSelected;
@property (nonatomic, strong) CardModel *selectedFather;
@property (nonatomic, strong) CardModel *selectedMother;

@end

// =============================================================================
#pragma mark - Implementation
// =============================================================================

@implementation NewCardForm

NSString *const RingIDValidation       = @"RingID";
NSString *const SubKindValidation      = @"SubKind";
NSString *const subSubKindValidation   = @"subSubKind";
NSString *const ClassificationValidation = @"Classification";
NSString *const attributeValidation    = @"attribute";
NSString *const BirthDateValidation    = @"BirthDate";
NSString *const SexualValidation       = @"Sexual";
NSString *const kSelectorUser          = @"selectorUser";
NSString *const kselectorParent        = @"selectorParent";
NSString *const kSelectorUserPopover   = @"kSelectorUserPopover";
NSString *const no_value               = @"no_value";

UIBarButtonItem *addbutton;

// =============================================================================
#pragma mark - AppDelegate
// =============================================================================

- (AppDelegate *)AppDelegate {
    return (AppDelegate *)[[UIApplication sharedApplication] delegate];
}

// =============================================================================
#pragma mark - Header Setup
// =============================================================================

- (void)setupHeaderViews {
    UIColor *brandColor = AppPrimaryClr ?: UIColor.systemOrangeColor;

    // Root container — same pattern as ProfileVC.tableHeaderView
    _topView = [[UIView alloc] init];
    _topView.backgroundColor = UIColor.clearColor;

    // --- Card view (frosted glass card) ---
    UIView *cardView = [[UIView alloc] init];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    cardView.backgroundColor = PPCardFormSurfaceColor();
    cardView.layer.cornerRadius = 28.0;
    cardView.layer.masksToBounds = NO;
    cardView.layer.borderWidth = 1.0;
    [cardView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.68]];
    [cardView pp_setShadowColor:UIColor.blackColor];
    cardView.layer.shadowOpacity = 0.06;
    cardView.layer.shadowRadius  = 20.0;
    cardView.layer.shadowOffset  = CGSizeMake(0, 10.0);
    [_topView addSubview:cardView];

    // Warm tint overlay
    UIView *tintView = [[UIView alloc] init];
    tintView.translatesAutoresizingMaskIntoConstraints = NO;
    tintView.backgroundColor = [[UIColor colorWithRed:0.99 green:0.96 blue:0.93 alpha:1.0] colorWithAlphaComponent:0.72];
    tintView.layer.cornerRadius = 28.0;
    tintView.layer.masksToBounds = YES;
    [cardView addSubview:tintView];

    // Ambient glow (brand-colored orb, top-right)
    UIView *ambientGlow = [[UIView alloc] init];
    ambientGlow.translatesAutoresizingMaskIntoConstraints = NO;
    ambientGlow.backgroundColor = [brandColor colorWithAlphaComponent:0.14];
    ambientGlow.userInteractionEnabled = NO;
    ambientGlow.layer.cornerRadius = 72.0;
    [ambientGlow pp_setShadowColor:[brandColor colorWithAlphaComponent:0.45]];
    ambientGlow.layer.shadowOpacity = 0.14;
    ambientGlow.layer.shadowRadius  = 36.0;
    ambientGlow.layer.shadowOffset  = CGSizeZero;
    [cardView addSubview:ambientGlow];

    // Secondary glow (white orb, bottom-left)
    UIView *secondaryGlow = [[UIView alloc] init];
    secondaryGlow.translatesAutoresizingMaskIntoConstraints = NO;
    secondaryGlow.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.38];
    secondaryGlow.userInteractionEnabled = NO;
    secondaryGlow.layer.cornerRadius = 46.0;
    [secondaryGlow pp_setShadowColor:[UIColor.whiteColor colorWithAlphaComponent:0.40]];
    secondaryGlow.layer.shadowOpacity = 0.18;
    secondaryGlow.layer.shadowRadius  = 18.0;
    secondaryGlow.layer.shadowOffset  = CGSizeZero;
    [cardView addSubview:secondaryGlow];

    // Accent bar
    UIView *accentBar = [[UIView alloc] init];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = brandColor;
    accentBar.layer.cornerRadius = 3.0;
    [cardView addSubview:accentBar];

    // Eyebrow pill — bird icon + text
    UIView *eyebrowPill = [[UIView alloc] init];
    eyebrowPill.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowPill.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.74];
    eyebrowPill.layer.cornerRadius = 14.0;
    eyebrowPill.layer.borderWidth = 1.0;
    [eyebrowPill pp_setBorderColor:[brandColor colorWithAlphaComponent:0.10]];
    eyebrowPill.layer.masksToBounds = YES;
    [cardView addSubview:eyebrowPill];

    UIImageView *birdIcon = [[UIImageView alloc] init];
    birdIcon.translatesAutoresizingMaskIntoConstraints = NO;
    birdIcon.image = [UIImage systemImageNamed:@"bird.fill"
                                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold]];
    birdIcon.tintColor = [brandColor colorWithAlphaComponent:0.92];
    birdIcon.contentMode = UIViewContentModeScaleAspectFit;
    [eyebrowPill addSubview:birdIcon];

    UILabel *eyebrowLabel = [[UILabel alloc] init];
    eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    eyebrowLabel.textColor = [brandColor colorWithAlphaComponent:0.92];
    eyebrowLabel.textAlignment = NSTextAlignmentCenter;
    eyebrowLabel.text = self.serverCardClass ? kLang(@"editCard") : kLang(@"addNewCard");
    [eyebrowPill addSubview:eyebrowLabel];

    // Title — big bold label
    _topTitle = [[UILabel alloc] init];
    _topTitle.translatesAutoresizingMaskIntoConstraints = NO;
    _topTitle.font = [GM boldFontWithSize:24.0] ?: [UIFont systemFontOfSize:24.0 weight:UIFontWeightBold];
    _topTitle.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    _topTitle.textAlignment = PPCardCurrentTextAlignment();
    _topTitle.numberOfLines = 2;
    _topTitle.text = kLang(@"BirdsCard");
    [cardView addSubview:_topTitle];

    // --- Stat capsules row ---
    UIView *statsRow = [[UIView alloc] init];
    statsRow.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:statsRow];

    NSInteger myCardsCount = AppData.UserCardsDocs.count;
    UIView *stat1 = [self _heroStatCapsuleWithIcon:@"doc.text.fill"
                                             value:[NSString stringWithFormat:@"%ld", (long)myCardsCount]
                                             label:kLang(@"myCards")];
    stat1.translatesAutoresizingMaskIntoConstraints = NO;
    [statsRow addSubview:stat1];

    NSInteger totalCards = AppData.AllCardsDocs.count;
    UIView *stat2 = [self _heroStatCapsuleWithIcon:@"square.grid.2x2.fill"
                                             value:[NSString stringWithFormat:@"%ld", (long)totalCards]
                                             label:kLang(@"totalCards")];
    stat2.translatesAutoresizingMaskIntoConstraints = NO;
    [statsRow addSubview:stat2];

    NSInteger breedsCount = self.SubKindsArrayLocal.count;
    UIView *stat3 = [self _heroStatCapsuleWithIcon:@"leaf.fill"
                                             value:[NSString stringWithFormat:@"%ld", (long)breedsCount]
                                             label:kLang(@"breeds")];
    stat3.translatesAutoresizingMaskIntoConstraints = NO;
    [statsRow addSubview:stat3];

    [NSLayoutConstraint activateConstraints:@[
        // Card inset from header root
        [cardView.topAnchor constraintEqualToAnchor:_topView.topAnchor constant:8.0],
        [cardView.leadingAnchor constraintEqualToAnchor:_topView.leadingAnchor constant:20.0],
        [cardView.trailingAnchor constraintEqualToAnchor:_topView.trailingAnchor constant:-20.0],
        [cardView.bottomAnchor constraintEqualToAnchor:_topView.bottomAnchor constant:-10.0],

        // Tint overlay
        [tintView.topAnchor constraintEqualToAnchor:cardView.topAnchor],
        [tintView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor],
        [tintView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor],
        [tintView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor],

        // Ambient glow orb — top right
        [ambientGlow.widthAnchor constraintEqualToConstant:144.0],
        [ambientGlow.heightAnchor constraintEqualToConstant:144.0],
        [ambientGlow.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:-60.0],
        [ambientGlow.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:60.0],

        // Secondary glow orb — bottom left
        [secondaryGlow.widthAnchor constraintEqualToConstant:92.0],
        [secondaryGlow.heightAnchor constraintEqualToConstant:92.0],
        [secondaryGlow.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:30.0],
        [secondaryGlow.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:-26.0],

        // Accent bar
        [accentBar.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:20.0],
        [accentBar.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:22.0],
        [accentBar.widthAnchor constraintEqualToConstant:56.0],
        [accentBar.heightAnchor constraintEqualToConstant:6.0],

        // Eyebrow pill
        [eyebrowPill.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:12.0],
        [eyebrowPill.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:22.0],
        [eyebrowPill.trailingAnchor constraintLessThanOrEqualToAnchor:cardView.trailingAnchor constant:-22.0],
        [eyebrowPill.heightAnchor constraintGreaterThanOrEqualToConstant:28.0],

        [birdIcon.leadingAnchor constraintEqualToAnchor:eyebrowPill.leadingAnchor constant:10.0],
        [birdIcon.centerYAnchor constraintEqualToAnchor:eyebrowPill.centerYAnchor],
        [birdIcon.widthAnchor constraintEqualToConstant:16.0],
        [birdIcon.heightAnchor constraintEqualToConstant:16.0],

        [eyebrowLabel.leadingAnchor constraintEqualToAnchor:birdIcon.trailingAnchor constant:6.0],
        [eyebrowLabel.trailingAnchor constraintEqualToAnchor:eyebrowPill.trailingAnchor constant:-12.0],
        [eyebrowLabel.topAnchor constraintEqualToAnchor:eyebrowPill.topAnchor constant:6.0],
        [eyebrowLabel.bottomAnchor constraintEqualToAnchor:eyebrowPill.bottomAnchor constant:-6.0],

        // Title
        [_topTitle.topAnchor constraintEqualToAnchor:eyebrowPill.bottomAnchor constant:12.0],
        [_topTitle.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:22.0],
        [_topTitle.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-22.0],

        // Stats row
        [statsRow.topAnchor constraintEqualToAnchor:_topTitle.bottomAnchor constant:14.0],
        [statsRow.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:14.0],
        [statsRow.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-14.0],
        [statsRow.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-18.0],
        [statsRow.heightAnchor constraintEqualToConstant:64.0],

        // Stat capsules — equal width
        [stat1.leadingAnchor constraintEqualToAnchor:statsRow.leadingAnchor],
        [stat1.topAnchor constraintEqualToAnchor:statsRow.topAnchor],
        [stat1.bottomAnchor constraintEqualToAnchor:statsRow.bottomAnchor],

        [stat2.leadingAnchor constraintEqualToAnchor:stat1.trailingAnchor constant:8.0],
        [stat2.topAnchor constraintEqualToAnchor:statsRow.topAnchor],
        [stat2.bottomAnchor constraintEqualToAnchor:statsRow.bottomAnchor],
        [stat2.widthAnchor constraintEqualToAnchor:stat1.widthAnchor],

        [stat3.leadingAnchor constraintEqualToAnchor:stat2.trailingAnchor constant:8.0],
        [stat3.topAnchor constraintEqualToAnchor:statsRow.topAnchor],
        [stat3.bottomAnchor constraintEqualToAnchor:statsRow.bottomAnchor],
        [stat3.trailingAnchor constraintEqualToAnchor:statsRow.trailingAnchor],
        [stat3.widthAnchor constraintEqualToAnchor:stat1.widthAnchor],
    ]];

    // Size the header to fit its content, assign as tableHeaderView
    CGSize fittingSize = [_topView systemLayoutSizeFittingSize:
        CGSizeMake(CGRectGetWidth(self.view.bounds), UILayoutFittingCompressedSize.height)
                                withHorizontalFittingPriority:UILayoutPriorityRequired
                                      verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    _topView.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), fittingSize.height);
}

/// Stat capsule — brand-tinted frosted pill with value + label
- (UIView *)_heroStatCapsuleWithIcon:(NSString *)iconName value:(NSString *)value label:(NSString *)label {
    UIColor *brandColor = AppPrimaryClr ?: UIColor.systemOrangeColor;

    UIView *capsule = [[UIView alloc] init];
    capsule.backgroundColor = [brandColor colorWithAlphaComponent:0.08];
    capsule.layer.cornerRadius = 16.0;
    capsule.layer.borderWidth = 1.0;
    [capsule pp_setBorderColor:[brandColor colorWithAlphaComponent:0.10]];

    UILabel *valueLabel = [[UILabel alloc] init];
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.text = value;
    valueLabel.font = [GM boldFontWithSize:20] ?: [UIFont monospacedDigitSystemFontOfSize:20 weight:UIFontWeightBold];
    valueLabel.textColor = brandColor;
    valueLabel.textAlignment = NSTextAlignmentCenter;
    [capsule addSubview:valueLabel];

    UILabel *labelView = [[UILabel alloc] init];
    labelView.translatesAutoresizingMaskIntoConstraints = NO;
    labelView.text = label;
    labelView.font = [GM MidFontWithSize:10] ?: [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    labelView.textColor = [brandColor colorWithAlphaComponent:0.68];
    labelView.textAlignment = NSTextAlignmentCenter;
    labelView.adjustsFontSizeToFitWidth = YES;
    labelView.minimumScaleFactor = 0.7;
    [capsule addSubview:labelView];

    [NSLayoutConstraint activateConstraints:@[
        [valueLabel.topAnchor constraintEqualToAnchor:capsule.topAnchor constant:12.0],
        [valueLabel.centerXAnchor constraintEqualToAnchor:capsule.centerXAnchor],
        [valueLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:capsule.leadingAnchor constant:4.0],
        [valueLabel.trailingAnchor constraintLessThanOrEqualToAnchor:capsule.trailingAnchor constant:-4.0],
        [labelView.topAnchor constraintEqualToAnchor:valueLabel.bottomAnchor constant:2.0],
        [labelView.centerXAnchor constraintEqualToAnchor:capsule.centerXAnchor],
        [labelView.leadingAnchor constraintGreaterThanOrEqualToAnchor:capsule.leadingAnchor constant:4.0],
        [labelView.trailingAnchor constraintLessThanOrEqualToAnchor:capsule.trailingAnchor constant:-4.0],
        [labelView.bottomAnchor constraintLessThanOrEqualToAnchor:capsule.bottomAnchor constant:-10.0],
    ]];

    return capsule;
}

// =============================================================================
#pragma mark - viewDidLoad
// =============================================================================

- (void)viewDidLoad {
    [super viewDidLoad];

    self.storageRef     = [GM CardsImagesRefrence];
    self.uploadManager  = [[FileUploadManager alloc] init];
    self.formDataArray  = [NSMutableDictionary new];
    self.allCardsArray  = AppData.AllCardsDocs;
    self.didChangeImages     = NO;
    self.isHydratingImages   = NO;
    self.isSaving            = NO;
    self.isHydratingFormData = YES;
    self.hasUserModifiedForm = NO;
    self.isDateSelected      = NO;

    self.view.backgroundColor = PPCardFormCanvasColor();
    self.view.layer.cornerRadius = 25;
    self.view.clipsToBounds = YES;

    initFlag = 0;
    finishFlag = 0;
    formFinishupload = 0;

    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    topbarHeight = self.navigationController.navigationBar.hx_maxy;
    if (topbarHeight < 44.0) topbarHeight = 44.0;
    #pragma clang diagnostic pop

    self.modalInPresentation = YES;

    [self initializeFormData];
    [self setupTableView];
    [self setupHeaderViews];
    self.tableView.tableHeaderView = _topView;
    self.tableView.contentInset = UIEdgeInsetsMake(6.0, 0, 120, 0);
    [self rebuildFormSections];
    [self.tableView reloadData];

    [self setClassTpForm];

    if ([self.FromVC isEqualToString:@"ViewData"])
        self.title = kLang(@"EditCard");
    else if ([self.FromVC isEqualToString:@"ViewDatas"])
        self.title = kLang(@"EditCard");
    else
        self.title = kLang(@"addNewCard");

    _prefs            = [NSUserDefaults standardUserDefaults];
    _storageRef       = [GM CardsImagesRefrence];
    _alertTitleDone   = kLang(@"doneTitle");
    _alertSubtitleDone = kLang(@"AddedAlertSubtitleDone");
    _alertWarningDataTitle    = kLang(@"warningTitle");
    _alertWarningDataSubTitle = kLang(@"warningSubTitle");

    [self syncFormDataWithServerCardIfNeeded];

    if (self.prefilledRingID.length > 0 && ![self isEditingFlow]) {
        [self setformDataArray:self.prefilledRingID forKey:@"RingID"];
    }

    [self setupImageCollection];
    [self restoreDraftIfNeeded];
    [self rebuildFormSections];
    [self.tableView reloadData];
    self.isHydratingFormData = NO;
}

// =============================================================================
#pragma mark - Initialize Form Data
// =============================================================================

- (void)initializeFormData {
    _prefs = [NSUserDefaults standardUserDefaults];
    userID = UserManager.sharedManager.currentUser.ID;
    self.CardsdataSource = AppData.UserCardsDocs;
    initFlag = 1;

    self.SubKindsArrayLocal = [[MKM.MainKindsArray filteredArrayUsingPredicate:
                                [NSPredicate predicateWithFormat:@"SELF.ID == %ld", 1]] firstObject].SubKindsArray;
    self.SubKindsArrayList = [self.SubKindsArrayLocal valueForKey:@"SubKindNameAr"];

    self.attributeArrayLocat = [[NSMutableArray alloc] init];
    [self.attributeArrayLocat addObject:kLang(@"blue")];
    [self.attributeArrayLocat addObject:kLang(@"Green")];
    [self.attributeArrayLocat addObject:kLang(@"trkwaz")];
    [self.attributeArrayLocat addObject:kLang(@"other")];

    [self setformDataArray:@"no_value" forKey:@"AdDesc"];
    [self setformDataArray:@"no_value" forKey:@"loanForUser"];
    [self setformDataArray:@"no_value" forKey:@"AttributeNote"];
    [self setformDataArray:userID forKey:@"UserID"];
    [self setformDataArray:PPCurrentUser.UserName forKey:@"OwnerName"];
}

// =============================================================================
#pragma mark - Setup TableView
// =============================================================================

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.estimatedRowHeight = 68.0;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.clipsToBounds = NO;
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }

    [self.tableView registerClass:[PPCardTextFieldCell class] forCellReuseIdentifier:PPCardTextFieldCellID];
    [self.tableView registerClass:[PPCardSelectorCell class] forCellReuseIdentifier:PPCardSelectorCellID];
    [self.tableView registerClass:[PPCardSwitchCell class] forCellReuseIdentifier:PPCardSwitchCellID];
    [self.tableView registerClass:[PPCardTextViewCell class] forCellReuseIdentifier:PPCardTextViewCellID];
    [self.tableView registerClass:[PPCardSegmentedCell class] forCellReuseIdentifier:PPCardSegmentedCellID];
    [self.tableView registerClass:[PPCardImageCell class] forCellReuseIdentifier:PPCardImageCellID];

    [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

// =============================================================================
#pragma mark - Animated Form Rebuild
// =============================================================================

- (void)animatedRebuildFormSections {
    // Capture old row counts per section
    NSMutableArray<NSNumber *> *oldCounts = [NSMutableArray array];
    for (NSArray *section in self.formSections) {
        [oldCounts addObject:@(section.count)];
    }
    NSInteger oldSectionCount = self.formSections.count;

    // Rebuild
    [self rebuildFormSections];

    NSInteger newSectionCount = self.formSections.count;
    NSMutableArray<NSNumber *> *newCounts = [NSMutableArray array];
    for (NSArray *section in self.formSections) {
        [newCounts addObject:@(section.count)];
    }

    // If section count changed, just do a smooth fade reload
    if (oldSectionCount != newSectionCount) {
        [UIView transitionWithView:self.tableView
                          duration:0.3
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            [self.tableView reloadData];
        } completion:nil];
        return;
    }

    // Same section count — animate row changes per section
    [self.tableView beginUpdates];
    for (NSInteger s = 0; s < newSectionCount; s++) {
        NSInteger oldN = [oldCounts[s] integerValue];
        NSInteger newN = [newCounts[s] integerValue];
        if (newN > oldN) {
            NSMutableArray<NSIndexPath *> *inserts = [NSMutableArray array];
            for (NSInteger r = oldN; r < newN; r++) {
                [inserts addObject:[NSIndexPath indexPathForRow:r inSection:s]];
            }
            [self.tableView insertRowsAtIndexPaths:inserts withRowAnimation:UITableViewRowAnimationFade];
        } else if (newN < oldN) {
            NSMutableArray<NSIndexPath *> *deletes = [NSMutableArray array];
            for (NSInteger r = newN; r < oldN; r++) {
                [deletes addObject:[NSIndexPath indexPathForRow:r inSection:s]];
            }
            [self.tableView deleteRowsAtIndexPaths:deletes withRowAnimation:UITableViewRowAnimationFade];
        }
    }
    [self.tableView endUpdates];

    // Reload visible rows to refresh content without animation
    NSArray<NSIndexPath *> *visible = [self.tableView indexPathsForVisibleRows];
    if (visible.count > 0) {
        [self.tableView reloadRowsAtIndexPaths:visible withRowAnimation:UITableViewRowAnimationNone];
    }
}

// =============================================================================
#pragma mark - Rebuild Form Sections
// =============================================================================

- (void)rebuildFormSections {
    NSMutableArray<PPCardFormField *> *identitySection = [NSMutableArray array];
    NSMutableArray<PPCardFormField *> *detailsSection = [NSMutableArray array];
    NSMutableArray<PPCardFormField *> *additionalSection = [NSMutableArray array];

    // --- SECTION 0: Identity ---
    // RingID
    PPCardFormField *ringField = [PPCardFormField new];
    ringField.tag = @"RingID";
    ringField.title = kLang(@"RingID");
    ringField.placeholder = kLang(@"RingIDPlace");
    ringField.fieldType = PPCardFieldTypeText;
    ringField.value = [self getformDataForKey:@"RingID" withType:1];
    if ([ringField.value isKindOfClass:NSString.class] && [self isNoValueString:ringField.value]) ringField.value = nil;
    ringField.required = YES;
    [identitySection addObject:ringField];

    // SubKind
    PPCardFormField *subKindField = [PPCardFormField new];
    subKindField.tag = @"SubKind";
    subKindField.title = kLang(@"SubKind");
    subKindField.placeholder = kLang(@"SubKindPlace");
    subKindField.fieldType = PPCardFieldTypeSelector;
    if (self.selectedSubKindModel) {
        subKindField.value = [self.selectedSubKindModel formDisplayText];
    }
    subKindField.required = YES;
    [identitySection addObject:subKindField];

    // SubSubKind (dynamic)
    if (self.selectedSubKindModel && self.selectedSubKindModel.have_subSub == 1 && self.subSubKindsArrayLocal.count > 0) {
        PPCardFormField *subSubField = [PPCardFormField new];
        subSubField.tag = @"subSubKind";
        subSubField.title = kLang(@"subSubKind");
        subSubField.placeholder = kLang(@"subSubKindPlaceholder");
        subSubField.fieldType = PPCardFieldTypeSelector;
        NSNumber *subSubKindIDVal = [self getformDataForKey:@"subSubKindID" withType:0];
        if ([subSubKindIDVal integerValue] > 0) {
            subSubKindModel *model = [[self.subSubKindsArrayLocal filteredArrayUsingPredicate:
                [NSPredicate predicateWithFormat:@"SELF.ID == %ld", [subSubKindIDVal integerValue]]] firstObject];
            if (model) subSubField.value = [model formDisplayText];
        }
        [identitySection addObject:subSubField];
    }

    // Attribute (dynamic - when have_subSub==1 AND SubKindID == 7)
    if (self.selectedSubKindModel && self.selectedSubKindModel.have_subSub == 1 && self.selectedSubKindModel.ID == 7) {
        PPCardFormField *attrField = [PPCardFormField new];
        attrField.tag = @"attribute";
        attrField.title = kLang(@"attribute");
        attrField.placeholder = kLang(@"attributePlace");
        attrField.fieldType = PPCardFieldTypeSelector;
        NSInteger attrIdx = [[self getformDataForKey:@"attribute" withType:0] integerValue];
        if (attrIdx > 0 && attrIdx <= (NSInteger)self.attributeArrayLocat.count) {
            attrField.value = self.attributeArrayLocat[attrIdx - 1];
        }
        [identitySection addObject:attrField];

        // AttributeNote (dynamic - when attribute index == 4 i.e. "other")
        if (attrIdx == 4) {
            PPCardFormField *attrNoteField = [PPCardFormField new];
            attrNoteField.tag = @"AttributeNote";
            attrNoteField.title = kLang(@"attributeNote");
            attrNoteField.placeholder = kLang(@"attributeNotePlace");
            attrNoteField.fieldType = PPCardFieldTypeText;
            id noteVal = [self getformDataForKey:@"AttributeNote" withType:1];
            if ([noteVal isKindOfClass:NSString.class] && ![self isNoValueString:noteVal]) attrNoteField.value = noteVal;
            [identitySection addObject:attrNoteField];
        }
    }

    // Classification (dynamic)
    if (self.subKindItemsArrayLocal.count > 0) {
        PPCardFormField *classField = [PPCardFormField new];
        classField.tag = @"Classification";
        classField.title = kLang(@"ClassificationPlace");
        classField.placeholder = kLang(@"ClassificationPlace");
        classField.fieldType = PPCardFieldTypeSelector;
        NSArray *selectedIDs = self.selectedItemsArray;
        if ([selectedIDs isKindOfClass:NSArray.class] && selectedIDs.count > 0) {
            classField.value = [NSString stringWithFormat:@"%lu %@", (unsigned long)selectedIDs.count, selectedIDs.count > 1 ? kLang(@"items") : kLang(@"item")];
        }
        [identitySection addObject:classField];
    }

    // --- SECTION 1: Details ---
    // Color (dynamic - when have_subSub==1 AND SubKindID == 7)
    if (self.selectedSubKindModel && self.selectedSubKindModel.have_subSub == 1 && self.selectedSubKindModel.ID == 7) {
        PPCardFormField *colorField = [PPCardFormField new];
        colorField.tag = @"birdColor";
        colorField.title = kLang(@"Color");
        colorField.placeholder = kLang(@"colorTXTPlace");
        colorField.fieldType = PPCardFieldTypeText;
        id colorVal = [self getformDataForKey:@"birdColor" withType:1];
        if ([colorVal isKindOfClass:NSString.class] && ![self isNoValueString:colorVal]) colorField.value = colorVal;
        [detailsSection addObject:colorField];
    }

    // BirthDate
    PPCardFormField *birthField = [PPCardFormField new];
    birthField.tag = @"BirthDate";
    birthField.title = kLang(@"BirthDatePlace");
    birthField.placeholder = kLang(@"BirthDatePlace");
    birthField.fieldType = PPCardFieldTypeSelector;
    if (self.isDateSelected && self.selectedBirthDate) {
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        [fmt setDateFormat:@"dd/MM/yyyy"];
        birthField.value = [fmt stringFromDate:self.selectedBirthDate];
    }
    birthField.required = YES;
    [detailsSection addObject:birthField];

    // Age (dynamic - after date selected)
    if (self.isDateSelected) {
        PPCardFormField *ageField = [PPCardFormField new];
        ageField.tag = @"age";
        ageField.title = kLang(@"ageBird");
        ageField.fieldType = PPCardFieldTypeSelector;
        ageField.disabled = YES;
        NSDate *bd = self.selectedBirthDate ?: [NSDate date];
        ageField.value = [self ageFromBirthday:bd adultHood:self.currentAdultHood];
        [detailsSection addObject:ageField];
    }

    // Father
    PPCardFormField *fatherField = [PPCardFormField new];
    fatherField.tag = @"FatherRingID";
    fatherField.title = kLang(@"fatherRingIDPlace");
    fatherField.placeholder = kLang(@"selectFather");
    fatherField.fieldType = PPCardFieldTypeSelector;
    if (self.selectedFather) {
        fatherField.value = self.selectedFather.RingID;
    }
    fatherField.disabled = (self.fathersCardsArray.count == 0);
    if (self.fathersCardsArray.count == 0) {
        fatherField.placeholder = kLang(@"FatherRowCount");
    }
    [detailsSection addObject:fatherField];

    // Mother
    PPCardFormField *motherField = [PPCardFormField new];
    motherField.tag = @"MotherRingID";
    motherField.title = kLang(@"motherRingIDPlace");
    motherField.placeholder = kLang(@"selectMother");
    motherField.fieldType = PPCardFieldTypeSelector;
    if (self.selectedMother) {
        motherField.value = self.selectedMother.RingID;
    }
    motherField.disabled = (self.mothersCardsArray.count == 0);
    if (self.mothersCardsArray.count == 0) {
        motherField.placeholder = kLang(@"MotherRowCount");
    }
    [detailsSection addObject:motherField];

    // --- SECTION 2: Additional ---
    // Sexual
    PPCardFormField *sexualField = [PPCardFormField new];
    sexualField.tag = @"Sexual";
    sexualField.title = kLang(@"SexualPlace");
    sexualField.fieldType = PPCardFieldTypeSegmented;
    sexualField.value = [self getformDataForKey:@"Sexual" withType:0];
    sexualField.required = YES;
    [additionalSection addObject:sexualField];

    // ClassificationLoaded (dynamic - after sexual selected)
    NSInteger sexual = [[self getformDataForKey:@"Sexual" withType:0] integerValue];
    NSArray<subKindItemsModel *> *loadedOptions = nil;
    if (sexual == 1) loadedOptions = self.LoadedItemsMaleArrayLocal;
    else if (sexual == 2) loadedOptions = self.LoadedItemsFemaleArrayLocal;
    if (loadedOptions.count > 0) {
        PPCardFormField *classLoadedField = [PPCardFormField new];
        classLoadedField.tag = @"ClassificationLoaded";
        classLoadedField.title = kLang(@"ClassificationLoaded");
        classLoadedField.placeholder = kLang(@"ClassificationPlace");
        classLoadedField.fieldType = PPCardFieldTypeSelector;
        NSArray *loadedIDs = self.selectedItemsLoadedArray;
        if ([loadedIDs isKindOfClass:NSArray.class] && loadedIDs.count > 0) {
            classLoadedField.value = [NSString stringWithFormat:@"%lu %@", (unsigned long)loadedIDs.count, loadedIDs.count > 1 ? kLang(@"items") : kLang(@"item")];
        }
        [additionalSection addObject:classLoadedField];
    }

    // Description
    PPCardFormField *descField = [PPCardFormField new];
    descField.tag = @"AdDesc";
    descField.title = kLang(@"cardDesc");
    descField.placeholder = kLang(@"AdDescPlace");
    descField.fieldType = PPCardFieldTypeTextView;
    id descVal = [self getformDataForKey:@"AdDesc" withType:1];
    if ([descVal isKindOfClass:NSString.class] && ![self isNoValueString:descVal]) descField.value = descVal;
    [additionalSection addObject:descField];

    // DNA Image
    PPCardFormField *dnaField = [PPCardFormField new];
    dnaField.tag = @"DNAImage";
    dnaField.title = kLang(@"AddDnaScan");
    dnaField.fieldType = PPCardFieldTypeImage;
    id dnaImg = [self.formDataArray objectForKey:@"DNAImage"];
    if ([dnaImg isKindOfClass:UIImage.class]) dnaField.value = dnaImg;
    [additionalSection addObject:dnaField];

    self.formSections = [NSMutableArray arrayWithArray:@[identitySection, detailsSection, additionalSection]];
}

// =============================================================================
#pragma mark - UITableView DataSource
// =============================================================================

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.formSections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.formSections[section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPCardFormField *field = self.formSections[indexPath.section][indexPath.row];
    __weak typeof(self) weakSelf = self;

    switch (field.fieldType) {
        case PPCardFieldTypeText:
        case PPCardFieldTypeInteger: {
            PPCardTextFieldCell *cell = [tableView dequeueReusableCellWithIdentifier:PPCardTextFieldCellID forIndexPath:indexPath];
            [cell configureWithField:field];
            cell.onValueChanged = ^(NSString *text) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf setformDataArray:text forKey:field.tag];
                if ([field.tag isEqualToString:@"RingID"]) {
                    strongSelf->alertRingIDText = text;
                }
            };
            // Attach parrot color suggestions for the birdColor field
            if ([field.tag isEqualToString:@"birdColor"]) {
                PPParrotColorSuggestionsView *colorBar = [[PPParrotColorSuggestionsView alloc] initWithFrame:CGRectZero];
                colorBar.onColorSelected = ^(NSString *colorName) {
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (!strongSelf) return;
                    cell.textField.text = colorName;
                    cell.textField.textColor = PPCardFormAccentColor();
                    [strongSelf setformDataArray:colorName forKey:@"birdColor"];
                };
                cell.textField.inputAccessoryView = colorBar;
            } else {
                cell.textField.inputAccessoryView = nil;
            }
            return cell;
        }

        case PPCardFieldTypeSelector: {
            PPCardSelectorCell *cell = [tableView dequeueReusableCellWithIdentifier:PPCardSelectorCellID forIndexPath:indexPath];
            [cell configureWithField:field];
            return cell;
        }

        case PPCardFieldTypeSwitch: {
            PPCardSwitchCell *cell = [tableView dequeueReusableCellWithIdentifier:PPCardSwitchCellID forIndexPath:indexPath];
            [cell configureWithField:field];
            cell.onSwitchChanged = ^(BOOL isOn) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf setformDataArray:@(isOn) forKey:field.tag];
            };
            return cell;
        }

        case PPCardFieldTypeTextView: {
            PPCardTextViewCell *cell = [tableView dequeueReusableCellWithIdentifier:PPCardTextViewCellID forIndexPath:indexPath];
            [cell configureWithField:field];
            cell.onTextChanged = ^(NSString *text) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf setformDataArray:text forKey:field.tag];
            };
            return cell;
        }

        case PPCardFieldTypeSegmented: {
            PPCardSegmentedCell *cell = [tableView dequeueReusableCellWithIdentifier:PPCardSegmentedCellID forIndexPath:indexPath];
            [cell configureWithField:field];
            cell.onSegmentChanged = ^(NSInteger selectedIndex) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf sexualSegmentChangedWithIndex:selectedIndex];
            };
            return cell;
        }

        case PPCardFieldTypeImage: {
            PPCardImageCell *cell = [tableView dequeueReusableCellWithIdentifier:PPCardImageCellID forIndexPath:indexPath];
            [cell configureWithField:field];
            return cell;
        }
    }

    return [UITableViewCell new];
}

// =============================================================================
#pragma mark - UITableView Delegate
// =============================================================================

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    cell.backgroundColor = UIColor.clearColor;
    cell.clipsToBounds = NO;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.contentView.backgroundColor = PPCardFormSurfaceColor();
    cell.contentView.layer.cornerRadius = 20.0;
    cell.contentView.layer.masksToBounds = YES;
    cell.contentView.layer.borderWidth = 1.0;
    [cell.contentView pp_setBorderColor:PPCardFormBorderColor()];
    [cell pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    cell.layer.shadowOpacity = 0.04;
    cell.layer.shadowRadius = 8.0;
    cell.layer.shadowOffset = CGSizeMake(0.0, 3.0);
    cell.layer.masksToBounds = NO;
    // Pre-set shadowPath to prevent shadow recalculation jumps
    UIBezierPath *shadowBounds = [UIBezierPath bezierPathWithRoundedRect:cell.contentView.frame cornerRadius:20.0];
    cell.layer.shadowPath = shadowBounds.CGPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Dismiss keyboard before presenting any sheet
    [self.view endEditing:YES];

    PPCardFormField *field = self.formSections[indexPath.section][indexPath.row];
    if (field.disabled) return;

    if ([field.tag isEqualToString:@"SubKind"]) {
        [self subKindRowTapped];
    } else if ([field.tag isEqualToString:@"subSubKind"]) {
        [self subSubKindRowTapped];
    } else if ([field.tag isEqualToString:@"attribute"]) {
        [self attributeRowTapped];
    } else if ([field.tag isEqualToString:@"Classification"]) {
        [self classificationRowTapped];
    } else if ([field.tag isEqualToString:@"BirthDate"]) {
        [self birthDateRowTapped];
    } else if ([field.tag isEqualToString:@"FatherRingID"]) {
        [self fatherRowTapped];
    } else if ([field.tag isEqualToString:@"MotherRingID"]) {
        [self motherRowTapped];
    } else if ([field.tag isEqualToString:@"ClassificationLoaded"]) {
        [self classificationLoadedRowTapped];
    } else if ([field.tag isEqualToString:@"DNAImage"]) {
        [self dnaImageRowTapped];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.section < 2) return 83;
    if(indexPath.section == 2 && indexPath.row == 0) return 104;
    if(indexPath.section == 2 &&  indexPath.row == 1 ) return 83;
    if(indexPath.section == 2 &&  indexPath.row == 2 ) return 64;

    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 70.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSArray<NSString *> *content = [self pp_sectionHeaderContentForSection:section];
    NSString *title = content.count > 0 ? content[0] : @"";
    NSString *subtitle = content.count > 1 ? content[1] : @"";
    return [self pp_sectionHeaderViewForTitle:title subtitle:subtitle];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return section == 2 ? 12 : 0.000001;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    return [UIView new];
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section {
    return 70.0;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForFooterInSection:(NSInteger)section {
    return section == 2 ? 12 : 0.000001;
}

// =============================================================================
#pragma mark - Section Header Content
// =============================================================================

- (NSArray<NSString *> *)pp_sectionHeaderContentForSection:(NSInteger)section {
    switch (section) {
        case 0: return @[kLang(@"RingID"), @""];
        case 1: return @[kLang(@"BirthDatePlace"), @""];
        case 2: return @[kLang(@"SexualPlace"), @""];
        default: return @[@"", @""];
    }
}

// =============================================================================
#pragma mark - Section Header Builder
// =============================================================================

- (UIView *)pp_sectionHeaderViewForTitle:(NSString *)title subtitle:(NSString *)subtitle {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = UIColor.clearColor;

    UIView *accentBar = [[UIView alloc] init];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = PPCardFormAccentColor();
    accentBar.layer.cornerRadius = 3.0;
    [container addSubview:accentBar];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = PPCardFormPrimaryTextColor();
    titleLabel.text = title ?: @"";
    titleLabel.textAlignment = PPCardCurrentTextAlignment();
    [container addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.88];
    subtitleLabel.text = subtitle ?: @"";
    subtitleLabel.textAlignment = PPCardCurrentTextAlignment();
    subtitleLabel.numberOfLines = 2;
    [container addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [accentBar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20.0],
        [accentBar.topAnchor constraintEqualToAnchor:container.topAnchor constant:12.0],
        [accentBar.widthAnchor constraintEqualToConstant:56.0],
        [accentBar.heightAnchor constraintEqualToConstant:6.0],
        [titleLabel.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:10.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:accentBar.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20.0],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:5.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:container.bottomAnchor constant:-10.0]
    ]];

    return container;
}

// =============================================================================
#pragma mark - Cell Lookup Helper
// =============================================================================

- (UITableViewCell *)cellForFieldTag:(NSString *)tag {
    for (NSInteger section = 0; section < (NSInteger)self.formSections.count; section++) {
        NSArray *fields = self.formSections[section];
        for (NSInteger row = 0; row < (NSInteger)fields.count; row++) {
            PPCardFormField *field = fields[row];
            if ([field.tag isEqualToString:tag]) {
                return [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section]];
            }
        }
    }
    return nil;
}

// =============================================================================
#pragma mark - Row Tap Handlers
// =============================================================================

- (void)subKindRowTapped {
    __weak typeof(self) weakSelf = self;
    PPSelectOptionViewController *vc =
        [[PPSelectOptionViewController alloc] initWithOptions:self.SubKindsArrayLocal
                                                        title:kLang(@"SubKindPlace")
                                                          row:nil
                                            presentationStyle:PPSelectOptionPresentationSheet
                                                   completion:^(id _Nullable selectedObject) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !selectedObject) return;
        [strongSelf handleSubKindSelected:selectedObject];
    }];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [PPFunc presentSheetFrom:self sheetVC:nav detentStyle:PPSheetDetentStyle80];
}

- (void)handleSubKindSelected:(SubKindModel *)newValue {
    self.selectedItemsArray       = [NSMutableArray new];
    self.selectedItemsLoadedArray = [NSMutableArray new];

    [self.formDataArray removeObjectForKey:@"attribute"];
    [self.formDataArray removeObjectForKey:@"AttributeNote"];
    [self.formDataArray removeObjectForKey:@"selectedItemsArray"];
    [self.formDataArray removeObjectForKey:@"selectedItemsLoadedArray"];
    [self.formDataArray removeObjectForKey:@"birdColor"];
    [self removeDataArrayObjects:@[@"selectedItemsArray", @"ClassificationLoaded", @"subSubKindID", @"attributeRow"]];

    self.selectedSubKindModel = newValue;
    [self setParentArray_SubKindID:self.selectedSubKindModel.ID];
    self.currentAdultHood = self.selectedSubKindModel.adultHood;

    [self setformDataArray:@(self.selectedSubKindModel.ID) forKey:@"SubKind"];
    alertSubKindIDText = self.selectedSubKindModel.SubKindNameAr;

    if (self.selectedSubKindModel.have_subSub == 1) {
        self.subSubKindsArrayLocal = self.selectedSubKindModel.subSubKindArray;
        self.subSubKindsArrayList = [Language languageVal] == 0
            ? [self.subSubKindsArrayLocal valueForKey:@"nameEn"]
            : [self.subSubKindsArrayLocal valueForKey:@"nameAr"];

        self.subKindItemsArrayLocal = nil;
        self.LoadedItemsMaleArrayLocal = nil;
        self.LoadedItemsFemaleArrayLocal = nil;

    } else if (self.selectedSubKindModel.have_subSub == 0 && self.selectedSubKindModel.have_items == 1) {
        self.subSubKindsArrayLocal = self.selectedSubKindModel.subSubKindArray;
        self.subKindItemsArrayLocal = [self.subSubKindsArrayLocal objectAtIndex:0].subKindItemsArray;

        if (self.subKindItemsArrayLocal.count != 0) {
            self.LoadedItemsMaleArrayLocal = [self.subKindItemsArrayLocal filteredArrayUsingPredicate:
                                              [NSPredicate predicateWithFormat:@"SELF.Male == 'yes'"]].mutableCopy;
            self.LoadedItemsFemaleArrayLocal = [self.subKindItemsArrayLocal filteredArrayUsingPredicate:
                                                [NSPredicate predicateWithFormat:@"SELF.Female == 'yes'"]].mutableCopy;
        }
    } else {
        self.subSubKindsArrayLocal = nil;
        self.subKindItemsArrayLocal = nil;
        self.LoadedItemsMaleArrayLocal = nil;
        self.LoadedItemsFemaleArrayLocal = nil;
        [self.formDataArray removeObjectForKey:@"birdColor"];
        [self.formDataArray removeObjectForKey:@"attribute"];
        [self.formDataArray removeObjectForKey:@"Classification"];
        [self.formDataArray removeObjectForKey:@"AttributeNote"];
        [self.formDataArray removeObjectForKey:@"selectedItemsArray"];
        [self.formDataArray removeObjectForKey:@"selectedItemsLoadedArray"];
    }

    [self animatedRebuildFormSections];
}

- (void)subSubKindRowTapped {
    __weak typeof(self) weakSelf = self;
    PPSelectOptionViewController *vc =
        [[PPSelectOptionViewController alloc] initWithOptions:self.subSubKindsArrayLocal
                                                        title:kLang(@"subSubKindPlaceholder")
                                                          row:nil
                                            presentationStyle:PPSelectOptionPresentationSheet
                                                   completion:^(id _Nullable selectedObject) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !selectedObject) return;
        [strongSelf handleSubSubKindSelected:selectedObject];
    }];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [PPFunc presentSheetFrom:self sheetVC:nav detentStyle:PPSheetDetentStyle80];
}

- (void)handleSubSubKindSelected:(subSubKindModel *)newValue {
    self.selectedItemsArray = [[NSMutableArray alloc] init];
    [self removeDataArrayObjects:@[@"selectedItemsArray", @"ClassificationLoaded"]];

    [self setformDataArray:@(newValue.ID) forKey:@"subSubKindID"];

    self.subKindItemsArrayLocal = newValue.subKindItemsArray;

    if (self.subKindItemsArrayLocal.count != 0) {
        self.LoadedItemsMaleArrayLocal = [self.subKindItemsArrayLocal filteredArrayUsingPredicate:
                                          [NSPredicate predicateWithFormat:@"SELF.Male == 'yes'"]].mutableCopy;
        self.LoadedItemsFemaleArrayLocal = [self.subKindItemsArrayLocal filteredArrayUsingPredicate:
                                            [NSPredicate predicateWithFormat:@"SELF.Female == 'yes'"]].mutableCopy;
    }

    [self animatedRebuildFormSections];
}

- (void)attributeRowTapped {
    __weak typeof(self) weakSelf = self;
    PPSelectOptionViewController *vc =
        [[PPSelectOptionViewController alloc] initWithOptions:self.attributeArrayLocat
                                                        title:kLang(@"attributePlace")
                                                          row:nil
                                            presentationStyle:PPSelectOptionPresentationSheet
                                                   completion:^(id _Nullable selectedObject) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !selectedObject) return;
        [strongSelf handleAttributeSelected:selectedObject];
    }];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [PPFunc presentSheetFrom:self sheetVC:nav detentStyle:PPSheetDetentStyle80];
}

- (void)handleAttributeSelected:(NSString *)newValue {
    [self removeDataArrayObjects:@[@"AttributeNote"]];

    NSInteger selectedIndex = [self.attributeArrayLocat indexOfObject:newValue];
    [self setformDataArray:[NSString stringWithFormat:@"%ld", (long)(selectedIndex + 1)] forKey:@"attribute"];

    [self animatedRebuildFormSections];
}

- (void)classificationRowTapped {
    __weak typeof(self) weakSelf = self;

    PPCardMultiSelectViewController *vc = [[PPCardMultiSelectViewController alloc] init];
    vc.allItems = self.subKindItemsArrayLocal;
    vc.headerTitle = kLang(@"ClassificationPlace");

    NSMutableArray<subKindItemsModel *> *preSelected = [NSMutableArray array];
    NSArray *selectedIDs = self.selectedItemsArray;
    if ([selectedIDs isKindOfClass:NSArray.class]) {
        for (NSNumber *itemID in selectedIDs) {
            subKindItemsModel *match = [[self.subKindItemsArrayLocal filteredArrayUsingPredicate:
                                         [NSPredicate predicateWithFormat:@"SELF.ID == %ld", [itemID integerValue]]] firstObject];
            if (match) [preSelected addObject:match];
        }
    }
    vc.selectedItems = preSelected;

    vc.onDone = ^(NSArray<subKindItemsModel *> *selected) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        strongSelf.selectedItemsArray = [[NSMutableArray alloc] init];
        for (subKindItemsModel *item in selected) {
            if (![strongSelf.selectedItemsArray containsObject:@(item.ID)]) {
                [strongSelf.selectedItemsArray addObject:@(item.ID)];
            }
        }

        NSString *classification = [strongSelf.selectedItemsArray componentsJoinedByString:@","];
        [strongSelf setformDataArray:classification forKey:@"Classification"];
        [strongSelf setformDataArray:strongSelf.selectedItemsArray forKey:@"selectedItemsArray"];

        [strongSelf animatedRebuildFormSections];
    };

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [PPFunc presentSheetFrom:self sheetVC:nav detentStyle:PPSheetDetentStyle80];
}

- (void)classificationLoadedRowTapped {
    __weak typeof(self) weakSelf = self;

    NSArray<subKindItemsModel *> *options = nil;
    NSInteger sexual = [[self getformDataForKey:@"Sexual" withType:0] integerValue];
    if (sexual == 1) {
        options = self.LoadedItemsMaleArrayLocal;
    } else {
        options = self.LoadedItemsFemaleArrayLocal;
    }
    if (!options || options.count == 0) return;

    PPCardMultiSelectViewController *vc = [[PPCardMultiSelectViewController alloc] init];
    vc.allItems = options;
    vc.headerTitle = kLang(@"ClassificationLoaded");

    NSMutableArray<subKindItemsModel *> *preSelected = [NSMutableArray array];
    NSArray *selectedIDs = self.selectedItemsLoadedArray;
    if ([selectedIDs isKindOfClass:NSArray.class]) {
        for (NSNumber *itemID in selectedIDs) {
            subKindItemsModel *match = [[options filteredArrayUsingPredicate:
                                         [NSPredicate predicateWithFormat:@"SELF.ID == %ld", [itemID integerValue]]] firstObject];
            if (match) [preSelected addObject:match];
        }
    }
    vc.selectedItems = preSelected;

    vc.onDone = ^(NSArray<subKindItemsModel *> *selected) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        strongSelf.selectedItemsLoadedArray = [[NSMutableArray alloc] init];
        for (subKindItemsModel *item in selected) {
            if (![strongSelf.selectedItemsLoadedArray containsObject:@(item.ID)]) {
                [strongSelf.selectedItemsLoadedArray addObject:@(item.ID)];
            }
        }

        NSString *classificationLoaded = [strongSelf.selectedItemsLoadedArray componentsJoinedByString:@","];
        [strongSelf setformDataArray:classificationLoaded forKey:@"ClassificationLoaded"];
        [strongSelf setformDataArray:strongSelf.selectedItemsLoadedArray forKey:@"selectedItemsLoadedArray"];

        [strongSelf animatedRebuildFormSections];
    };

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [PPFunc presentSheetFrom:self sheetVC:nav detentStyle:PPSheetDetentStyle80];
}

- (void)birthDateRowTapped {
    UIViewController *pickerVC = [[UIViewController alloc] init];
    pickerVC.view.backgroundColor = [UIColor systemBackgroundColor];
    pickerVC.title = kLang(@"BirthDatePlace");

    UIDatePicker *picker = [[UIDatePicker alloc] init];
    picker.datePickerMode = UIDatePickerModeDate;
    picker.preferredDatePickerStyle = UIDatePickerStyleWheels;
    picker.maximumDate = [NSDate date];
    picker.translatesAutoresizingMaskIntoConstraints = NO;
    if (self.selectedBirthDate) picker.date = self.selectedBirthDate;
    [pickerVC.view addSubview:picker];

    [NSLayoutConstraint activateConstraints:@[
        [picker.topAnchor constraintEqualToAnchor:pickerVC.view.safeAreaLayoutGuide.topAnchor constant:24],
        [picker.leadingAnchor constraintEqualToAnchor:pickerVC.view.leadingAnchor constant:16],
        [picker.trailingAnchor constraintEqualToAnchor:pickerVC.view.trailingAnchor constant:-16],
        [picker.bottomAnchor constraintLessThanOrEqualToAnchor:pickerVC.view.safeAreaLayoutGuide.bottomAnchor constant:-24],
    ]];

    __weak typeof(self) weakself = self;
    UIButton *doneBtn = [PPButtonHelper pp_buttonWithTitle:kLang(@"done")
                                                      font:[GM fontWithSize:17]
                                                 imageName:@""
                                                    target:nil
                                                    config:[UIButtonConfiguration tintedButtonConfiguration]
                                                    action:nil];
    [doneBtn addAction:[UIAction actionWithHandler:^(UIAction *action) {
        __strong typeof(weakself) strongSelf = weakself;
        if (!strongSelf) return;
        [strongSelf handleBirthDateSelected:picker.date];
        [strongSelf dismissViewControllerAnimated:YES completion:nil];
    }] forControlEvents:UIControlEventTouchUpInside];
    pickerVC.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:doneBtn];

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:pickerVC];
    [PPFunc presentSheetFrom:self sheetVC:nav detentStyle:PPSheetDetentStyleMediumAndLarge];
}

- (void)handleBirthDateSelected:(NSDate *)date {
    self.selectedBirthDate = date;
    self.isDateSelected = YES;
    [self setformDataArray:date forKey:@"BirthDate"];
    [self animatedRebuildFormSections];
}

- (void)fatherRowTapped {
    if (self.fathersCardsArray.count == 0) return;

    __weak typeof(self) weakSelf = self;
    PPSelectOptionViewController *vc =
        [[PPSelectOptionViewController alloc] initWithOptions:self.fathersCardsArray
                                                        title:kLang(@"fatherRingIDPlace")
                                                          row:nil
                                            presentationStyle:PPSelectOptionPresentationSheet
                                                   completion:^(id _Nullable selectedObject) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !selectedObject) return;
        CardModel *ca = (CardModel *)selectedObject;
        strongSelf.selectedFather = ca;
        [strongSelf setformDataArray:ca.ID forKey:@"FatherRingID"];
        [strongSelf animatedRebuildFormSections];
    }];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [PPFunc presentSheetFrom:self sheetVC:nav detentStyle:PPSheetDetentStyle80];
}

- (void)motherRowTapped {
    if (self.mothersCardsArray.count == 0) return;

    __weak typeof(self) weakSelf = self;
    PPSelectOptionViewController *vc =
        [[PPSelectOptionViewController alloc] initWithOptions:self.mothersCardsArray
                                                        title:kLang(@"motherRingIDPlace")
                                                          row:nil
                                            presentationStyle:PPSelectOptionPresentationSheet
                                                   completion:^(id _Nullable selectedObject) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !selectedObject) return;
        CardModel *ca = (CardModel *)selectedObject;
        strongSelf.selectedMother = ca;
        [strongSelf setformDataArray:ca.ID forKey:@"MotherRingID"];
        [strongSelf animatedRebuildFormSections];
    }];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [PPFunc presentSheetFrom:self sheetVC:nav detentStyle:PPSheetDetentStyle80];
}

- (void)sexualSegmentChangedWithIndex:(NSInteger)selectedIndex {
    if (selectedIndex == 1) {
        [self setformDataArray:@1 forKey:@"Sexual"];
    } else {
        [self setformDataArray:@2 forKey:@"Sexual"];
    }
    [self animatedRebuildFormSections];
}

- (void)dnaImageRowTapped {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = (id<UIImagePickerControllerDelegate, UINavigationControllerDelegate>)self;
    picker.allowsEditing = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:nil];

    if (!image) return;

    UIImage *dnaImage = [self normalizedDNAImage:image];
    if (!dnaImage) return;

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyyMMddHHmmss"];
    NSString *dnaImageName = [NSString stringWithFormat:@"%@%@%@%@", userID, [dateFormatter stringFromDate:[NSDate date]], @"DNA", @".jpeg"];

    [self setformDataArray:dnaImage forKey:@"DNAImage"];
    [self setformDataArray:dnaImageName forKey:@"dnaImageName"];

    [self animatedRebuildFormSections];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

// =============================================================================
#pragma mark - UITextViewDelegate
// =============================================================================

- (void)textViewDidChange:(UITextView *)textView {
    [self setformDataArray:textView.text forKey:@"AdDesc"];
    [self.tableView beginUpdates];
    [self.tableView endUpdates];
}

- (void)textViewDidBeginEditing:(UITextView *)textView {
    // Handled by cell
}

- (void)textViewDidEndEditing:(UITextView *)textView {
    [self setformDataArray:textView.text forKey:@"AdDesc"];
}

// =============================================================================
#pragma mark - UITextFieldDelegate
// =============================================================================

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

// =============================================================================
#pragma mark - setClassTpForm (Edit Mode Pre-fill)
// =============================================================================

- (void)setClassTpForm {
    if ([_FromVC isEqual:@"ViewData"] || [_FromVC isEqual:@"main"] || [_FromVC isEqual:@"childs"]) {

        if ([_FromVC isEqual:@"ViewData"] || [_FromVC isEqual:@"main"]) {
            _topTitle.text = kLang(@"topTitleEditCard");
        } else {
            _topTitle.text = kLang(@"topTitleCompleteChild");
        }

        if (self.serverCardClass.FilesArray.count > 0) {
            self.imagesFromStorage = [[NSMutableArray alloc] init];
        }

        // Ring ID
        [self setformDataArray:self.serverCardClass.RingID forKey:@"RingID"];

        // SubKind
        SubKindModel *SubKind = [[self.SubKindsArrayLocal filteredArrayUsingPredicate:
                                  [NSPredicate predicateWithFormat:@"SELF.ID == %ld", self.serverCardClass.SubKind]] firstObject];
        if (SubKind) {
            [self handleSubKindSelected:SubKind];
        }

        // SubSubKind
        subSubKindModel *subSubKindID = [[self.subSubKindsArrayLocal filteredArrayUsingPredicate:
                                          [NSPredicate predicateWithFormat:@"SELF.ID == %ld", self.serverCardClass.subSubKindID]] firstObject];
        if (subSubKindID) {
            [self handleSubSubKindSelected:subSubKindID];
        }

        // Father
        if (![self.serverCardClass.FatherRingID isEqualToString:@"no_value"]) {
            CardModel *FRingID = [[self.allCardsArray filteredArrayUsingPredicate:
                                   [NSPredicate predicateWithFormat:@"SELF.ID == %@", self.serverCardClass.FatherRingID]] firstObject];
            if (FRingID) {
                self.selectedFather = FRingID;
                [self setformDataArray:FRingID.ID forKey:@"FatherRingID"];
            }
        }

        // Mother
        if (![self.serverCardClass.MotherRingID isEqualToString:@"no_value"]) {
            CardModel *MRingID = [[self.allCardsArray filteredArrayUsingPredicate:
                                   [NSPredicate predicateWithFormat:@"SELF.ID == %@", self.serverCardClass.MotherRingID]] firstObject];
            if (MRingID) {
                self.selectedMother = MRingID;
                [self setformDataArray:MRingID.ID forKey:@"MotherRingID"];
            }
        }

        if ([_FromVC isEqual:@"ViewData"] || [_FromVC isEqual:@"main"]) {
            // Classification items
            NSMutableArray<subKindItemsModel *> *selectedItemsModels = [[NSMutableArray alloc] init];
            NSArray *subKindItemsIDs = [self.serverCardClass.subKindItemsID componentsSeparatedByString:@","];

            for (NSString *ItemID in subKindItemsIDs) {
                subKindItemsModel *itemModel = [[self.subKindItemsArrayLocal filteredArrayUsingPredicate:
                                                  [NSPredicate predicateWithFormat:@"SELF.ID == %ld", [ItemID integerValue]]] firstObject];
                if (itemModel) {
                    [selectedItemsModels addObject:itemModel];
                }
            }

            if (selectedItemsModels.count > 0) {
                self.selectedItemsArray = [NSMutableArray array];
                for (subKindItemsModel *item in selectedItemsModels) {
                    [self.selectedItemsArray addObject:@(item.ID)];
                }
                NSString *classification = [self.selectedItemsArray componentsJoinedByString:@","];
                [self setformDataArray:classification forKey:@"Classification"];
                [self setformDataArray:self.selectedItemsArray forKey:@"selectedItemsArray"];
            }

            // Attribute
            if (self.serverCardClass.attribute > 0 && self.serverCardClass.attribute <= (NSInteger)self.attributeArrayLocat.count) {
                NSString *attributeString = [self.attributeArrayLocat objectAtIndex:(self.serverCardClass.attribute - 1)];
                [self handleAttributeSelected:attributeString];
            }

            // Color
            NSString *birdColor = self.serverCardClass.birdColor;
            if (![birdColor isEqualToString:@"no_value"]) {
                [self setformDataArray:birdColor forKey:@"birdColor"];
            }

            // BirthDate
            if (self.serverCardClass.BirthDate) {
                [self handleBirthDateSelected:self.serverCardClass.BirthDate];
            }

            // Sexual
            NSString *Sexual = self.serverCardClass.getBirdSexual;
            if (![Sexual isEqualToString:@"no_value"]) {
                if (self.serverCardClass.Sexual == 1) {
                    [self setformDataArray:@1 forKey:@"Sexual"];
                } else if (self.serverCardClass.Sexual == 2) {
                    [self setformDataArray:@2 forKey:@"Sexual"];
                }
            }

            // ClassificationLoaded items
            selectedItemsModels = [[NSMutableArray alloc] init];
            NSArray *splitIDs = [self.serverCardClass.splitID componentsSeparatedByString:@","];

            if (![self.serverCardClass.splitID isEqualToString:@"no_value"]) {
                for (NSString *ItemID in splitIDs) {
                    subKindItemsModel *ItemModel = [[self.subKindItemsArrayLocal filteredArrayUsingPredicate:
                                                     [NSPredicate predicateWithFormat:@"SELF.ID == %ld", [ItemID integerValue]]] firstObject];
                    if (ItemModel) {
                        [selectedItemsModels addObject:ItemModel];
                    }
                }

                if (selectedItemsModels.count > 0) {
                    self.selectedItemsLoadedArray = [NSMutableArray array];
                    for (subKindItemsModel *item in selectedItemsModels) {
                        [self.selectedItemsLoadedArray addObject:@(item.ID)];
                    }
                    NSString *classLoaded = [self.selectedItemsLoadedArray componentsJoinedByString:@","];
                    [self setformDataArray:classLoaded forKey:@"ClassificationLoaded"];
                    [self setformDataArray:self.selectedItemsLoadedArray forKey:@"selectedItemsLoadedArray"];
                }
            }

            // Description
            if (![self.serverCardClass.AdDesc isEqualToString:@"no_value"]) {
                [self setformDataArray:self.serverCardClass.AdDesc forKey:@"AdDesc"];
            }

            // DNA image
            if (![self.serverCardClass.Dna isEqualToString:@"no_value"]) {
                NSString *str = [NSString stringWithFormat:@"%@/%@", [GM CardsImagesRefStr], self.serverCardClass.Dna];
                FIRStorageReference *starsRef = [self.storageRef child:str];

                __weak typeof(self) weakSelf = self;
                [starsRef downloadURLWithCompletion:^(NSURL *URL, NSError *error) {
                    if (error != nil) return;
                    [[SDWebImageManager sharedManager] loadImageWithURL:URL
                                                                options:0
                                                               progress:nil
                                                              completed:^(UIImage *_Nullable image, NSData *_Nullable data, NSError *_Nullable error, SDImageCacheType cacheType, BOOL finished, NSURL *_Nullable imageURL) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            __strong typeof(weakSelf) strongSelf = weakSelf;
                            if (!strongSelf || !image) return;
                            [strongSelf setformDataArray:image forKey:@"DNAImage"];
                            [strongSelf animatedRebuildFormSections];
                        });
                    }];
                }];
            }
        }

        [self animatedRebuildFormSections];
    }
}

// =============================================================================
#pragma mark - setParentArray_SubKindID:
// =============================================================================

- (void)setParentArray_SubKindID:(NSInteger)subKindID {
    self.CardsdataSource = AppData.UserCardsDocs;

    NSArray<CardModel *> *temCards = [self.CardsdataSource filteredArrayUsingPredicate:
                                      [NSPredicate predicateWithFormat:@"SELF.SubKind == %ld", subKindID]];

    NSPredicate *sPredicate = [NSPredicate predicateWithFormat:@"SELF.Sexual == 2"];
    self.mothersCardsArray = [temCards filteredArrayUsingPredicate:sPredicate];
    sPredicate = [NSPredicate predicateWithFormat:@"SELF.Sexual == 1"];
    self.fathersCardsArray = [temCards filteredArrayUsingPredicate:sPredicate];
}

// =============================================================================
#pragma mark - Helper Methods
// =============================================================================

- (BOOL)isEditingFlow {
    if (!self.serverCardClass) return NO;
    return ([_FromVC isEqual:@"ViewData"] ||
            [_FromVC isEqual:@"main"] ||
            [_FromVC isEqual:@"childs"]);
}

- (BOOL)isNoValueString:(NSString *)value {
    if (![value isKindOfClass:NSString.class]) return YES;
    NSString *trimmed = [[value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    return (trimmed.length == 0 ||
            [trimmed isEqualToString:@"no_value"] ||
            [trimmed isEqualToString:@"null"] ||
            [trimmed isEqualToString:@"(null)"] ||
            [trimmed isEqualToString:@"<null>"] ||
            [trimmed isEqualToString:@"nil"]);
}

- (NSString *)trimmedStringOrNil:(NSString *)value {
    if (![value isKindOfClass:NSString.class]) return nil;
    NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed.length ? trimmed : nil;
}

- (void)syncFormDataWithServerCardIfNeeded {
    if (![self isEditingFlow]) return;

    CardModel *card = self.serverCardClass;
    [self setformDataArray:card.RingID forKey:@"RingID"];
    [self setformDataArray:@(card.SubKind) forKey:@"SubKind"];

    if (card.subSubKindID > 0) {
        [self setformDataArray:@(card.subSubKindID) forKey:@"subSubKindID"];
    }

    if (![self isNoValueString:card.FatherRingID]) {
        [self setformDataArray:card.FatherRingID forKey:@"FatherRingID"];
    }
    if (![self isNoValueString:card.MotherRingID]) {
        [self setformDataArray:card.MotherRingID forKey:@"MotherRingID"];
    }
    if (card.BirthDate) {
        [self setformDataArray:card.BirthDate forKey:@"BirthDate"];
    }
    if (card.Sexual == 1 || card.Sexual == 2) {
        [self setformDataArray:@(card.Sexual) forKey:@"Sexual"];
    }
    if (card.attribute > 0) {
        [self setformDataArray:[NSString stringWithFormat:@"%ld", (long)card.attribute] forKey:@"attribute"];
    }
    if (![self isNoValueString:card.AttributeNote]) {
        [self setformDataArray:card.AttributeNote forKey:@"AttributeNote"];
    }
    if (![self isNoValueString:card.birdColor]) {
        [self setformDataArray:card.birdColor forKey:@"birdColor"];
    }
    if (![self isNoValueString:card.AdDesc]) {
        [self setformDataArray:card.AdDesc forKey:@"AdDesc"];
    }
    if (![self isNoValueString:card.Dna]) {
        [self setformDataArray:card.Dna forKey:@"dnaImageName"];
    }

    NSMutableArray<NSNumber *> *selectedItems = [NSMutableArray array];
    for (NSString *item in [card.subKindItemsID componentsSeparatedByString:@","]) {
        NSInteger itemID = item.integerValue;
        if (itemID > 0) [selectedItems addObject:@(itemID)];
    }
    if (selectedItems.count > 0) {
        [self setformDataArray:selectedItems forKey:@"selectedItemsArray"];
    }

    NSMutableArray<NSNumber *> *selectedSplitItems = [NSMutableArray array];
    for (NSString *item in [card.splitID componentsSeparatedByString:@","]) {
        NSInteger itemID = item.integerValue;
        if (itemID > 0) [selectedSplitItems addObject:@(itemID)];
    }
    if (selectedSplitItems.count > 0) {
        [self setformDataArray:selectedSplitItems forKey:@"selectedItemsLoadedArray"];
    }
}

// =============================================================================
#pragma mark - Form Data Management
// =============================================================================

- (void)setformDataArray:(id)obj forKey:(NSString *)key {
    if (key.length == 0) return;

    if (!self.formDataArray) {
        self.formDataArray = [NSMutableDictionary new];
    }

    if (!obj || obj == [NSNull null]) {
        [self.formDataArray removeObjectForKey:key];
        return;
    }

    if ([obj isKindOfClass:NSString.class]) {
        NSString *value = (NSString *)obj;
        if ([self isNoValueString:value]) {
            [self.formDataArray removeObjectForKey:key];
            return;
        }
    }

    id oldValue = [self.formDataArray objectForKey:key];
    if (!self.isHydratingFormData && ![oldValue isEqual:obj]) {
        self.hasUserModifiedForm = YES;
    }

    [self.formDataArray setObject:obj forKey:key];
}

- (void)removeDataArrayObjects:(NSArray *)objArray {
    for (NSString *key in objArray) {
        if (!self.isHydratingFormData && [self.formDataArray objectForKey:key] != nil) {
            self.hasUserModifiedForm = YES;
        }
        [self.formDataArray removeObjectForKey:key];
    }
}

- (id)getformDataForKey:(NSString *)key withType:(int)type {
    id value = [self.formDataArray objectForKey:key];
    if (value && value != [NSNull null]) {
        return value;
    } else {
        return type == 0 ? @(0) : [NSString stringWithFormat:@"no_value"];
    }
}

// =============================================================================
#pragma mark - PPImageCollectionDelegate
// =============================================================================

- (void)prefillPhotosForEdit {
    if (self.serverCardClass.imagesUrls.count == 0) return;

    self.isHydratingImages = YES;
    __weak typeof(self) weakSelf = self;
    [self.imageCollection preloadImagesFromURLs:self.serverCardClass.imagesUrlsStrings completion:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.isHydratingImages = NO;
        strongSelf.didChangeImages = NO;
    }];
}

- (void)imageCollection:(PPImageCollection *)collection didUpdateImages:(NSArray<UIImage *> *)images {
    if (!self.isHydratingImages) {
        self.didChangeImages = YES;
    }
}

- (void)imageCollection:(PPImageCollection *)collection didSelectImage:(nonnull UIImage *)selectedImage AtIndex:(NSInteger)index {
    [collection presentEditorForImageAtIndex:index fromViewController:self];
}

- (void)imageCollectionDidRequestAddImage:(PPImageCollection *)collection {
    [collection presentPickerFromViewController:self];
}

// =============================================================================
#pragma mark - Image Collection Setup
// =============================================================================

- (void)setupImageCollection {
    CGFloat horizontalPad = kPPCardCellHorizontalInset;
    CGFloat availableWidth = self.view.bounds.size.width - horizontalPad * 2.0;
    PPImageCollection *ic = [[PPImageCollection alloc] initWithFrame:CGRectMake(horizontalPad, 0, availableWidth, 200)];
    ic.maxImageCount = 10;
    ic.delegate = self;
    ic.allowsVideoSelection = PPReusableVideoMediaEnabled();
    self.imageCollection = ic;

    // Wrap in a container to provide horizontal padding inside the table footer
    UIView *footerContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 200)];
    footerContainer.backgroundColor = UIColor.clearColor;
    [footerContainer addSubview:ic];
    self.tableView.tableFooterView = footerContainer;

    if ([self isEditingFlow]) {
        [self prefillPhotosForEdit];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// =============================================================================
#pragma mark - Draft System
// =============================================================================

// Draft constants defined at top of file

- (NSString *)draftStorageKey {
    NSString *currentUserID = PPSafeString(UserManager.sharedManager.currentUser.ID);
    if ([self isEditingFlow] && self.serverCardClass.ID.length) {
        return [NSString stringWithFormat:@"%@.edit.%@.%@",
                kNewCardDraftDefaultsPrefix,
                self.serverCardClass.ID,
                currentUserID];
    }
    return [NSString stringWithFormat:@"%@.new.%@",
            kNewCardDraftDefaultsPrefix,
            currentUserID];
}

- (NSString *)draftDirectoryPath {
    NSString *draftID = [[[self draftStorageKey]
                          stringByReplacingOccurrencesOfString:@"." withString:@"_"]
                         stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:@"pp_form_drafts"];
    return [root stringByAppendingPathComponent:draftID];
}

- (NSData *)archivedDraftDataForObject:(id)object {
    if (!object) return nil;

    if (@available(iOS 11.0, *)) {
        NSError *archiveError = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object
                                             requiringSecureCoding:NO
                                                             error:&archiveError];
        if (archiveError) {
            NSLog(@"Failed to archive new card draft: %@", archiveError.localizedDescription);
        }
        return data;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [NSKeyedArchiver archivedDataWithRootObject:object];
#pragma clang diagnostic pop
}

- (id)unarchivedDraftObjectFromData:(NSData *)data {
    if (![data isKindOfClass:NSData.class] || data.length == 0) return nil;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [NSKeyedUnarchiver unarchiveObjectWithData:data];
#pragma clang diagnostic pop
}

- (NSDictionary *)draftFormDataSnapshot {
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];
    NSDictionary *source = [self.formDataArray copy] ?: @{};

    [source enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        (void)stop;
        if (![key isKindOfClass:NSString.class]) return;
        if ([key isEqualToString:@"DNAImage"]) return;
        if (!obj || obj == [NSNull null]) return;

        if ([obj isKindOfClass:NSString.class]) {
            NSString *value = [(NSString *)obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (!value.length ||
                [value.lowercaseString isEqualToString:@"no_value"] ||
                [value.lowercaseString isEqualToString:@"null"] ||
                [value.lowercaseString isEqualToString:@"<null>"] ||
                [value.lowercaseString isEqualToString:@"(null)"] ||
                [value.lowercaseString isEqualToString:@"nil"]) {
                return;
            }
        }
        snapshot[key] = obj;
    }];

    if (userID.length) {
        snapshot[@"UserID"] = userID;
    }
    if (PPCurrentUser.UserName.length) {
        snapshot[@"OwnerName"] = PPCurrentUser.UserName;
    }
    return snapshot.copy;
}

- (NSString *)writeDraftImage:(UIImage *)image
                        named:(NSString *)fileName
                    directory:(NSString *)directory {
    if (!image || !fileName.length || !directory.length) return nil;

    NSData *imageData = UIImageJPEGRepresentation(image, 0.88);
    if (!imageData) imageData = UIImagePNGRepresentation(image);
    if (!imageData) return nil;

    NSString *path = [directory stringByAppendingPathComponent:fileName];
    return [imageData writeToFile:path atomically:YES] ? path : nil;
}

- (NSArray<NSString *> *)writeDraftImages:(NSArray<UIImage *> *)images
                               withPrefix:(NSString *)prefix
                                directory:(NSString *)directory {
    if (images.count == 0) return @[];

    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    [images enumerateObjectsUsingBlock:^(UIImage *image, NSUInteger idx, BOOL *stop) {
        (void)stop;
        NSString *fileName = [NSString stringWithFormat:@"%@_%lu.jpg", prefix, (unsigned long)idx];
        NSString *path = [self writeDraftImage:image named:fileName directory:directory];
        if (path.length) [paths addObject:path];
    }];
    return paths.copy;
}

- (NSArray<UIImage *> *)imagesFromDraftPaths:(NSArray<NSString *> *)paths {
    NSMutableArray<UIImage *> *images = [NSMutableArray array];
    for (NSString *path in paths) {
        if (![path isKindOfClass:NSString.class] || path.length == 0) continue;
        UIImage *image = [UIImage imageWithContentsOfFile:path];
        if (image) [images addObject:image];
    }
    return images.copy;
}

- (void)showDraftSnackbarMessage:(NSString *)message {
    if (message.length == 0) return;

    self.snakBar = [[TTGSnackbar alloc] initWithMessage:message duration:1.6];
    [self.snakBar setAnimationType:TTGSnackbarAnimationTypeSlideFromBottomBackToBottom];
    self.snakBar.messageTextAlign = NSTextAlignmentCenter;
    self.snakBar.cornerRadius = 18;
    [self.snakBar setIconTintColor:AppForgroundColr];
    [self.snakBar show];
}

- (void)clearSavedDraft {
    NSString *directory = [self draftDirectoryPath];
    [[NSFileManager defaultManager] removeItemAtPath:directory error:nil];
    [self.prefs removeObjectForKey:[self draftStorageKey]];
    [self.prefs synchronize];
}

- (void)saveDraftForLater {
    NSDictionary *snapshot = [self draftFormDataSnapshot];
    NSString *directory = [self draftDirectoryPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    [fileManager removeItemAtPath:directory error:nil];
    [fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];

    NSArray<NSString *> *galleryPaths = [self writeDraftImages:[self.imageCollection allImages]
                                                    withPrefix:@"gallery"
                                                     directory:directory];

    NSString *dnaImagePath = nil;
    UIImage *dnaImage = [self.formDataArray objectForKey:@"DNAImage"];
    if ([dnaImage isKindOfClass:UIImage.class]) {
        dnaImagePath = [self writeDraftImage:dnaImage named:@"dna.jpg" directory:directory];
    }

    NSData *archivedSnapshot = [self archivedDraftDataForObject:snapshot];
    if (!archivedSnapshot) return;

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[kNewCardDraftFormDataKey] = archivedSnapshot;
    payload[kNewCardDraftGalleryPathsKey] = galleryPaths ?: @[];
    if (dnaImagePath.length) {
        payload[kNewCardDraftDNAPathKey] = dnaImagePath;
    }

    [self.prefs setObject:payload.copy forKey:[self draftStorageKey]];
    [self.prefs synchronize];
}

- (NSArray<subKindItemsModel *> *)draftItemModelsFromIDs:(NSArray *)storedIDs {
    if (![storedIDs isKindOfClass:NSArray.class] || storedIDs.count == 0) return @[];

    NSMutableArray<subKindItemsModel *> *items = [NSMutableArray array];
    for (id rawValue in storedIDs) {
        NSInteger itemID = [rawValue integerValue];
        subKindItemsModel *match =
            [[self.subKindItemsArrayLocal filteredArrayUsingPredicate:
              [NSPredicate predicateWithFormat:@"SELF.ID == %ld", itemID]] firstObject];
        if (match) [items addObject:match];
    }
    return items.copy;
}

- (void)restoreDraftIfNeeded {
    NSDictionary *payload = [self.prefs objectForKey:[self draftStorageKey]];
    if (![payload isKindOfClass:NSDictionary.class]) return;

    NSData *archivedSnapshot = payload[kNewCardDraftFormDataKey];
    NSDictionary *storedSnapshot = [self unarchivedDraftObjectFromData:archivedSnapshot];
    if (![storedSnapshot isKindOfClass:NSDictionary.class] || storedSnapshot.count == 0) {
        [self clearSavedDraft];
        return;
    }

    self.isHydratingFormData = YES;
    NSMutableDictionary *mergedValues = [self.formDataArray mutableCopy] ?: [NSMutableDictionary dictionary];
    [mergedValues addEntriesFromDictionary:storedSnapshot];
    self.formDataArray = mergedValues;

    // SubKind
    NSNumber *subKindID = storedSnapshot[@"SubKind"];
    if ([subKindID respondsToSelector:@selector(integerValue)]) {
        SubKindModel *subKind =
            [[self.SubKindsArrayLocal filteredArrayUsingPredicate:
              [NSPredicate predicateWithFormat:@"SELF.ID == %ld", subKindID.integerValue]] firstObject];
        if (subKind) {
            [self handleSubKindSelected:subKind];
        }
    }

    // SubSubKind
    NSNumber *subSubKindIDVal = storedSnapshot[@"subSubKindID"];
    if ([subSubKindIDVal respondsToSelector:@selector(integerValue)]) {
        subSubKindModel *subSubKind =
            [[self.subSubKindsArrayLocal filteredArrayUsingPredicate:
              [NSPredicate predicateWithFormat:@"SELF.ID == %ld", subSubKindIDVal.integerValue]] firstObject];
        if (subSubKind) {
            [self handleSubSubKindSelected:subSubKind];
        }
    }

    // Classification
    NSArray *classificationIDs = storedSnapshot[@"selectedItemsArray"];
    if ([classificationIDs isKindOfClass:NSArray.class] && classificationIDs.count > 0) {
        self.selectedItemsArray = [classificationIDs mutableCopy];
        NSString *classification = [self.selectedItemsArray componentsJoinedByString:@","];
        [self setformDataArray:classification forKey:@"Classification"];
        [self setformDataArray:self.selectedItemsArray forKey:@"selectedItemsArray"];
    }

    // Attribute
    NSInteger attributeIndex = [storedSnapshot[@"attribute"] integerValue];
    if (attributeIndex > 0 && attributeIndex <= (NSInteger)self.attributeArrayLocat.count) {
        NSString *attributeValue = self.attributeArrayLocat[attributeIndex - 1];
        [self handleAttributeSelected:attributeValue];
    }

    // BirthDate
    NSDate *birthDate = storedSnapshot[@"BirthDate"];
    if ([birthDate isKindOfClass:NSDate.class]) {
        [self handleBirthDateSelected:birthDate];
    }

    // Father
    NSString *fatherID = PPSafeString(storedSnapshot[@"FatherRingID"]);
    if (fatherID.length) {
        CardModel *father =
            [[self.allCardsArray filteredArrayUsingPredicate:
              [NSPredicate predicateWithFormat:@"SELF.ID == %@", fatherID]] firstObject];
        if (father) {
            self.selectedFather = father;
            [self setformDataArray:father.ID forKey:@"FatherRingID"];
        }
    }

    // Mother
    NSString *motherID = PPSafeString(storedSnapshot[@"MotherRingID"]);
    if (motherID.length) {
        CardModel *mother =
            [[self.allCardsArray filteredArrayUsingPredicate:
              [NSPredicate predicateWithFormat:@"SELF.ID == %@", motherID]] firstObject];
        if (mother) {
            self.selectedMother = mother;
            [self setformDataArray:mother.ID forKey:@"MotherRingID"];
        }
    }

    // Sexual
    NSInteger sexualValue = [storedSnapshot[@"Sexual"] integerValue];
    if (sexualValue == 1 || sexualValue == 2) {
        [self setformDataArray:@(sexualValue) forKey:@"Sexual"];
    }

    // ClassificationLoaded
    NSArray *loadedClassificationIDs = storedSnapshot[@"selectedItemsLoadedArray"];
    if ([loadedClassificationIDs isKindOfClass:NSArray.class] && loadedClassificationIDs.count > 0) {
        self.selectedItemsLoadedArray = [loadedClassificationIDs mutableCopy];
        NSString *classLoaded = [self.selectedItemsLoadedArray componentsJoinedByString:@","];
        [self setformDataArray:classLoaded forKey:@"ClassificationLoaded"];
        [self setformDataArray:self.selectedItemsLoadedArray forKey:@"selectedItemsLoadedArray"];
    }

    // DNA Image
    NSString *dnaImagePath = PPSafeString(payload[kNewCardDraftDNAPathKey]);
    if (dnaImagePath.length) {
        UIImage *dnaImage = [UIImage imageWithContentsOfFile:dnaImagePath];
        if (dnaImage) {
            [self setformDataArray:dnaImage forKey:@"DNAImage"];
            NSString *dnaImageName = PPSafeString(storedSnapshot[@"dnaImageName"]);
            if (dnaImageName.length) {
                [self setformDataArray:dnaImageName forKey:@"dnaImageName"];
            }
        }
    }

    // Gallery images
    NSArray<NSString *> *storedGalleryPaths = payload[kNewCardDraftGalleryPathsKey];
    if ([storedGalleryPaths isKindOfClass:NSArray.class]) {
        NSArray<UIImage *> *galleryImages = [self imagesFromDraftPaths:storedGalleryPaths];
        self.isHydratingImages = YES;
        [self.imageCollection clearAllImages];
        if (galleryImages.count > 0) {
            [self.imageCollection addImages:galleryImages];
        }
        self.isHydratingImages = NO;
    }

    self.hasUserModifiedForm = NO;
    self.didChangeImages = NO;
    self.isHydratingFormData = NO;
    [self showDraftSnackbarMessage:kLang(@"form_draft_restored")];
}

- (void)presentUnsavedChangesPromptFromBarButtonItem:(UIBarButtonItem *)buttonItem {
    (void)buttonItem;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"form_draft_prompt_title")
                                                                   message:kLang(@"form_draft_prompt_message")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    alert.view.tintColor = [GM appPrimaryColor];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"form_draft_save_and_close")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf saveDraftForLater];
        [strongSelf.prefs setInteger:0 forKey:@"FromForm"];
        [strongSelf closeSelfController];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"form_draft_discard")
                                              style:UIAlertActionStyleDestructive
                                            handler:^(__unused UIAlertAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf clearSavedDraft];
        [strongSelf.prefs setInteger:0 forKey:@"FromForm"];
        [strongSelf closeSelfController];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"form_draft_keep_editing")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

// =============================================================================
#pragma mark - Validation
// =============================================================================

- (NSString *)differentParentsValidationMessage {
    return Language.isRTL
        ? @"يجب اختيار اب وام مختلفين."
        : @"Father and mother must be different birds.";
}

- (NSString *)selfParentValidationMessageForRole:(NSString *)role {
    if (Language.isRTL) {
        if ([role isEqualToString:@"father"]) {
            return @"لا يمكن للطير ان يكون ابا لنفسه.";
        }
        return @"لا يمكن للطير ان يكون اما لنفسه.";
    }

    if ([role isEqualToString:@"father"]) {
        return @"A bird cannot be its own father.";
    }
    return @"A bird cannot be its own mother.";
}

- (BOOL)validateBeforeUpload {
    NSString *ring = [self trimmedStringOrNil:[self getformDataForKey:@"RingID" withType:1]];
    if ([self isNoValueString:ring]) {
        [PPAlertHelper showWarningIn:self title:kLang(@"warningTitle") subtitle:kLang(@"RingIDPlace")];
        [self animateView:[self cellForFieldTag:@"RingID"]];
        return NO;
    }
    [self setformDataArray:ring forKey:@"RingID"];

    id storedBirthDate = [self getformDataForKey:@"BirthDate" withType:1];
    NSDate *birthDateVal = [storedBirthDate isKindOfClass:NSDate.class] ? storedBirthDate : self.selectedBirthDate;
    if ([birthDateVal isKindOfClass:NSDate.class] && [birthDateVal timeIntervalSinceNow] > 0) {
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        [PPAlertHelper showWarningIn:self
                               title:kLang(@"warningTitle")
                            subtitle:kLang(@"BirthDatePlace")];
        [self animateView:[self cellForFieldTag:@"BirthDate"]];
        return NO;
    }

    NSString *fatherID = [self getformDataForKey:@"FatherRingID" withType:1];
    NSString *motherID = [self getformDataForKey:@"MotherRingID" withType:1];

    if (![self isNoValueString:fatherID] &&
        ![self isNoValueString:motherID] &&
        [fatherID isEqualToString:motherID]) {
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        [PPAlertHelper showWarningIn:self
                               title:kLang(@"warningTitle")
                            subtitle:[self differentParentsValidationMessage]];
        [self animateView:[self cellForFieldTag:@"FatherRingID"]];
        [self animateView:[self cellForFieldTag:@"MotherRingID"]];
        return NO;
    }

    if ([self isEditingFlow] && self.serverCardClass.ID.length) {
        if (![self isNoValueString:fatherID] && [fatherID isEqualToString:self.serverCardClass.ID]) {
            [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
            [PPAlertHelper showWarningIn:self
                                   title:kLang(@"warningTitle")
                                subtitle:[self selfParentValidationMessageForRole:@"father"]];
            return NO;
        }
        if (![self isNoValueString:motherID] && [motherID isEqualToString:self.serverCardClass.ID]) {
            [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
            [PPAlertHelper showWarningIn:self
                                   title:kLang(@"warningTitle")
                                subtitle:[self selfParentValidationMessageForRole:@"mother"]];
            return NO;
        }
    }

    return YES;
}

- (BOOL)validateRequiredFields {
    NSString *ring = [self trimmedStringOrNil:[self getformDataForKey:@"RingID" withType:1]];
    if ([self isNoValueString:ring]) {
        [self animateView:[self cellForFieldTag:@"RingID"]];
        return NO;
    }

    NSNumber *subKind = [self getformDataForKey:@"SubKind" withType:0];
    if ([subKind integerValue] <= 0) {
        [self animateView:[self cellForFieldTag:@"SubKind"]];
        return NO;
    }

    id birthDateVal = [self getformDataForKey:@"BirthDate" withType:1];
    if (![birthDateVal isKindOfClass:NSDate.class]) {
        [self animateView:[self cellForFieldTag:@"BirthDate"]];
        return NO;
    }

    NSInteger sexual = [[self getformDataForKey:@"Sexual" withType:0] integerValue];
    if (sexual != 1 && sexual != 2) {
        [self animateView:[self cellForFieldTag:@"Sexual"]];
        return NO;
    }

    return YES;
}

// =============================================================================
#pragma mark - Save / Upload
// =============================================================================

- (void)saveForm:(id)buttonItem {
    [self saveBarButton];
}

- (void)saveBarButton {
    if (self.isSaving) return;

    if (![self validateRequiredFields]) {
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }

    if (![self validateBeforeUpload]) {
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }

    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
    self.isSaving = YES;
    [self sendForDataToServer];
}

- (void)sendForDataToServer {
    [self.view endEditing:YES];

    BOOL isEditing = [self isEditingFlow];
    CardModel *editingCard = self.serverCardClass;

    NSString *RingID = [self trimmedStringOrNil:[self getformDataForKey:@"RingID" withType:1]];
    if (!RingID.length && isEditing) {
        RingID = [self trimmedStringOrNil:editingCard.RingID];
    }
    if (!RingID.length) {
        [self restoreFormAfterUploadAttempt];
        return;
    }

    NSInteger SubKind = [[self getformDataForKey:@"SubKind" withType:0] integerValue];
    if (SubKind <= 0 && isEditing) SubKind = editingCard.SubKind;

    NSInteger subSubKindID = [[self getformDataForKey:@"subSubKindID" withType:0] integerValue];
    if (subSubKindID <= 0 && isEditing) subSubKindID = editingCard.subSubKindID;

    NSString *attribute = [NSString stringWithFormat:@"%@", [self getformDataForKey:@"attribute" withType:1]];
    if ([self isNoValueString:attribute] && isEditing) {
        attribute = [NSString stringWithFormat:@"%ld", (long)editingCard.attribute];
    }
    if ([self isNoValueString:attribute]) attribute = @"0";

    NSString *birdColor = [self getformDataForKey:@"birdColor" withType:1];
    if ([self isNoValueString:birdColor] && isEditing) birdColor = editingCard.birdColor;
    if ([self isNoValueString:birdColor]) birdColor = no_value;

    id birthDateObj = [self getformDataForKey:@"BirthDate" withType:1];
    NSDate *BirthDate = [birthDateObj isKindOfClass:NSDate.class] ? birthDateObj : nil;
    if (!BirthDate && isEditing) BirthDate = editingCard.BirthDate;
    if (!BirthDate) BirthDate = [NSDate date];

    NSString *FatherRingID = [self getformDataForKey:@"FatherRingID" withType:1];
    if ([self isNoValueString:FatherRingID] && isEditing) FatherRingID = editingCard.FatherRingID;
    if ([self isNoValueString:FatherRingID]) FatherRingID = no_value;

    NSString *MotherRingID = [self getformDataForKey:@"MotherRingID" withType:1];
    if ([self isNoValueString:MotherRingID] && isEditing) MotherRingID = editingCard.MotherRingID;
    if ([self isNoValueString:MotherRingID]) MotherRingID = no_value;

    NSInteger Sexual = [[self getformDataForKey:@"Sexual" withType:0] integerValue];
    if ((Sexual != 1 && Sexual != 2) && isEditing && (editingCard.Sexual == 1 || editingCard.Sexual == 2)) {
        Sexual = editingCard.Sexual;
    }

    NSString *Dna = [self getformDataForKey:@"dnaImageName" withType:1];
    if ([self isNoValueString:Dna] && isEditing) Dna = editingCard.Dna;
    if ([self isNoValueString:Dna]) Dna = no_value;

    NSString *AdDesc = [self getformDataForKey:@"AdDesc" withType:1];
    if ([self isNoValueString:AdDesc] && isEditing) AdDesc = editingCard.AdDesc;
    if ([self isNoValueString:AdDesc]) AdDesc = no_value;

    NSString *AttributeNote = [self getformDataForKey:@"AttributeNote" withType:1];
    if ([self isNoValueString:AttributeNote] && isEditing) AttributeNote = editingCard.AttributeNote;
    if ([self isNoValueString:AttributeNote]) AttributeNote = no_value;

    NSString *userIDVal = [self getformDataForKey:@"UserID" withType:1];
    if ([self isNoValueString:userIDVal] && isEditing) userIDVal = editingCard.UserID;
    if ([self isNoValueString:userIDVal]) userIDVal = UserManager.sharedManager.currentUser.ID ?: no_value;

    id subKindItemsObj = [self getformDataForKey:@"selectedItemsArray" withType:1];
    NSString *subKindItemsID = [subKindItemsObj isKindOfClass:NSArray.class]
        ? [subKindItemsObj componentsJoinedByString:@","]
        : no_value;
    if ([self isNoValueString:subKindItemsID] && isEditing) subKindItemsID = editingCard.subKindItemsID;
    if ([self isNoValueString:subKindItemsID]) subKindItemsID = no_value;

    id subKindItemsLoadedObj = [self getformDataForKey:@"selectedItemsLoadedArray" withType:1];
    NSString *splitID = [subKindItemsLoadedObj isKindOfClass:NSArray.class]
        ? [subKindItemsLoadedObj componentsJoinedByString:@","]
        : no_value;
    if ([self isNoValueString:splitID] && isEditing) splitID = editingCard.splitID;
    if ([self isNoValueString:splitID]) splitID = no_value;

    NSArray<UIImage *> *images = [self.imageCollection allImages];

    NSDate *AddedDate = [NSDate date];
    NSDateFormatter *CardFormatter = [[NSDateFormatter alloc] init];
    [CardFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en"]];
    [CardFormatter setDateFormat:@"ddMMHHmmssSSS"];
    NSString *CardIDDate = [CardFormatter stringFromDate:[NSDate date]];
    NSString *CardID = [NSString stringWithFormat:@"%@_%@", RingID, CardIDDate];

    NSMutableDictionary *Dic = [NSMutableDictionary new];
    [Dic setValue:CardID forKey:@"ID"];
    [Dic setValue:RingID forKey:@"RingID"];
    [Dic setValue:@(SubKind) forKey:@"SubKind"];
    [Dic setValue:@(subSubKindID) forKey:@"subSubKindID"];
    [Dic setValue:subKindItemsID forKey:@"subKindItemsID"];
    [Dic setValue:splitID forKey:@"splitID"];
    [Dic setValue:@([attribute integerValue]) forKey:@"attribute"];
    [Dic setValue:AttributeNote forKey:@"AttributeNote"];
    [Dic setValue:@(Sexual) forKey:@"Sexual"];
    [Dic setValue:birdColor forKey:@"birdColor"];
    [Dic setValue:BirthDate forKey:@"BirthDate"];
    [Dic setValue:FatherRingID forKey:@"FatherRingID"];
    [Dic setValue:MotherRingID forKey:@"MotherRingID"];
    [Dic setValue:Dna forKey:@"Dna"];
    [Dic setValue:AdDesc forKey:@"AdDesc"];
    [Dic setValue:AddedDate forKey:@"AddedDate"];
    [Dic setValue:userIDVal forKey:@"UserID"];
    [Dic setValue:@"not_set" forKey:@"CardLocation"];
    [Dic setValue:@(1) forKey:@"cardInfo"];
    [Dic setValue:@"no_value" forKey:@"loanForUser"];
    [Dic setValue:@(0) forKey:@"isSold"];
    [Dic setValue:@"" forKey:@"soldPrice"];
    [Dic setValue:[FIRFieldValue fieldValueForServerTimestamp] forKey:@"lastUpdated"];
    [Dic setValue:@(CardSectionCards) forKey:@"cardSection"];

    if ([_FromVC isEqual:@"childs"]) {
        [Dic setValue:@(2) forKey:@"cardInfo"];
        [Dic setValue:@"new_child" forKey:@"CardLocation"];
        [Dic setValue:@(CardSectionNewChild) forKey:@"cardSection"];
    }

    typeof(self) __weak weakself = self;

    if (isEditing) {
        CardID = self.serverCardClass.ID;
        [Dic setValue:self.serverCardClass.ID forKey:@"ID"];
        [Dic setValue:self.serverCardClass.CardLocation forKey:@"CardLocation"];
        [Dic setValue:self.serverCardClass.CageID forKey:@"CageID"];
        [Dic setValue:@(self.serverCardClass.cardInfo) forKey:@"cardInfo"];
        [Dic setValue:self.serverCardClass.archiveID forKey:@"archiveID"];
        [Dic setValue:self.serverCardClass.masterArchiveID forKey:@"masterArchiveID"];
        [Dic setValue:@(self.serverCardClass.isSold) forKey:@"isSold"];
        [Dic setValue:PPSafeString(self.serverCardClass.soldPrice) forKey:@"soldPrice"];
        [Dic setValue:@(self.serverCardClass.cardSection) forKey:@"cardSection"];

        if ([_FromVC isEqual:@"ViewData"] || [_FromVC isEqual:@"main"]) {
            [Dic removeObjectForKey:@"AddedDate"];
        }

        self.currentIndex = 0;
        [self startUploadFiles];
        [self uploadFiles:Dic CardID:CardID];
        return;
    }

    if ([self RingIDExist]) {
        [PPAlertHelper showConfirmationIn:self
                                     title:_alertWarningDataTitle
                                  subtitle:_alertWarningDataSubTitle
                             confirmButton:kLang(@"yes")
                              cancelButton:kLang(@"cancel")
                                      icon:nil
                               confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
            if (!didConfirm) {
                [weakself restoreFormAfterUploadAttempt];
                return;
            }
            weakself.currentIndex = 0;
            [weakself startUploadFiles];
            [weakself uploadFiles:Dic CardID:CardID];
        }
                                cancelBlock:^{
            [weakself restoreFormAfterUploadAttempt];
        }];
    } else {
        self.currentIndex = 0;
        [self startUploadFiles];
        [self uploadFiles:Dic CardID:CardID];
    }
}

- (void)uploadData:(NSMutableDictionary *)Dic CardID:(NSString *)CardID {
    __weak typeof(self) weakSelf = self;
    [self uploadDNAImageIfNeededWithCompletion:^(NSError * _Nullable dnaError) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (dnaError) {
            [strongSelf processUploadCompleteWithError:YES CardID:CardID];
            return;
        }

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            FIRFirestore *db = [FIRFirestore firestore];
            FIRDocumentReference *docRef = [[db collectionWithPath:@"CardsCol"] documentWithPath:CardID];

            [docRef setData:Dic merge:YES
                 completion:^(NSError *_Nullable error) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf processUploadCompleteWithError:(error != nil) CardID:CardID];
            }];
        });
    }];
}

- (void)processUploadCompleteWithError:(BOOL)error CardID:(NSString *)CardID {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [PPHUD dismiss];
        [strongSelf restoreFormAfterUploadAttempt];
        strongSelf->formFinishupload = error ? 0 : 1;

        if (error) {
            [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
            [PPAlertHelper showWarningIn:strongSelf
                                   title:strongSelf->alertTitleError ?: kLang(@"alertTitleError")
                                subtitle:strongSelf->alertSubtitleError ?: kLang(@"alertSubtitleError")
                             completion:^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (strongSelf) [strongSelf closeSelfController];
            }];
        } else {
            [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentSuccess];
            [PPAlertHelper showSuccessIn:strongSelf title:strongSelf.alertTitleDone subtitle:strongSelf.alertSubtitleDone confirmAction:^(NSString * _Nullable text, BOOL didConfirm) {
                if(!didConfirm) return;
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf clearSavedDraft];
                [strongSelf.prefs setInteger:1 forKey:@"FromForm"];
                [strongSelf.delegate refreshView];
                [strongSelf closeSelfController];
            } cancelAction:^{
            }];
        }
    });
}

- (NSDictionary *)dictionaryFromFilesArray:(NSMutableArray<FileModel *> *)filesArray {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    for (FileModel *file in filesArray) {
        [dictionary setObject:file forKey:@(file.ID)];
    }
    return [dictionary copy];
}

- (NSMutableArray<FileModel *> *)pp_fileModelsFromMediaUploadResult:(PPMediaUploadResult *)result
                                                             cardID:(NSString *)cardID
{
    NSMutableArray<FileModel *> *files = [NSMutableArray arrayWithCapacity:result.mixedMetadata.count];
    NSInteger index = 0;
    for (NSDictionary *metadata in result.mixedMetadata) {
        if (![metadata isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSString *rawMediaType = [metadata[@"media_type"] isKindOfClass:NSString.class] ? metadata[@"media_type"] : @"image";
        NSString *mediaType = rawMediaType.lowercaseString;
        NSString *url = [metadata[@"url"] isKindOfClass:NSString.class] ? metadata[@"url"] : @"";
        if (url.length == 0) {
            continue;
        }

        FileModel *file = [FileModel new];
        file.ID = [metadata[@"order"] respondsToSelector:@selector(integerValue)] ? [metadata[@"order"] integerValue] : index;
        file.FileType = [mediaType isEqualToString:@"video"] ? 1 : 0;
        file.FileUrl = url;
        file.FirImageUrl = [NSURL URLWithString:url];
        file.CardID = cardID ?: @"";
        file.FileName = [metadata[@"storage_path"] isKindOfClass:NSString.class] ? metadata[@"storage_path"] : @"";
        file.videoDuration = [metadata[@"duration"] respondsToSelector:@selector(floatValue)] ? [metadata[@"duration"] floatValue] : 0.0;
        if (file.FileType == 1) {
            file.CoverUrl = [metadata[@"thumbnail_url"] isKindOfClass:NSString.class] ? metadata[@"thumbnail_url"] : @"";
            file.CoverName = [metadata[@"thumbnail_storage_path"] isKindOfClass:NSString.class] ? metadata[@"thumbnail_storage_path"] : @"";
        }
        [files addObject:file];
        index += 1;
    }
    return files;
}

- (NSString *)pp_cardMediaStorageFolderForCardID:(NSString *)cardID
{
    NSString *safeCardID = cardID.length > 0 ? cardID : NSUUID.UUID.UUIDString;
    return [NSString stringWithFormat:@"CardsCol/%@", safeCardID];
}

- (void)uploadFiles:(NSMutableDictionary *)Dic CardID:(NSString *)CardID {
    NSArray<UIImage *> *images = [self.imageCollection allImages];

    if ([self isEditingFlow] && !self.didChangeImages) {
        NSArray *existingFiles = [self.serverCardClass.FilesArray modelToJSONObject] ?: @[];
        [Dic setValue:existingFiles forKey:@"FilesArray"];
        [self uploadData:Dic CardID:CardID];
        return;
    }

    if (images.count == 0 && [self isEditingFlow]) {
        [Dic setValue:@[] forKey:@"FilesArray"];
        [self uploadData:Dic CardID:CardID];
        return;
    }

    if ([self.imageCollection hasSelectedVideos]) {
        NSString *ownerID = UserManager.sharedManager.currentUser.ID ?: @"unknown";
        [self.imageCollection uploadSelectedMediaWithStorageFolder:[self pp_cardMediaStorageFolderForCardID:CardID]
                                                           ownerID:ownerID
                                                         contextID:CardID
                                                        completion:^(PPMediaUploadResult * _Nullable result, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error || !result) {
                    [self processUploadCompleteWithError:YES CardID:CardID];
                    return;
                }
                NSMutableArray<FileModel *> *filesArray = [self pp_fileModelsFromMediaUploadResult:result cardID:CardID];
                if (filesArray.count == 0) {
                    [self processUploadCompleteWithError:YES CardID:CardID];
                    return;
                }
                [Dic setValue:[filesArray modelToJSONObject] forKey:@"FilesArray"];
                [self uploadData:Dic CardID:CardID];
            });
        }];
        return;
    }

    [self.uploadManager uploadFilesfromArray:images.mutableCopy
                                   completion:^(NSMutableArray<FileModel *> *filesArray, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [self processUploadCompleteWithError:YES CardID:CardID];
                return;
            }

            [Dic setValue:[filesArray modelToJSONObject] forKey:@"FilesArray"];
            [self uploadData:Dic CardID:CardID];
        });
    }];
}

- (void)startUploadFiles {
    if (!self.uploadProgressView) {
        GSIndeterminateProgressView *pv = [[GSIndeterminateProgressView alloc] initWithFrame:CGRectMake(0, self.navigationController.navigationBar.hx_maxy, self.view.hx_w, 4)];
        pv.progressTintColor = [[GM appPrimaryColor] colorWithAlphaComponent:0.1];
        pv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        pv.backgroundColor = UIColor.whiteColor;
        [self.view addSubview:pv];
        self.uploadProgressView = pv;
    }

    self.navigationItem.leftBarButtonItem.enabled = NO;
    alertTitleLoad = @"الرجاء الانتظار";
    alertSubtitleLoad = @"تتم الان عملية انشاء البطاقة للطير";
    [PPHUD showLoading:alertTitleLoad subtitle:alertSubtitleLoad];
    [self.uploadProgressView startAnimating];
    [self.saveButton setEnabled:NO];
    [self.tableView setUserInteractionEnabled:NO];
}

- (void)restoreFormAfterUploadAttempt {
    self.isSaving = NO;
    [self.saveButton setEnabled:YES];
    self.navigationItem.leftBarButtonItem.enabled = YES;
    [self.tableView setUserInteractionEnabled:YES];
    [self.uploadProgressView stopAnimating];
    [PPHUD dismiss];
}

- (BOOL)RingIDExist {
    NSString *UserID = [self getformDataForKey:@"UserID" withType:1];
    NSInteger SubKind = [[self getformDataForKey:@"SubKind" withType:0] integerValue];
    NSString *RingID = [self trimmedStringOrNil:[self getformDataForKey:@"RingID" withType:1]];
    if (RingID.length == 0) return NO;

    for (CardModel *card in AppData.UserCardsDocs) {
        if ([card.UserID isEqualToString:UserID] &&
            card.SubKind == SubKind &&
            [card.RingID caseInsensitiveCompare:RingID] == NSOrderedSame &&
            !([self isEditingFlow] && [card.ID isEqualToString:self.serverCardClass.ID])) {
            NSString *subKindTitle = alertSubKindIDText ?: @"";
            NSString *ringTitle = alertRingIDText ?: RingID;
            _alertWarningDataTitle = [NSString stringWithFormat:@"%@ (%@) %@ (%@)", kLang(@"youHaveBird"), subKindTitle, kLang(@"withRingId"), ringTitle];
            _alertWarningDataSubTitle = [NSString stringWithFormat:@"%@", kLang(@"YouWannaDeleteIT")];
            return TRUE;
        }
    }

    return FALSE;
}

- (BOOL)PhotoAdded {
    NSArray<UIImage *> *images = [self.imageCollection allImages];
    return images.count > 0;
}

- (void)setAlertLoaded {
    _uploadProgressV = [[UIActivityIndicatorView alloc]
                        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    [_uploadProgressV setColor:[GM appPrimaryColor]];
    _uploadProgressV.center = CGPointMake(self.view.bounds.size.width / 2,
                                          self.view.bounds.size.height / 2);
    [self.view addSubview:_uploadProgressV];
}

// =============================================================================
#pragma mark - Age Calculation
// =============================================================================

- (NSString *)ageFromBirthday:(NSDate *)birthdate adultHood:(NSInteger)adultHood {
    NSString *monthString = kLang(@"month");
    NSString *yearString = kLang(@"year");
    NSString *redyString = kLang(@"readyToMarrage");
    NSString *ageString = kLang(@"age");
    NSString *stringDate;
    NSDate *today = [NSDate date];
    NSDateComponents *ageComponents = [[NSCalendar currentCalendar] components:NSCalendarUnitMonth
                                                                      fromDate:birthdate
                                                                        toDate:today
                                                                       options:0];

    if (ageComponents.month < 12) {
        stringDate = [NSString stringWithFormat:@"%@ (%ld) %@ %@", ageString, (long)ageComponents.month, monthString, ageComponents.month >= adultHood ? redyString : @""];
        return stringDate;
    } else if (ageComponents.month == 12) {
        stringDate = [NSString stringWithFormat:@"(1) %@ %@", yearString, redyString];
        return stringDate;
    } else {
        NSInteger aboveMonths = ageComponents.month % 12;
        NSInteger allMonths = ageComponents.month;

        if (ageComponents.month % 12 == 0) {
            ageComponents = [[NSCalendar currentCalendar] components:NSCalendarUnitYear
                                                            fromDate:birthdate
                                                              toDate:today
                                                             options:0];

            stringDate = [NSString stringWithFormat:@"(%ld) %@ %@", (long)ageComponents.year, yearString, allMonths >= adultHood ? redyString : @""];
            return stringDate;
        } else {
            ageComponents = [[NSCalendar currentCalendar] components:NSCalendarUnitYear
                                                            fromDate:birthdate
                                                              toDate:today
                                                             options:0];

            stringDate = [NSString stringWithFormat:@"(%ld) %@ (%ld) %@ %@", (long)ageComponents.year, yearString, (long)aboveMonths, monthString, allMonths >= adultHood ? redyString : @""];
            return stringDate;
        }

        return stringDate;
    }
}

// =============================================================================
#pragma mark - DNA Image Helpers
// =============================================================================

- (void)sendDnaImage:(UIImage *)DNAImage ImageName:(NSString *)ImageName {
    FIRStorageReference *mountainRef = [[GM CardsImagesRefrence] child:ImageName];
    NSData *imageData = UIImageJPEGRepresentation(DNAImage, 0.6);
    FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] init];
    metadata.contentType = @"image/jpeg";

    FIRStorageUploadTask *uploadTask = [mountainRef putData:imageData metadata:metadata];

    [uploadTask observeStatus:FIRStorageTaskStatusSuccess
                      handler:^(FIRStorageTaskSnapshot *_Nonnull snapshotMeta) {
    }];
}

- (UIImage *)normalizedDNAImage:(UIImage *)image {
    if (![image isKindOfClass:UIImage.class]) {
        return nil;
    }

    UIImage *resized = [self resizedImage:image withMaxDimension:2000.0];
    return resized ?: image;
}

- (void)uploadDNAImageIfNeededWithCompletion:(void (^)(NSError * _Nullable error))completion {
    UIImage *dnaImage = [self.formDataArray objectForKey:@"DNAImage"];
    NSString *imageName = [self.formDataArray objectForKey:@"dnaImageName"];

    if (![dnaImage isKindOfClass:UIImage.class] || imageName.length == 0) {
        if (completion) completion(nil);
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            UIImage *normalizedImage = [self normalizedDNAImage:dnaImage];
            NSData *imageData = UIImageJPEGRepresentation(normalizedImage, 0.72);
            if (imageData.length == 0) {
                NSError *error = [NSError errorWithDomain:@"com.purepets.cards"
                                                     code:-1001
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Failed to encode DNA image."}];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(error);
                });
                return;
            }

            FIRStorageReference *mountainRef = [[GM CardsImagesRefrence] child:imageName];
            FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] init];
            metadata.contentType = @"image/jpeg";

            [mountainRef putData:imageData metadata:metadata completion:^(FIRStorageMetadata * _Nullable returnedMeta, NSError * _Nullable error) {
                (void)returnedMeta;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(error);
                });
            }];
        }
    });
}

- (UIImage *)resizedImage:(UIImage *)image withMaxDimension:(CGFloat)maxDimension {
    CGFloat scale = 1.0;

    if (image.size.width > maxDimension || image.size.height > maxDimension) {
        scale = MIN(maxDimension / image.size.width, maxDimension / image.size.height);
    }

    CGSize newSize = CGSizeMake(image.size.width * scale, image.size.height * scale);
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resizedImage;
}

// =============================================================================
#pragma mark - Animation & UI Helpers
// =============================================================================

- (void)animateView:(UIView *)view {
    if (!view) return;
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animation];
    animation.keyPath = @"position.x";
    animation.values =  @[ @0, @20, @-20, @10, @0 ];
    animation.keyTimes = @[ @0, @(1 / 6.0), @(3 / 6.0), @(5 / 6.0), @1 ];
    animation.duration = 0.3;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    animation.additive = YES;
    [view.layer addAnimation:animation forKey:@"shake"];

    [PPHUD dismiss];
}

- (void)animateCell:(UIView *)cell {
    [self animateView:cell];
}

- (void)showNoNetworkAlert {
    FCAlertView *alert = [[FCAlertView alloc] init];

    alert.colorScheme = [GM appPrimaryColor];
    alert.tintColor = [GM appPrimaryColor];
    alert.firstButtonTitleColor = GM.appPrimaryColor;
    [alert  showAlertInView:self
                  withTitle:kLang(@"noInternetTitle")
               withSubtitle:kLang(@"noInternetSubTitle")
            withCustomImage:nil
        withDoneButtonTitle:kLang(@"ok")
                 andButtons:nil];
}

// =============================================================================
#pragma mark - Navigation / Lifecycle
// =============================================================================

- (void)changeColor {
    self.navigationController.navigationBar.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;

    UIBarButtonItem *closebutton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:Language.isRTL ? @"arrow.right" : @"arrow.left"]
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(closeForm:)];
    self.navigationItem.leftBarButtonItem = closebutton;

    self.saveButton = [PPButtonHelper pp_buttonWithTitle:kLang(@"save")
                                                    font:[GM fontWithSize:17]
                                               imageName:@""
                                                  target:self
                                                  config:[UIButtonConfiguration tintedButtonConfiguration]
                                                  action:@selector(saveForm:)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.saveButton];
}

- (void)closeForm:(UIBarButtonItem *)buttonItem {
    if (self.isSaving) return;
    [self.view endEditing:YES];
    BOOL shouldPromptDiscard = (self.hasUserModifiedForm || self.didChangeImages) && formFinishupload == 0;
    if (shouldPromptDiscard) {
        [self presentUnsavedChangesPromptFromBarButtonItem:buttonItem];
        return;
    }

    [PPHUD dismiss];
    [self.prefs setInteger:0 forKey:@"FromForm"];
    [self closeSelfController];
}

- (void)closeBTN:(id)sender {
    [self closeForm:nil];
}

- (void)closeSelfController {
    if (self.navigationController) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self changeColor];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [PPHUD dismiss];

    if (self.isMovingFromParentViewController || self.isBeingDismissed) {
        [self.imageCollection clearAllImages];
    }
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];

    if (!self.uploadProgressView) {
        GSIndeterminateProgressView *pv = [[GSIndeterminateProgressView alloc] initWithFrame:CGRectMake(0, self.navigationController.navigationBar.hx_maxy, self.view.hx_w, 4)];
        pv.progressTintColor = [[GM appPrimaryColor] colorWithAlphaComponent:0.1];
        pv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        pv.backgroundColor = UIColor.whiteColor;
        [self.view addSubview:pv];
        self.uploadProgressView = pv;
    }
    [self.view bringSubviewToFront:self.uploadProgressView];
}

@end
