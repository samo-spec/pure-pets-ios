#import "AddNewAd.h"
#import "PPImageCollection.h"
#import "PPMenuHelper.h"
#import "LocationPickerViewController.h"
#import "ZYCircleProgressView.h"
#import "PPSelectOptionViewController.h"
#import <Pure_Pets-Swift.h>
#import <ImageIO/ImageIO.h>
#import <math.h>
#import <float.h>
@import FirebaseAuth;
@import FirebaseFirestore;
@import FirebaseStorage;

static NSString * const PPAddNewAdUploadErrorDomain = @"PPAddNewAdUploadErrorDomain";
static NSString * const PPAddNewAdLanguageDidChangeNotification = @"LanguageDidChangeNotification";
static NSString * const PPAddNewAdDraftDefaultsPrefix = @"pp.add_pet_ad.draft";
static NSString * const PPAddNewAdDraftFormDataKey = @"formData";
static NSString * const PPAddNewAdDraftImagePathsKey = @"imagePaths";
static NSString * const PPAddNewAdDraftMediaMutatedKey = @"didMutateMedia";
static CGFloat const PPAddNewAdDraftImageMaxPixelSize = 1800.0;

static NSString * const PPAdTextFieldCellID  = @"PPAdTextFieldCell";
static NSString * const PPAdSelectorCellID   = @"PPAdSelectorCell";
static NSString * const PPAdSwitchCellID     = @"PPAdSwitchCell";
static NSString * const PPAdTextViewCellID   = @"PPAdTextViewCell";

static inline BOOL PPIsValidAdCoordinate(CLLocationCoordinate2D coordinate) {
    if (!isfinite(coordinate.latitude) || !isfinite(coordinate.longitude)) return NO;
    if (coordinate.latitude < -90.0 || coordinate.latitude > 90.0) return NO;
    if (coordinate.longitude < -180.0 || coordinate.longitude > 180.0) return NO;
    if (fabs(coordinate.latitude) < DBL_EPSILON && fabs(coordinate.longitude) < DBL_EPSILON) return NO;
    return YES;
}

static const CGFloat kPPAdCellHorizontalInset = 20.0;
static const CGFloat kPPAdCellVerticalInset   = 10.0;

static inline UIColor *PPAdFormAccentColor(void) {
    return AppPrimaryClr ?: UIColor.systemOrangeColor;
}

static inline UIColor *PPAdFormPrimaryTextColor(void) {
    return AppPrimaryTextClr ?: UIColor.labelColor;
}

static inline UIColor *PPAdFormSurfaceColor(void) {
    return [AppBackgroundClrLigter colorWithAlphaComponent:0.88];
}

static inline UIColor *PPAdFormMutedSurfaceColor(void) {
    return [AppForgroundColr colorWithAlphaComponent:0.92];
}

static inline UIColor *PPAdFormBorderColor(void) {
    return [UIColor colorWithRed:0.25 green:0.17 blue:0.18 alpha:0.08];
}

static inline UISemanticContentAttribute PPAdCurrentSemanticAttribute(void) {
    return Language.isRTL
        ? UISemanticContentAttributeForceRightToLeft
        : UISemanticContentAttributeForceLeftToRight;
}

static inline NSTextAlignment PPAdCurrentTextAlignment(void) {
    return Language.alignmentForCurrentLanguage;
}

static inline NSString *PPAdForwardSymbolName(void) {
    return Language.isRTL ? @"arrow.left" : @"arrow.right";
}

@interface PPAdBaseCell : UITableViewCell
- (void)applyDisabledState:(BOOL)disabled;
@end

@implementation PPAdBaseCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.clipsToBounds = NO;
        self.contentView.clipsToBounds = NO;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.semanticContentAttribute = PPAdCurrentSemanticAttribute();
        self.contentView.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    }
    return self;
}

- (void)setFrame:(CGRect)frame
{
    frame.origin.x = kPPAdCellHorizontalInset;
    frame.size.width -= kPPAdCellHorizontalInset * 2.0;
    frame.origin.y += kPPAdCellVerticalInset * 0.5;
    frame.size.height -= kPPAdCellVerticalInset;
    if (frame.size.width  < 0.0) frame.size.width  = 0.0;
    if (frame.size.height < 0.0) frame.size.height = 0.0;
    [super setFrame:frame];
}

- (void)applyDisabledState:(BOOL)disabled
{
    self.contentView.alpha = disabled ? 0.58 : 1.0;
}

@end

#pragma mark - PPAdFormField

typedef NS_ENUM(NSInteger, PPAdFieldType) {
    PPAdFieldTypeText,
    PPAdFieldTypeInteger,
    PPAdFieldTypeSelector,
    PPAdFieldTypeSwitch,
    PPAdFieldTypeTextView
};

@interface PPAdFormField : NSObject
@property (nonatomic, copy) NSString *tag;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *placeholder;
@property (nonatomic, strong) id value;
@property (nonatomic, assign) PPAdFieldType fieldType;
@property (nonatomic, assign) BOOL required;
@property (nonatomic, assign) BOOL disabled;
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, strong) NSArray *selectorOptions;
@property (nonatomic, copy) NSString *selectorTitle;
@property (nonatomic, copy) void(^onChangeBlock)(id oldValue, id newValue);
@end

@implementation PPAdFormField
- (instancetype)init {
    self = [super init];
    if (self) { _height = 52.0; _required = NO; _disabled = NO; }
    return self;
}
@end

#pragma mark - PPAdTextFieldCell

@interface PPAdTextFieldCell : PPAdBaseCell <UITextFieldDelegate>
@property (nonatomic, strong) PPInsetLabel *titleLabel;
@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, copy) void(^onValueChanged)(NSString *text);
@end

@implementation PPAdTextFieldCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _titleLabel = [[PPInsetLabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        _titleLabel.textColor = PPAdFormPrimaryTextColor();
        _titleLabel.textAlignment = PPAdCurrentTextAlignment();
        _titleLabel.textInsets = UIEdgeInsetsMake(3, 3, 3, 3);
        [self.contentView addSubview:_titleLabel];

        _textField = [[UITextField alloc] init];
        _textField.translatesAutoresizingMaskIntoConstraints = NO;
        _textField.font = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
        _textField.textColor = PPAdFormPrimaryTextColor();
        _textField.textAlignment = PPAdCurrentTextAlignment();
        _textField.semanticContentAttribute = PPAdCurrentSemanticAttribute();
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

- (void)configureWithField:(PPAdFormField *)field {
    self.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    self.titleLabel.text = field.title;
    self.titleLabel.textAlignment = PPAdCurrentTextAlignment();
    self.textField.textAlignment = PPAdCurrentTextAlignment();
    self.textField.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    
    UIColor *placeholderColor = [UIColor.placeholderTextColor colorWithAlphaComponent:0.75];
    self.textField.attributedPlaceholder = field.placeholder.length
        ? [[NSAttributedString alloc] initWithString:field.placeholder
                                         attributes:@{NSForegroundColorAttributeName: placeholderColor}]
        : nil;
    self.textField.enabled = !field.disabled;
    if (field.fieldType == PPAdFieldTypeInteger) {
        self.textField.keyboardType = UIKeyboardTypeNumberPad;
        self.textField.text = field.value ? [NSString stringWithFormat:@"%@", field.value] : @"";
    } else {
        self.textField.keyboardType = UIKeyboardTypeDefault;
        self.textField.text = [field.value isKindOfClass:NSString.class] ? field.value : @"";
    }
    [self applyDisabledState:field.disabled];
}

- (void)textFieldDidChange:(UITextField *)textField {
    if (self.onValueChanged) self.onValueChanged(textField.text);
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}
@end

#pragma mark - PPAdSelectorCell

@interface PPAdSelectorCell : PPAdBaseCell
@property (nonatomic, strong) UILabel *fieldTitleLabel;
@property (nonatomic, strong) UILabel *valueLabel;
@property (nonatomic, strong) UIImageView *chevronView;
@end

@implementation PPAdSelectorCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _fieldTitleLabel = [[UILabel alloc] init];
        _fieldTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _fieldTitleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        _fieldTitleLabel.textColor = PPAdFormPrimaryTextColor();
        _fieldTitleLabel.textAlignment = PPAdCurrentTextAlignment();
        [self.contentView addSubview:_fieldTitleLabel];

        _valueLabel = [[UILabel alloc] init];
        _valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _valueLabel.font = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
        _valueLabel.textColor = PPAdFormPrimaryTextColor();
        _valueLabel.textAlignment = PPAdCurrentTextAlignment();
        [self.contentView addSubview:_valueLabel];

        _chevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:PPAdForwardSymbolName()]];
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

- (void)configureWithField:(PPAdFormField *)field {
    self.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    self.fieldTitleLabel.text = field.title;
    self.fieldTitleLabel.textAlignment = PPAdCurrentTextAlignment();
    self.valueLabel.textAlignment = PPAdCurrentTextAlignment();
    self.chevronView.image = [UIImage systemImageNamed:PPAdForwardSymbolName()];
    NSString *displayValue = nil;
    if (field.value) {
        if ([field.value isKindOfClass:NSString.class]) {
            displayValue = (NSString *)field.value;
        } else if ([field.value respondsToSelector:@selector(formDisplayText)]) {
            displayValue = [field.value performSelector:@selector(formDisplayText)];
        } else if ([field.value respondsToSelector:@selector(KindName)]) {
            displayValue = [field.value performSelector:@selector(KindName)];
        } else if ([field.value respondsToSelector:@selector(SubKindName)]) {
            displayValue = [field.value performSelector:@selector(SubKindName)];
        } else {
            displayValue = [NSString stringWithFormat:@"%@", field.value];
        }
    }
    if (displayValue.length > 0) {
        self.valueLabel.text = displayValue;
        self.valueLabel.textColor = PPAdFormAccentColor();
    } else {
        self.valueLabel.text = field.placeholder ?: field.selectorTitle;
        self.valueLabel.textColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.68];
    }
    self.userInteractionEnabled = !field.disabled;
    [self applyDisabledState:field.disabled];
}
@end

#pragma mark - PPAdSwitchCell

@interface PPAdSwitchCell : PPAdBaseCell
@property (nonatomic, strong) UILabel *fieldTitleLabel;
@property (nonatomic, strong) UISwitch *toggleSwitch;
@property (nonatomic, copy) void(^onSwitchChanged)(BOOL isOn);
@end

@implementation PPAdSwitchCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _fieldTitleLabel = [[UILabel alloc] init];
        _fieldTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _fieldTitleLabel.font = [GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
        _fieldTitleLabel.textColor = PPAdFormPrimaryTextColor();
        _fieldTitleLabel.textAlignment = PPAdCurrentTextAlignment();
        [self.contentView addSubview:_fieldTitleLabel];

        _toggleSwitch = [[UISwitch alloc] init];
        _toggleSwitch.onTintColor = PPAdFormAccentColor();
        _toggleSwitch.translatesAutoresizingMaskIntoConstraints = NO;
        [_toggleSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        [self.contentView addSubview:_toggleSwitch];

        [NSLayoutConstraint activateConstraints:@[
            [_fieldTitleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
            [_fieldTitleLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_fieldTitleLabel.heightAnchor constraintGreaterThanOrEqualToConstant:12.0],
            
            [_toggleSwitch.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
            [_toggleSwitch.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_fieldTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_toggleSwitch.leadingAnchor constant:-12.0],
            [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:72.0]
        ]];
    }
    return self;
}

- (void)configureWithField:(PPAdFormField *)field {
    self.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    self.fieldTitleLabel.text = field.title;
    self.fieldTitleLabel.textAlignment = PPAdCurrentTextAlignment();
    self.toggleSwitch.on = [field.value boolValue];
    self.toggleSwitch.enabled = !field.disabled;
    [self applyDisabledState:field.disabled];
}

- (void)switchChanged:(UISwitch *)sender {
    if (self.onSwitchChanged) self.onSwitchChanged(sender.isOn);
}
@end

#pragma mark - PPAdTextViewCell

@interface PPAdTextViewCell : PPAdBaseCell <UITextViewDelegate>
@property (nonatomic, strong) UILabel *fieldTitleLabel;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (nonatomic, copy) void(^onTextChanged)(NSString *text);
@end

@implementation PPAdTextViewCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _fieldTitleLabel = [[UILabel alloc] init];
        _fieldTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _fieldTitleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        _fieldTitleLabel.textColor = PPAdFormPrimaryTextColor();
        _fieldTitleLabel.textAlignment = PPAdCurrentTextAlignment();
        [self.contentView addSubview:_fieldTitleLabel];

        _textView = [[UITextView alloc] init];
        _textView.translatesAutoresizingMaskIntoConstraints = NO;
        _textView.font = [GM MidFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
        _textView.textColor = PPAdFormPrimaryTextColor();
        _textView.backgroundColor = UIColor.clearColor;
        _textView.textAlignment = PPAdCurrentTextAlignment();
        _textView.semanticContentAttribute = PPAdCurrentSemanticAttribute();
        _textView.textContainerInset = UIEdgeInsetsZero;
        _textView.textContainer.lineFragmentPadding = 0.0;
        _textView.delegate = self;
        _textView.scrollEnabled = NO;
        [self.contentView addSubview:_textView];

        _placeholderLabel = [[UILabel alloc] init];
        _placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _placeholderLabel.font = _textView.font;
        _placeholderLabel.textColor = [UIColor.placeholderTextColor colorWithAlphaComponent:0.72];
        _placeholderLabel.textAlignment = PPAdCurrentTextAlignment();
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

- (void)configureWithField:(PPAdFormField *)field {
    self.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    self.fieldTitleLabel.text = field.title ?: kLang(@"enter_description");
    self.fieldTitleLabel.textAlignment = PPAdCurrentTextAlignment();
    self.textView.textAlignment = PPAdCurrentTextAlignment();
    self.textView.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    self.textView.text = [field.value isKindOfClass:NSString.class] ? field.value : @"";
    self.placeholderLabel.text = field.placeholder;
    self.placeholderLabel.textAlignment = PPAdCurrentTextAlignment();
    self.placeholderLabel.hidden = (self.textView.text.length > 0);
    self.textView.editable = !field.disabled;
    [self applyDisabledState:field.disabled];
}

- (void)textViewDidChange:(UITextView *)textView {
    self.placeholderLabel.hidden = (textView.text.length > 0);
    if (self.onTextChanged) self.onTextChanged(textView.text);
}
@end

@interface AddNewAd ()<UISheetPresentationControllerDelegate,UITextFieldDelegate,PPImageCollectionDelegate>
// form + data
@property (nonatomic, strong) NSMutableArray<NSMutableArray<PPAdFormField *> *> *formSections;
@property (nonatomic, strong) FileUploadManager *uploadManager;

@property (nonatomic, strong) PetAd *adModel;
@property (nonatomic, strong) MainKindsModel *selectedKind;
@property (assign) BOOL presented;
@property (nonatomic, weak) UIView *ppFloatingBar;
@property (nonatomic, weak) UIButton *ppFloatingBarDoneButton;

@property (nonatomic, strong) NSArray<PetImageItem *> *finalImageItems;
@property (nonatomic, strong) UIBarButtonItem *ppUploadSpinnerItem;
@property (nonatomic, strong) UIBarButtonItem *ppOriginalRightItem;
@property (nonatomic, strong) UIActivityIndicatorView *ppUploadSpinner;
@property (nonatomic, strong) PPPhotoBrowserBridge *photoBrowserBridge;
@property (nonatomic, strong) UIView *prefillLoadingView;
@property (nonatomic, strong) UIActivityIndicatorView *prefillLoadingSpinner;
@property (nonatomic, strong) UILabel *prefillLoadingLabel;
@property (nonatomic, strong) UIView *uploadProgressOverlay;
@property (nonatomic, strong) ZYCircleProgressView *uploadCircleProgressView;
@property (nonatomic, strong) UILabel *uploadProgressValueLabel;
@property (nonatomic, strong) UILabel *uploadProgressTitleLabel;
@property (nonatomic, strong) UIView *backgroundGlowViewTop;
@property (nonatomic, strong) UIView *backgroundGlowViewBottom;
@property (nonatomic, strong) UIView *formHeroContainerView;
@property (nonatomic, strong) UIView *formHeroCardView;
@property (nonatomic, strong) UILabel *formHeroEyebrowLabel;
@property (nonatomic, strong) UILabel *formHeroTitleLabel;
@property (nonatomic, strong) UILabel *formHeroSubtitleLabel;
@property (nonatomic, strong) UILabel *formHeroMetaLabel;
@property (nonatomic, strong) UIView *imageCollectionFooterContainerView;
@property (nonatomic, assign) BOOL isSubmittingAd;
@property (nonatomic, assign) BOOL isPrefillInProgress;
@property (nonatomic, copy) NSString *createFlowAdID;
@property (nonatomic, assign) BOOL didMutateMediaAfterPrefill;
@property (nonatomic, assign) BOOL hasUserModifiedForm;
@property (nonatomic, assign) BOOL isHydratingFormData;
@property (nonatomic, assign) BOOL isHydratingMedia;
@property (nonatomic, assign) BOOL formDisabled;
@property (nonatomic, assign) CGFloat lastAppliedFormHeroHeaderHeight;
@property (nonatomic, assign) CGFloat lastAppliedFormHeroHeaderWidth;
@property (nonatomic, assign) CGFloat lastAppliedImageCollectionFooterWidth;
@end


@implementation AddNewAd

- (UIColor *)pp_adCanvasColor
{
    return [UIColor colorWithRed:0.969 green:0.961 blue:0.949 alpha:1.0];
}

- (UIColor *)pp_adSurfaceColor
{
    return PPAdFormSurfaceColor();
}

- (UIColor *)pp_adSurfaceBorderColor
{
    return PPAdFormBorderColor();
}

- (void)pp_applyAdCanvasBackground
{
    UIColor *canvasColor = [self pp_adCanvasColor];
    self.view.backgroundColor = canvasColor;
    self.view.opaque = YES;
    self.navigationController.view.backgroundColor = canvasColor;

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


- (UIBarButtonItem *)pp_uploadSpinnerBarItem
{
    if (self.ppUploadSpinnerItem) {
        return self.ppUploadSpinnerItem;
    }

    UIActivityIndicatorViewStyle style =
        UIActivityIndicatorViewStyleMedium;

    UIActivityIndicatorView *spinner =
        [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:style];

    spinner.color = AppPrimaryClr;
    spinner.hidesWhenStopped = YES;
    [spinner startAnimating];

    self.ppUploadSpinner = spinner;
    self.ppUploadSpinnerItem =
        [[UIBarButtonItem alloc] initWithCustomView:spinner];

    return self.ppUploadSpinnerItem;
}


- (instancetype)initWithCoordinator:(id)coordinator {
      self = [super initWithStyle:UITableViewStyleGrouped];
      if (self) {
          _coordinator = coordinator;
      }
      return self;
  }


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - viewDidLoad (Fixed)

- (void)viewDidLoad {
    [super viewDidLoad];
    self.presented=NO;
    self.lastAppliedFormHeroHeaderHeight = 0.0;
    self.lastAppliedFormHeroHeaderWidth = 0.0;
    self.lastAppliedImageCollectionFooterWidth = 0.0;
    self.isHydratingFormData = YES;
    self.isHydratingMedia = NO;
    self.hasUserModifiedForm = NO;
    self.view.semanticContentAttribute = PPAdCurrentSemanticAttribute();

    [self initBase];
    [self initForm];
    [self setBackAndCorners];
    [self pp_applyAdCanvasBackground];
    [self setupImageCollection];
    [self setupPrefillLoadingUI];
    [self setupUploadProgressUI];
    [self setupModernBackdrop];
    [self setupFormHeroHeader];
    [self pp_updateFormHeroHeaderLayoutIfNeeded];
    self.photoBrowserBridge = [PPPhotoBrowserBridge new];
    self.photoBrowserBridge.useArabic = Language.isRTL;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleLanguageDidChange:)
                                               name:PPAddNewAdLanguageDidChangeNotification
                                               object:nil];
    [self pp_refreshMediaLocalizedText];
    [self pp_refreshFormHeroContent];
    if (![self restoreDraftIfNeeded]) {
        [self configureForEditingIfNeeded];
    }
    self.isHydratingFormData = NO;
    [self pp_refreshFormHeroContent];
    
    
    // PPImageCollection owns editor notifications and picker handling.
}

#pragma mark - Media Access (PPImageCollection)

- (NSString *)pp_localizedStringForKey:(NSString *)key fallback:(NSString *)fallback
{
    NSString *value = key.length ? kLang(key) : nil;
    if (![value isKindOfClass:NSString.class] || value.length == 0 || [value isEqualToString:key]) {
        return fallback ?: @"";
    }
    return value;
}

- (void)pp_refreshMediaLocalizedText
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_refreshMediaLocalizedText];
        });
        return;
    }

    self.photoBrowserBridge.useArabic = Language.isRTL;
    self.imageCollection.useArabic = Language.isRTL;
    self.imageCollection.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    NSString *title = [self pp_localizedStringForKey:@"add.images.here"
                                             fallback:@"Add images here"];
    [self.imageCollection setTitle:title icon:nil];
}

- (void)pp_setSubmitEnabled:(BOOL)enabled
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.ppOriginalRightItem) {
            self.ppOriginalRightItem.enabled = enabled;
        }
        self.navigationItem.rightBarButtonItem.enabled = enabled;
    });
}

- (void)pp_setMediaLoadingVisible:(BOOL)visible
                          textKey:(NSString *)textKey
                         fallback:(NSString *)fallback
{
    NSString *text = [self pp_localizedStringForKey:textKey fallback:fallback];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.prefillLoadingLabel.text = text;
        [self setPrefillLoadingVisible:visible];
    });
}

- (void)pp_handleLanguageDidChange:(NSNotification *)note
{
    (void)note;
    self.view.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    self.tableView.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    self.imageCollectionFooterContainerView.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    [self pp_refreshMediaLocalizedText];
    self.uploadProgressTitleLabel.text = [self pp_localizedStringForKey:@"uploading_images" fallback:@"Uploading images..."];
    [self pp_refreshFormHeroContent];
    [self.tableView reloadData];
    [self pp_updateImageCollectionFooterLayoutIfNeeded];
}

- (NSArray<UIImage *> *)safeMediaOutputArray {
    return [self.imageCollection allImages] ?: @[];
}

- (NSInteger)safeMediaOutputCount {
    return [self.imageCollection imageCount];
}

- (void)safeAddImage:(UIImage *)image {
    [self.imageCollection addImage:image];
}

- (void)safeReplaceImageAtIndex:(NSInteger)index withImage:(UIImage *)image {
    [self.imageCollection replaceImageAtIndex:index withImage:image];
}

- (void)safeRemoveImageAtIndex:(NSInteger)index {
    [self.imageCollection removeImageAtIndex:index];
}

- (void)safeClearAllImages {
    [self.imageCollection clearAllImages];
}

- (void)setupPrefillLoadingUI
{
    self.prefillLoadingView = [[UIView alloc] init];
    self.prefillLoadingView.translatesAutoresizingMaskIntoConstraints = NO;
    self.prefillLoadingView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
    self.prefillLoadingView.layer.cornerRadius = 12;
    self.prefillLoadingView.layer.masksToBounds = YES;
    self.prefillLoadingView.hidden = YES;

    self.prefillLoadingSpinner =
        [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.prefillLoadingSpinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.prefillLoadingSpinner.color = UIColor.whiteColor;

    self.prefillLoadingLabel = [[UILabel alloc] init];
    self.prefillLoadingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.prefillLoadingLabel.font = [GM MidFontWithSize:12];
    self.prefillLoadingLabel.textColor = UIColor.whiteColor;
    NSString *loadingText = kLang(@"loading_images");
    self.prefillLoadingLabel.text = loadingText.length ? loadingText : kLang(@"Loading");

    [self.prefillLoadingView addSubview:self.prefillLoadingSpinner];
    [self.prefillLoadingView addSubview:self.prefillLoadingLabel];
    [self.view addSubview:self.prefillLoadingView];

    [NSLayoutConstraint activateConstraints:@[
        [self.prefillLoadingView.centerXAnchor constraintEqualToAnchor:self.imageCollection.centerXAnchor],
        [self.prefillLoadingView.centerYAnchor constraintEqualToAnchor:self.imageCollection.centerYAnchor],
        [self.prefillLoadingSpinner.leadingAnchor constraintEqualToAnchor:self.prefillLoadingView.leadingAnchor constant:10],
        [self.prefillLoadingSpinner.centerYAnchor constraintEqualToAnchor:self.prefillLoadingView.centerYAnchor],
        [self.prefillLoadingLabel.leadingAnchor constraintEqualToAnchor:self.prefillLoadingSpinner.trailingAnchor constant:8],
        [self.prefillLoadingLabel.trailingAnchor constraintEqualToAnchor:self.prefillLoadingView.trailingAnchor constant:-10],
        [self.prefillLoadingLabel.topAnchor constraintEqualToAnchor:self.prefillLoadingView.topAnchor constant:8],
        [self.prefillLoadingLabel.bottomAnchor constraintEqualToAnchor:self.prefillLoadingView.bottomAnchor constant:-8]
    ]];
}

- (void)setupUploadProgressUI
{
    UIView *overlay = [[UIView alloc] init];
    overlay.translatesAutoresizingMaskIntoConstraints = NO;
    overlay.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.62];
    overlay.layer.cornerRadius = 16.0;
    overlay.layer.masksToBounds = YES;
    overlay.userInteractionEnabled = NO;
    overlay.hidden = YES;

    ZYCircleProgressView *circleView = [[ZYCircleProgressView alloc] init];
    circleView.translatesAutoresizingMaskIntoConstraints = NO;
    [circleView updateConfig:^(ZYCircleProgressViewConfig *config) {
        config.lineWidth = 8.0;
        config.backLineColor = [[UIColor whiteColor] colorWithAlphaComponent:0.25];
        config.progressLineColor = AppPrimaryClr;
    }];
    circleView.progress = 0.0;

    UILabel *valueLabel = [[UILabel alloc] init];
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.font = [GM MidFontWithSize:16];
    valueLabel.textColor = UIColor.whiteColor;
    valueLabel.textAlignment = NSTextAlignmentCenter;
    valueLabel.text = @"0%";

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM MidFontWithSize:12];
    titleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.92];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.text = [self pp_localizedStringForKey:@"uploading_images" fallback:@"Uploading images..."];

    [overlay addSubview:circleView];
    [overlay addSubview:valueLabel];
    [overlay addSubview:titleLabel];
    [self.view addSubview:overlay];

    self.uploadProgressOverlay = overlay;
    self.uploadCircleProgressView = circleView;
    self.uploadProgressValueLabel = valueLabel;
    self.uploadProgressTitleLabel = titleLabel;

    [NSLayoutConstraint activateConstraints:@[
        [overlay.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [overlay.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor constant:-20.0],
        [overlay.widthAnchor constraintEqualToConstant:168.0],
        [overlay.heightAnchor constraintEqualToConstant:176.0],

        [circleView.centerXAnchor constraintEqualToAnchor:overlay.centerXAnchor],
        [circleView.topAnchor constraintEqualToAnchor:overlay.topAnchor constant:18.0],
        [circleView.widthAnchor constraintEqualToConstant:86.0],
        [circleView.heightAnchor constraintEqualToConstant:86.0],

        [valueLabel.centerXAnchor constraintEqualToAnchor:circleView.centerXAnchor],
        [valueLabel.centerYAnchor constraintEqualToAnchor:circleView.centerYAnchor],

        [titleLabel.leadingAnchor constraintEqualToAnchor:overlay.leadingAnchor constant:12.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:overlay.trailingAnchor constant:-12.0],
        [titleLabel.topAnchor constraintEqualToAnchor:circleView.bottomAnchor constant:14.0]
    ]];
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
    [topGlow pp_setShadowColor:[UIColor colorWithRed:0.97 green:0.80 blue:0.64 alpha:1.0]];
    topGlow.layer.shadowOpacity = 0.10;
    topGlow.layer.shadowRadius = 62.0;
    topGlow.layer.shadowOffset = CGSizeZero;

    UIView *bottomGlow = [[UIView alloc] init];
    bottomGlow.translatesAutoresizingMaskIntoConstraints = NO;
    bottomGlow.userInteractionEnabled = NO;
    bottomGlow.backgroundColor = [[UIColor colorWithRed:0.72 green:0.45 blue:0.42 alpha:1.0] colorWithAlphaComponent:0.06];
    [bottomGlow pp_setShadowColor:[UIColor colorWithRed:0.73 green:0.31 blue:0.32 alpha:1.0]];
    bottomGlow.layer.shadowOpacity = 0.08;
    bottomGlow.layer.shadowRadius = 72.0;
    bottomGlow.layer.shadowOffset = CGSizeZero;

    [self.view insertSubview:topGlow belowSubview:self.tableView];
    [self.view insertSubview:bottomGlow belowSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [topGlow.widthAnchor constraintEqualToConstant:220.0],
        [topGlow.heightAnchor constraintEqualToConstant:220.0],
        [topGlow.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:-64.0],
        [topGlow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:80.0],

        [bottomGlow.widthAnchor constraintEqualToConstant:210.0],
        [bottomGlow.heightAnchor constraintEqualToConstant:210.0],
        [bottomGlow.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:44.0],
        [bottomGlow.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-68.0]
    ]];

    self.backgroundGlowViewTop = topGlow;
    self.backgroundGlowViewBottom = bottomGlow;
}

- (void)setupFormHeroHeader
{
    UIColor *accentColor = PPAdFormAccentColor();
    UIColor *primaryTextColor = PPAdFormPrimaryTextColor();

    UIView *heroRoot = [[UIView alloc] init];
    heroRoot.backgroundColor = UIColor.clearColor;
    heroRoot.userInteractionEnabled = NO;

    UIView *cardView = [[UIView alloc] init];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    cardView.backgroundColor = [self pp_adSurfaceColor];
    cardView.layer.cornerRadius = 34.0;
    cardView.layer.cornerCurve = kCACornerCurveContinuous;
    cardView.layer.borderWidth = 1.0;
    [cardView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:0.68]];
    [cardView pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    cardView.layer.shadowOpacity = 0.08;
    cardView.layer.shadowRadius = 24.0;
    cardView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    [heroRoot addSubview:cardView];

    UIView *tintView = [[UIView alloc] init];
    tintView.translatesAutoresizingMaskIntoConstraints = NO;
    tintView.backgroundColor = [[UIColor colorWithRed:0.99 green:0.96 blue:0.93 alpha:1.0] colorWithAlphaComponent:0.72];
    tintView.layer.cornerRadius = 34.0;
    tintView.layer.cornerCurve = kCACornerCurveContinuous;
    tintView.layer.masksToBounds = YES;
    [cardView addSubview:tintView];

    UIView *ambientGlow = [[UIView alloc] init];
    ambientGlow.translatesAutoresizingMaskIntoConstraints = NO;
    ambientGlow.backgroundColor = [accentColor colorWithAlphaComponent:0.16];
    ambientGlow.userInteractionEnabled = NO;
    ambientGlow.layer.cornerRadius = 94.0;
    [ambientGlow pp_setShadowColor:[accentColor colorWithAlphaComponent:0.48]];
    ambientGlow.layer.shadowOpacity = 0.16;
    ambientGlow.layer.shadowRadius = 42.0;
    ambientGlow.layer.shadowOffset = CGSizeZero;
    [cardView addSubview:ambientGlow];

    UIView *secondaryGlow = [[UIView alloc] init];
    secondaryGlow.translatesAutoresizingMaskIntoConstraints = NO;
    secondaryGlow.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.38];
    secondaryGlow.userInteractionEnabled = NO;
    secondaryGlow.layer.cornerRadius = 58.0;
    [secondaryGlow pp_setShadowColor:[[UIColor whiteColor] colorWithAlphaComponent:0.44]];
    secondaryGlow.layer.shadowOpacity = 0.18;
    secondaryGlow.layer.shadowRadius = 24.0;
    secondaryGlow.layer.shadowOffset = CGSizeZero;
    [cardView addSubview:secondaryGlow];

    UIView *accentBar = [[UIView alloc] init];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = accentColor;
    accentBar.layer.cornerRadius = 3.0;
    [cardView addSubview:accentBar];

    UIView *iconBadge = [[UIView alloc] init];
    iconBadge.translatesAutoresizingMaskIntoConstraints = NO;
    iconBadge.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.66];
    iconBadge.layer.cornerRadius = 31.0;
    iconBadge.layer.cornerCurve = kCACornerCurveContinuous;
    iconBadge.layer.borderWidth = 1.0;
    [iconBadge pp_setBorderColor:[accentColor colorWithAlphaComponent:0.18]];
    [iconBadge pp_setShadowColor:[accentColor colorWithAlphaComponent:0.30]];
    iconBadge.layer.shadowOpacity = 0.16;
    iconBadge.layer.shadowRadius = 18.0;
    iconBadge.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    [cardView addSubview:iconBadge];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"square.and.pencil"]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = accentColor;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconBadge addSubview:iconView];

    UIView *eyebrowPill = [[UIView alloc] init];
    eyebrowPill.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowPill.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.74];
    eyebrowPill.layer.cornerRadius = 14.0;
    eyebrowPill.layer.cornerCurve = kCACornerCurveContinuous;
    eyebrowPill.layer.borderWidth = 1.0;
    [eyebrowPill pp_setBorderColor:[accentColor colorWithAlphaComponent:0.10]];
    eyebrowPill.layer.masksToBounds = YES;
    [cardView addSubview:eyebrowPill];

    UILabel *eyebrowLabel = [[UILabel alloc] init];
    eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    eyebrowLabel.textColor = [accentColor colorWithAlphaComponent:0.92];
    eyebrowLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [eyebrowPill addSubview:eyebrowLabel];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:30.0] ?: [UIFont systemFontOfSize:30.0 weight:UIFontWeightBold];
    titleLabel.textColor = primaryTextColor;
    titleLabel.numberOfLines = 2;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [cardView addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.90];
    subtitleLabel.numberOfLines = 3;
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [cardView addSubview:subtitleLabel];

    UILabel *metaLabel = [[UILabel alloc] init];
    metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    metaLabel.font = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    metaLabel.textColor = [accentColor colorWithAlphaComponent:0.92];
    metaLabel.numberOfLines = 2;
    metaLabel.textAlignment = Language.alignmentForCurrentLanguage;
    metaLabel.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.78];
    metaLabel.layer.cornerRadius = 17.0;
    metaLabel.layer.cornerCurve = kCACornerCurveContinuous;
    metaLabel.layer.borderWidth = 1.0;
    [metaLabel pp_setBorderColor:[accentColor colorWithAlphaComponent:0.10]];
    metaLabel.layer.masksToBounds = YES;
    [cardView addSubview:metaLabel];

    [NSLayoutConstraint activateConstraints:@[
        [cardView.topAnchor constraintEqualToAnchor:heroRoot.topAnchor constant:10.0],
        [cardView.leadingAnchor constraintEqualToAnchor:heroRoot.leadingAnchor constant:20.0],
        [cardView.trailingAnchor constraintEqualToAnchor:heroRoot.trailingAnchor constant:-20.0],
        [cardView.bottomAnchor constraintEqualToAnchor:heroRoot.bottomAnchor constant:-14.0],

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

        [iconBadge.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:24.0],
        [iconBadge.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-24.0],
        [iconBadge.widthAnchor constraintEqualToConstant:62.0],
        [iconBadge.heightAnchor constraintEqualToConstant:62.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconBadge.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconBadge.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:28.0],
        [iconView.heightAnchor constraintEqualToConstant:28.0],

        [eyebrowPill.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:16.0],
        [eyebrowPill.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [eyebrowPill.trailingAnchor constraintLessThanOrEqualToAnchor:iconBadge.leadingAnchor constant:-16.0],
        [eyebrowPill.heightAnchor constraintGreaterThanOrEqualToConstant:28.0],

        [eyebrowLabel.topAnchor constraintEqualToAnchor:eyebrowPill.topAnchor constant:6.0],
        [eyebrowLabel.leadingAnchor constraintEqualToAnchor:eyebrowPill.leadingAnchor constant:12.0],
        [eyebrowLabel.trailingAnchor constraintEqualToAnchor:eyebrowPill.trailingAnchor constant:-12.0],
        [eyebrowLabel.bottomAnchor constraintEqualToAnchor:eyebrowPill.bottomAnchor constant:-6.0],

        [titleLabel.topAnchor constraintEqualToAnchor:eyebrowPill.bottomAnchor constant:18.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-24.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

        [metaLabel.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:18.0],
        [metaLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [metaLabel.trailingAnchor constraintLessThanOrEqualToAnchor:titleLabel.trailingAnchor],
        [metaLabel.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-24.0],
        [metaLabel.heightAnchor constraintGreaterThanOrEqualToConstant:34.0]
    ]];

    self.formHeroContainerView = heroRoot;
    self.formHeroCardView = cardView;
    self.formHeroEyebrowLabel = eyebrowLabel;
    self.formHeroTitleLabel = titleLabel;
    self.formHeroSubtitleLabel = subtitleLabel;
    self.formHeroMetaLabel = metaLabel;

    heroRoot.frame = CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.bounds), 252.0);
    self.tableView.tableHeaderView = heroRoot;
}

- (void)pp_refreshFormHeroContent
{
    NSString *eyebrow = (self.mode == AdEditorModeEdit)
        ? [self pp_localizedStringForKey:@"editing_mode" fallback:@"Editing mode"]
        : [self pp_localizedStringForKey:@"new_listing" fallback:@"New listing"];
    NSString *title = (self.mode == AdEditorModeEdit)
        ? [self pp_localizedStringForKey:@"EditAdTitle" fallback:@"Refine your listing"]
        : [self pp_localizedStringForKey:@"PostAdTitle" fallback:@"Create a polished ad"];

    NSString *kindName = self.selectedMainKind.KindName ?: self.selectedKind.KindName ?: @"";
    NSString *subtitle = kindName.length > 0
        ? [NSString stringWithFormat:@"%@%@", kindName, [self pp_localizedStringForKey:@"compose_listing_kind_suffix" fallback:@" listing details and standout visuals come next."]]
        : [self pp_localizedStringForKey:@"compose_listing_hint" fallback:@"Lead with the right details, then add a strong photo set."];

    NSString *imageText =
        [NSString stringWithFormat:@"%@ %ld/%ld",
         [self pp_localizedStringForKey:@"photos" fallback:@"Photos"],
         (long)[self safeMediaOutputCount],
         (long)self.imageCollection.maxImageCount];
    NSString *stateText = self.isPrefillInProgress
        ? [self pp_localizedStringForKey:@"loading_images" fallback:@"Loading images..."]
        : (self.isSubmittingAd
           ? [self pp_localizedStringForKey:@"uploading_images" fallback:@"Uploading images..."]
           : ((self.mode == AdEditorModeEdit)
              ? [self pp_localizedStringForKey:@"ready_to_update" fallback:@"Ready to update"]
              : [self pp_localizedStringForKey:@"draft_ready" fallback:@"Draft ready"]));

    self.formHeroEyebrowLabel.text = eyebrow;
    self.formHeroTitleLabel.text = title;
    self.formHeroSubtitleLabel.text = subtitle;
    self.formHeroMetaLabel.text = [NSString stringWithFormat:@"  %@  •  %@  ", imageText, stateText];
    [self pp_updateFormHeroHeaderLayoutIfNeeded];
}

- (CGFloat)pp_formHeroHeaderHeightForWidth:(CGFloat)width
{
    if (width <= 0.0) {
        return 252.0;
    }

    if (width < 350.0) {
        return 274.0;
    }

    if (width < 390.0) {
        return 262.0;
    }

    return 252.0;
}

- (NSString *)pp_authenticatedFirebaseUID
{
    return PPSafeString([FIRAuth auth].currentUser.uid);
}

- (NSString *)pp_submitOwnerID
{
    NSString *authUID = [self pp_authenticatedFirebaseUID];
    if (authUID.length > 0) {
        return authUID;
    }
    return PPSafeString(UserManager.sharedManager.currentUser.ID);
}

- (BOOL)pp_ensureAuthenticatedSessionForSubmit
{
    if ([self pp_authenticatedFirebaseUID].length > 0) {
        return YES;
    }

    NSString *title = [self pp_localizedStringForKey:@"sign_in_required"
                                             fallback:@"Sign in required"];
    NSString *subtitle =
        [self pp_localizedStringForKey:@"ad_submit_session_required"
                              fallback:@"Please sign in again before posting your ad."];
    [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
    return NO;
}

- (NSString *)pp_storagePathForAdID:(NSString *)adID index:(NSInteger)index
{
    NSString *fileName = [self pp_storageFileNameForAdID:adID index:index];
    return [NSString stringWithFormat:@"pet_ads/%@", fileName];
}

- (NSString *)pp_userFacingSubmitMessageForError:(NSError * _Nullable)error
                                        fallback:(NSString *)fallback
{
    if (![error isKindOfClass:NSError.class]) {
        return fallback;
    }

    if ([error.domain isEqualToString:FIRStorageErrorCodeDomain]) {
        if (error.code == FIRStorageErrorCodeUnauthenticated) {
            return [self pp_localizedStringForKey:@"ad_submit_session_required"
                                         fallback:@"Please sign in again before posting your ad."];
        }

        if (error.code == FIRStorageErrorCodeUnauthorized) {
            return [self pp_localizedStringForKey:@"ad_upload_failed_retry"
                                         fallback:@"We couldn't upload your ad photos right now. Please try again."];
        }
    }

    if ([error.domain isEqualToString:FIRFirestoreErrorDomain] &&
        error.code == FIRFirestoreErrorCodePermissionDenied) {
        return [self pp_localizedStringForKey:@"ad_save_failed_retry"
                                     fallback:@"We couldn't save your ad right now. Please try again."];
    }

    NSString *lowerDescription = [[error.localizedDescription ?: @"" lowercaseString] copy];
    if ([lowerDescription containsString:@"permission"] ||
        [lowerDescription containsString:@"unauthorized"]) {
        return [self pp_localizedStringForKey:@"ad_upload_failed_retry"
                                     fallback:@"We couldn't upload your ad photos right now. Please try again."];
    }

    if ([lowerDescription containsString:@"unauthenticated"] ||
        [lowerDescription containsString:@"sign in"]) {
        return [self pp_localizedStringForKey:@"ad_submit_session_required"
                                     fallback:@"Please sign in again before posting your ad."];
    }

    return error.localizedDescription.length ? error.localizedDescription : fallback;
}

- (void)pp_setCircularUploadProgressVisible:(BOOL)visible
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (visible) {
            self.uploadProgressTitleLabel.text = [self pp_localizedStringForKey:@"uploading_images" fallback:@"Uploading images..."];
            self.uploadProgressValueLabel.text = @"0%";
            self.uploadCircleProgressView.progress = 0.0;
            [self.view bringSubviewToFront:self.uploadProgressOverlay];
        }
        self.uploadProgressOverlay.hidden = !visible;
    });
}

- (void)pp_updateCircularUploadProgress:(CGFloat)progress
{
    CGFloat clampedProgress = MIN(1.0, MAX(0.0, progress));
    NSInteger percentage = (NSInteger)lrint(clampedProgress * 100.0);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.uploadCircleProgressView.progress = clampedProgress;
        self.uploadProgressValueLabel.text = [NSString stringWithFormat:@"%ld%%", (long)percentage];
    });
}

- (void)setPrefillLoadingVisible:(BOOL)visible
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.prefillLoadingView.hidden = !visible;
        if (visible) {
            [self.prefillLoadingSpinner startAnimating];
        } else {
            [self.prefillLoadingSpinner stopAnimating];
        }
    });
}

- (void)openImagePreviewAtIndex:(NSInteger)index
{
    NSArray<UIImage *> *images = [self safeMediaOutputArray];
    if (images.count == 0 || index < 0 || index >= images.count) return;

    self.photoBrowserBridge.useArabic = Language.isRTL;
    [self.photoBrowserBridge showBrowserFrom:self
                                      images:images
                                  startIndex:index];
}

#pragma mark - PPImageCollectionDelegate

- (void)imageCollection:(PPImageCollection *)collection didUpdateImages:(NSArray<UIImage *> *)images {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self imageCollection:collection didUpdateImages:images];
        });
        return;
    }

    NSLog(@"[PPImages] Updated images count=%ld", (long)images.count);
    if (!self.isHydratingFormData && !self.isHydratingMedia && !self.isPrefillInProgress) {
        self.hasUserModifiedForm = YES;
    }
    if (self.mode == AdEditorModeEdit && !self.isPrefillInProgress && !self.isHydratingMedia) {
        self.didMutateMediaAfterPrefill = YES;
    }
    [self pp_refreshMediaLocalizedText];
    [self pp_reloadMediaUI];
}

- (void)imageCollection:(PPImageCollection *)collection
         didSelectImage:(nonnull UIImage *)selectedImage
                AtIndex:(NSInteger)index
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.presentedViewController) {
            return;
        }

        UIView *anchorView = collection.collectionView ?: self.imageCollection;

        NSString *previewTitle = [self pp_localizedStringForKey:@"preview" fallback:@"Preview"];
        NSString *editTitle = [self pp_localizedStringForKey:@"edit" fallback:@"Edit"];
        NSArray<NSString *> *titles = @[previewTitle, editTitle];
        NSArray<UIImage *> *icons = @[
            [UIImage systemImageNamed:@"eye"],
            [UIImage systemImageNamed:@"slider.horizontal.3"]
        ];

        __weak typeof(self) weakSelf = self;
        [PPMenuHelper presentActionSheetFromViewController:self
                                                sourceView:anchorView
                                                    titles:titles
                                                    images:icons
                                              destructive:nil
                                                  handler:^(NSInteger menuIndex, NSString *title) {
            if (menuIndex == 0) {
                [weakSelf openImagePreviewAtIndex:index];
            } else if (menuIndex == 1) {
                [collection presentEditorForImageAtIndex:index fromViewController:weakSelf];
            }
        }];
    });
}

- (void)imageCollectionDidRequestAddImage:(PPImageCollection *)collection {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self safeMediaOutputCount] >= collection.maxImageCount) {
            NSString *title = [self pp_localizedStringForKey:@"max_images_reached"
                                                     fallback:@"Maximum images reached"];
            NSString *subtitle = [NSString stringWithFormat:@"%@ %ld",
                                  [self pp_localizedStringForKey:@"max_images_hint" fallback:@"You can upload up to"],
                                  (long)collection.maxImageCount];
            [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
            return;
        }
        [collection presentPickerFromViewController:self];
    });
}

#pragma mark - Prefill for Editing

- (void)pp_finishPrefillFlow
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isPrefillInProgress = NO;
        [self pp_setMediaLoadingVisible:NO textKey:@"loading_images" fallback:@"Loading images..."];
        self.imageCollection.userInteractionEnabled = !self.isSubmittingAd;
        [self pp_setSubmitEnabled:!self.isSubmittingAd];
    });
}

- (void)prefillPhotosForEdit
{
    self.isPrefillInProgress = YES;
    [self pp_setSubmitEnabled:NO];
    [self pp_setMediaLoadingVisible:YES textKey:@"loading_images" fallback:@"Loading images..."];

    NSArray<PetImageItem *> *items = self.adModel.imageItems;
    if (items.count == 0) {
        [self pp_finishPrefillFlow];
        return;
    }

    NSMutableArray<NSString *> *urls = [NSMutableArray arrayWithCapacity:items.count];
    for (PetImageItem *item in items) {
        if (item.url.length) {
            [urls addObject:item.url];
        }
    }

    if (urls.count == 0) {
        [self pp_finishPrefillFlow];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageCollection.userInteractionEnabled = NO;
    });

    [self.imageCollection preloadImagesFromURLs:urls completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"Prefilled %ld images for editing", (long)urls.count);
            [self pp_reloadMediaUI];
            [self pp_refreshMediaLocalizedText];
        });
        [self pp_finishPrefillFlow];
    }];
}

#pragma mark - Upload Handling (Fixed)

- (NSError *)pp_uploadErrorWithCode:(NSInteger)code description:(NSString *)description
{
    NSString *message = description.length ? description : @"Image upload failed.";
    return [NSError errorWithDomain:PPAddNewAdUploadErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

- (void)pp_cleanupFailedCreatedAd:(PetAd *)ad
                    originalError:(NSError *)error
{
    if (ad.adID.length == 0) {
        [self pp_handleSubmitFailure:error];
        return;
    }

    [[PetAdManager sharedManager] deletePetAd:ad completion:^(NSError *cleanupError) {
        if (cleanupError) {
            NSLog(@"⚠️ [CreateAd] Failed to rollback ad %@ after submit error: %@",
                  ad.adID,
                  cleanupError.localizedDescription ?: @"Unknown cleanup error");
        }
        [self pp_handleSubmitFailure:error];
    }];
}

- (BOOL)pp_validateCreateHasAtLeastOneImage
{
    if ([self safeMediaOutputCount] > 0) {
        return YES;
    }

    NSString *title = [self pp_localizedStringForKey:@"add_images_required"
                                             fallback:@"Add at least one image"];
    NSString *subtitle = [self pp_localizedStringForKey:@"add_images_required_desc"
                                                fallback:@"Please add at least one image before posting your ad."];
    [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
    return NO;
}

- (UIImage *)pp_normalizedImageForUpload:(UIImage *)image
{
    if (!image) return nil;
    if (image.size.width <= 0.0 || image.size.height <= 0.0) return nil;

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;
    format.scale = image.scale > 0 ? image.scale : UIScreen.mainScreen.scale;

    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:image.size format:format];
    UIImage *normalized = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    }];
    return normalized ?: image;
}

- (void)uploadUIImages:(NSArray<UIImage *> *)images
                 forAd:(PetAd *)ad
            completion:(void (^)(PetAd *_Nullable updatedAd, NSError *_Nullable error))completion
{
    NSLog(@"🟢 [uploadUIImages] START | adID=%@ | images=%lu",
          ad.adID, (unsigned long)images.count);

    if (ad.adID.length == 0) {
        if (completion) completion(nil, [self pp_uploadErrorWithCode:400 description:@"Missing adID for image upload."]);
        return;
    }

    if (images.count == 0) {
        NSLog(@"⚠️ [uploadUIImages] No images, returning immediately");
        ad.imageItems = @[];
        self.finalImageItems = @[];
        if (completion) completion(ad, nil);
        return;
    }

    NSMutableArray<UIImage *> *normalizedImages = [NSMutableArray arrayWithCapacity:images.count];
    for (NSInteger idx = 0; idx < images.count; idx++) {
        UIImage *normalized = [self pp_normalizedImageForUpload:images[idx]];
        if (!normalized) {
            if (completion) completion(nil, [self pp_uploadErrorWithCode:401
                                                             description:[NSString stringWithFormat:@"Failed to prepare image at index %ld.", (long)idx]]);
            return;
        }
        [normalizedImages addObject:normalized];
    }

    FIRStorage *storage = [FIRStorage storage];
    FIRStorageReference *rootRef = storage.reference;

    dispatch_group_t group = dispatch_group_create();
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:normalizedImages.count];
    dispatch_queue_t stateQueue = dispatch_queue_create("com.purepets.addnewad.upload", DISPATCH_QUEUE_SERIAL);
    __block NSMutableDictionary<NSNumber *, NSNumber *> *progressByIndex = [NSMutableDictionary dictionaryWithCapacity:normalizedImages.count];
    __block NSError *firstError = nil;

    for (NSInteger i = 0; i < normalizedImages.count; i++) {
        [items addObject:[NSNull null]];
        progressByIndex[@(i)] = @(0.0);
    }
    [self pp_updateCircularUploadProgress:0.0];

    for (NSInteger idx = 0; idx < normalizedImages.count; idx++) {

        UIImage *img = normalizedImages[idx];
        if (!img) {
            NSLog(@"❌ [uploadUIImages] Image at index %ld is nil", (long)idx);
            dispatch_sync(stateQueue, ^{
                if (!firstError) {
                    firstError = [self pp_uploadErrorWithCode:402
                                                   description:[NSString stringWithFormat:@"Image at index %ld is empty.", (long)idx]];
                }
            });
            continue;
        }

        NSLog(@"⬆️ [uploadUIImages] Uploading image %ld/%lu",
              (long)(idx + 1), (unsigned long)normalizedImages.count);

        dispatch_group_enter(group);

        NSData *data = UIImageJPEGRepresentation(img, 0.75);
        if (!data) {
            NSLog(@"❌ [uploadUIImages] Failed to encode image at index %ld", (long)idx);
            dispatch_sync(stateQueue, ^{
                if (!firstError) {
                    firstError = [self pp_uploadErrorWithCode:403
                                                   description:[NSString stringWithFormat:@"Failed to encode image at index %ld.", (long)idx]];
                }
            });
            dispatch_group_leave(group);
            continue;
        }

        NSString *storagePath = [self pp_storagePathForAdID:ad.adID index:idx];
        FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] init];
        metadata.contentType = @"image/jpeg";

        FIRStorageReference *ref =
        [rootRef child:storagePath];

        FIRStorageUploadTask *uploadTask =
            [ref putData:data metadata:metadata completion:^(FIRStorageMetadata *meta, NSError *error) {

            if (error) {
                NSLog(@"❌ [uploadUIImages] Upload failed idx=%ld | %@",
                      (long)idx, error.localizedDescription);
                dispatch_sync(stateQueue, ^{
                    if (!firstError) {
                        firstError = error;
                    }
                    progressByIndex[@(idx)] = @(1.0);
                });
                __block CGFloat overallProgress = 0.0;
                dispatch_sync(stateQueue, ^{
                    double total = 0.0;
                    for (NSNumber *value in progressByIndex.allValues) {
                        total += value.doubleValue;
                    }
                    overallProgress = (CGFloat)(total / (double)normalizedImages.count);
                });
                [self pp_updateCircularUploadProgress:overallProgress];
                dispatch_group_leave(group);
                return;
            }

            NSLog(@"✅ [uploadUIImages] Upload success idx=%ld", (long)idx);

            [ref downloadURLWithCompletion:^(NSURL *url, NSError *error2) {

                if (!url) {
                    NSLog(@"❌ [uploadUIImages] URL fetch failed idx=%ld | %@",
                          (long)idx, error2.localizedDescription);
                    dispatch_sync(stateQueue, ^{
                        if (!firstError) {
                            firstError = error2 ?: [self pp_uploadErrorWithCode:404 description:@"Failed to fetch uploaded image URL."];
                        }
                    });
                    dispatch_group_leave(group);
                    return;
                }

                NSLog(@"🔗 [uploadUIImages] Got download URL idx=%ld", (long)idx);

                // 🔥 BlurHash generation happens HERE
                [PPBlurHashGenerator generateBlurHashFromImage:img
                                                     completion:^(NSString *hash) {

                    NSLog(@"🎨 [uploadUIImages] BlurHash generated idx=%ld | %@",
                          (long)idx, hash.length > 0 ? @"YES" : @"NO");

                    PetImageItem *item =
                    [PetImageItem itemWithURL:url.absoluteString
                                        width:img.size.width
                                       height:img.size.height
                                     blurHash:hash];

                    dispatch_sync(stateQueue, ^{
                        items[idx] = item ?: [NSNull null];
                        progressByIndex[@(idx)] = @(1.0);
                    });

                    __block CGFloat overallProgress = 0.0;
                    dispatch_sync(stateQueue, ^{
                        double total = 0.0;
                        for (NSNumber *value in progressByIndex.allValues) {
                            total += value.doubleValue;
                        }
                        overallProgress = (CGFloat)(total / (double)normalizedImages.count);
                    });
                    [self pp_updateCircularUploadProgress:overallProgress];

                    NSLog(@"📦 [uploadUIImages] ImageItem ready idx=%ld", (long)idx);

                    dispatch_group_leave(group);
                }];
            }];
        }];

        [uploadTask observeStatus:FIRStorageTaskStatusProgress handler:^(FIRStorageTaskSnapshot *snapshot) {
            NSProgress *taskProgress = snapshot.progress;
            if (!taskProgress) {
                return;
            }
            double current = 0.0;
            if (taskProgress.totalUnitCount > 0) {
                current = (double)taskProgress.completedUnitCount / (double)taskProgress.totalUnitCount;
            }
            current = MIN(1.0, MAX(0.0, current));

            __block CGFloat overallProgress = 0.0;
            dispatch_sync(stateQueue, ^{
                progressByIndex[@(idx)] = @(current);
                double total = 0.0;
                for (NSNumber *value in progressByIndex.allValues) {
                    total += value.doubleValue;
                }
                overallProgress = (CGFloat)(total / (double)normalizedImages.count);
            });
            [self pp_updateCircularUploadProgress:overallProgress];
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{

        NSMutableArray<PetImageItem *> *finalItems = [NSMutableArray array];
        for (id obj in [items copy]) {
            if ([obj isKindOfClass:PetImageItem.class]) {
                [finalItems addObject:obj];
            }
        }

        NSLog(@"🏁 [uploadUIImages] FINISHED | validItems=%lu",
              (unsigned long)finalItems.count);

        if (firstError) {
            if (completion) completion(nil, firstError);
            return;
        }

        if (finalItems.count != normalizedImages.count) {
            if (completion) completion(nil, [self pp_uploadErrorWithCode:405
                                                             description:@"Not all images were uploaded successfully."]);
            return;
        }

        // 🔑 SINGLE SOURCE OF TRUTH
        self.finalImageItems = finalItems;
        ad.imageItems = finalItems;
        [self pp_reloadMediaUI];
        [self pp_updateCircularUploadProgress:1.0];

        NSLog(@"🧠 [uploadUIImages] Assigned imageItems to adID=%@",
              ad.adID);

        // ✅ Upload finished — images are now on the model
        if (completion) completion(ad, nil);
    });
}

- (NSString *)pp_storageFileNameForAdID:(NSString *)adID index:(NSInteger)index
{
    NSString *safeAdID = adID.length ? adID : @"ad";
    NSString *token = [NSUUID.UUID.UUIDString lowercaseString];
    return [NSString stringWithFormat:@"%@_%03ld_%@.jpg", safeAdID, (long)index, token];
}

#pragma mark - Cleanup

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    BOOL exiting = self.isMovingFromParentViewController || self.isBeingDismissed || self.navigationController.isBeingDismissed;
    if (exiting) {
        [self pp_setPremiumTabDockHidden:NO animated:animated];
    }
    NSLog(@"[PPImages] viewWillDisappear - preserving media state");
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

- (NSString *)draftStorageKey
{
    NSString *currentUserID = PPSafeString(UserManager.sharedManager.currentUser.ID);
    if (self.mode == AdEditorModeEdit && self.editingAd.adID.length) {
        return [NSString stringWithFormat:@"%@.edit.%@.%@",
                PPAddNewAdDraftDefaultsPrefix,
                self.editingAd.adID,
                currentUserID];
    }

    NSInteger kindID = self.selectedMainKind.ID > 0 ? self.selectedMainKind.ID : self.selectedKind.ID;
    return [NSString stringWithFormat:@"%@.create.%ld.%@",
            PPAddNewAdDraftDefaultsPrefix,
            (long)kindID,
            currentUserID];
}

- (NSString *)draftDirectoryPath
{
    NSString *draftID = [[[self draftStorageKey]
                          stringByReplacingOccurrencesOfString:@"." withString:@"_"]
                         stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:@"pp_form_drafts"];
    return [root stringByAppendingPathComponent:draftID];
}

- (BOOL)hasSavedDraft
{
    return [[[NSUserDefaults standardUserDefaults] objectForKey:[self draftStorageKey]] isKindOfClass:NSDictionary.class];
}

- (NSData *)archivedDraftDataForObject:(id)object
{
    if (!object) return nil;

    if (@available(iOS 11.0, *)) {
        return [NSKeyedArchiver archivedDataWithRootObject:object
                                     requiringSecureCoding:NO
                                                     error:nil];
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [NSKeyedArchiver archivedDataWithRootObject:object];
#pragma clang diagnostic pop
}

- (id)unarchivedDraftObjectFromData:(NSData *)data
{
    if (![data isKindOfClass:NSData.class] || data.length == 0) return nil;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [NSKeyedUnarchiver unarchiveObjectWithData:data];
#pragma clang diagnostic pop
}

- (NSDictionary *)draftFormDataSnapshot
{
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];

    NSString *title = [PPSafeString([self fieldForTag:@"adTitle"].value) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (title.length) {
        snapshot[@"adTitle"] = title;
    }

    MainKindsModel *mainKind = self.selectedMainKind;
    if (!mainKind && [[self fieldForTag:kcategory].value isKindOfClass:MainKindsModel.class]) {
        mainKind = (MainKindsModel *)[self fieldForTag:kcategory].value;
    }
    if (!mainKind) {
        mainKind = self.selectedKind;
    }
    if (mainKind.ID > 0) {
        snapshot[@"categoryID"] = @(mainKind.ID);
    }

    SubKindModel *subKind = [[self fieldForTag:ksubcategory].value isKindOfClass:SubKindModel.class]
        ? (SubKindModel *)[self fieldForTag:ksubcategory].value
        : nil;
    if (subKind.ID > 0) {
        snapshot[@"subcategoryID"] = @(subKind.ID);
    }

    snapshot[@"isFemale"] = @(self.adModel.isFemale);

    if ([[self fieldForTag:kpetAge].value respondsToSelector:@selector(integerValue)]) {
        NSInteger age = [[self fieldForTag:kpetAge].value integerValue];
        if (age > 0) {
            snapshot[@"petAgeMonths"] = @(age);
        }
    }

    if ([[self fieldForTag:kprice].value respondsToSelector:@selector(integerValue)]) {
        NSInteger price = [[self fieldForTag:kprice].value integerValue];
        if (price > 0) {
            snapshot[@"price"] = @(price);
        }
    }

    NSString *desc = [PPSafeString([self fieldForTag:kdesc].value) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (desc.length) {
        snapshot[@"desc"] = desc;
    }

    NSString *locationName = PPSafeString(self.selectedAdLocationName.length ? self.selectedAdLocationName : [self fieldForTag:kadLocation].value);
    if (locationName.length) {
        snapshot[@"locationName"] = locationName;
    }

    if (self.hasSelectedAdCoordinate && PPIsValidAdCoordinate(self.selectedAdCoordinate)) {
        snapshot[@"latitude"] = @(self.selectedAdCoordinate.latitude);
        snapshot[@"longitude"] = @(self.selectedAdCoordinate.longitude);
    }

    snapshot[PPAddNewAdDraftMediaMutatedKey] = @(self.didMutateMediaAfterPrefill);
    return snapshot.copy;
}

- (NSString *)writeDraftImage:(UIImage *)image
                        named:(NSString *)fileName
                    directory:(NSString *)directory
{
    if (!image || fileName.length == 0 || directory.length == 0) return nil;

    NSData *imageData = UIImageJPEGRepresentation(image, 0.88);
    if (!imageData) {
        imageData = UIImagePNGRepresentation(image);
    }
    if (!imageData) return nil;

    NSString *path = [directory stringByAppendingPathComponent:fileName];
    return [imageData writeToFile:path atomically:YES] ? path : nil;
}

- (NSArray<NSString *> *)writeDraftImages:(NSArray<UIImage *> *)images
                               withPrefix:(NSString *)prefix
                                directory:(NSString *)directory
{
    if (images.count == 0) return @[];

    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    [images enumerateObjectsUsingBlock:^(UIImage *image, NSUInteger idx, BOOL *stop) {
        (void)stop;
        NSString *fileName = [NSString stringWithFormat:@"%@_%lu.jpg",
                              prefix,
                              (unsigned long)idx];
        NSString *path = [self writeDraftImage:image named:fileName directory:directory];
        if (path.length) {
            [paths addObject:path];
        }
    }];

    return paths.copy;
}

- (NSArray<UIImage *> *)imagesFromDraftPaths:(NSArray<NSString *> *)paths
{
    NSMutableArray<UIImage *> *images = [NSMutableArray array];
    for (NSString *path in paths) {
        if (![path isKindOfClass:NSString.class] || path.length == 0) continue;
        UIImage *image = [self pp_downsampledDraftImageAtPath:path maxPixelSize:PPAddNewAdDraftImageMaxPixelSize];
        if (image) {
            [images addObject:image];
        }
    }
    return images.copy;
}

- (UIImage *)pp_downsampledDraftImageAtPath:(NSString *)path
                               maxPixelSize:(CGFloat)maxPixelSize
{
    if (![path isKindOfClass:NSString.class] || path.length == 0) {
        return nil;
    }

    NSURL *fileURL = [NSURL fileURLWithPath:path];
    NSDictionary *sourceOptions = @{
        (NSString *)kCGImageSourceShouldCache : @NO
    };
    CGImageSourceRef source =
        CGImageSourceCreateWithURL((__bridge CFURLRef)fileURL, (__bridge CFDictionaryRef)sourceOptions);
    if (!source) {
        return [UIImage imageWithContentsOfFile:path];
    }

    NSDictionary *thumbnailOptions = @{
        (NSString *)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
        (NSString *)kCGImageSourceCreateThumbnailWithTransform : @YES,
        (NSString *)kCGImageSourceShouldCacheImmediately : @NO,
        (NSString *)kCGImageSourceThumbnailMaxPixelSize : @((NSInteger)MAX(1.0, maxPixelSize))
    };
    CGImageRef thumbnail =
        CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)thumbnailOptions);
    CFRelease(source);

    if (!thumbnail) {
        return [UIImage imageWithContentsOfFile:path];
    }

    UIImage *image =
        [UIImage imageWithCGImage:thumbnail
                            scale:UIScreen.mainScreen.scale
                      orientation:UIImageOrientationUp];
    CGImageRelease(thumbnail);
    return image;
}

- (void)pp_restoreDraftImagesFromPaths:(NSArray<NSString *> *)paths
{
    NSArray<NSString *> *imagePaths =
        [paths isKindOfClass:NSArray.class] ? [paths copy] : @[];

    self.isHydratingMedia = YES;
    [self.imageCollection clearAllImages];

    if (imagePaths.count == 0) {
        self.isHydratingMedia = NO;
        [self pp_setMediaLoadingVisible:NO textKey:@"loading_images" fallback:@"Loading images..."];
        [self pp_refreshFormHeroContent];
        return;
    }

    [self pp_setMediaLoadingVisible:YES textKey:@"loading_images" fallback:@"Loading images..."];

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        NSArray<UIImage *> *draftImages = [self imagesFromDraftPaths:imagePaths];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }

            if (draftImages.count > 0) {
                [strongSelf.imageCollection addImages:draftImages];
            }
            strongSelf.isHydratingMedia = NO;
            [strongSelf pp_setMediaLoadingVisible:NO textKey:@"loading_images" fallback:@"Loading images..."];
            [strongSelf pp_refreshFormHeroContent];
        });
    });
}

- (void)clearSavedDraft
{
    [[NSFileManager defaultManager] removeItemAtPath:[self draftDirectoryPath] error:nil];
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs removeObjectForKey:[self draftStorageKey]];
    [prefs synchronize];
}

- (void)saveDraftForLater
{
    NSDictionary *snapshot = [self draftFormDataSnapshot];
    NSData *archivedForm = [self archivedDraftDataForObject:snapshot];
    if (!archivedForm) return;

    NSString *directory = [self draftDirectoryPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:directory error:nil];
    [fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];

    NSArray<NSString *> *imagePaths = [self writeDraftImages:[self.imageCollection allImages]
                                                  withPrefix:@"media"
                                                   directory:directory];

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[PPAddNewAdDraftFormDataKey] = archivedForm;
    payload[PPAddNewAdDraftImagePathsKey] = imagePaths ?: @[];

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:payload.copy forKey:[self draftStorageKey]];
    [prefs synchronize];
}

- (void)applyDraftValue:(id)value
               toRowTag:(NSString *)tag
           triggerBlock:(BOOL)triggerBlock
{
    PPAdFormField *field = [self fieldForTag:tag];
    if (!field || !value || value == [NSNull null]) return;

    id oldValue = field.value;
    field.value = value;
    [self pp_reloadFieldWithTag:tag];

    if (triggerBlock && field.onChangeBlock) {
        field.onChangeBlock(oldValue, value);
    }
}

- (BOOL)restoreDraftIfNeeded
{
    NSDictionary *payload = [[NSUserDefaults standardUserDefaults] objectForKey:[self draftStorageKey]];
    if (![payload isKindOfClass:NSDictionary.class]) {
        return NO;
    }

    NSDictionary *storedValues = [self unarchivedDraftObjectFromData:payload[PPAddNewAdDraftFormDataKey]];
    if (![storedValues isKindOfClass:NSDictionary.class]) {
        [self clearSavedDraft];
        return NO;
    }

    self.isHydratingFormData = YES;

    NSString *title = PPSafeString(storedValues[@"adTitle"]);
    if (title.length) {
        [self applyDraftValue:title toRowTag:@"adTitle" triggerBlock:YES];
    }

    MainKindsModel *mainKind = self.selectedMainKind;
    NSNumber *mainKindID = storedValues[@"categoryID"];
    if (!mainKind && [mainKindID respondsToSelector:@selector(integerValue)]) {
        mainKind = [MKM mainKindForID:mainKindID.integerValue];
    }

    if (mainKind) {
        self.selectedKind = mainKind;
        self.adModel.category = mainKind.ID;
        if (!self.selectedMainKind) {
            [self applyDraftValue:mainKind toRowTag:kcategory triggerBlock:YES];
        }
        PPAdFormField *subF = [self fieldForTag:ksubcategory];
        subF.disabled = NO;
        subF.selectorOptions = mainKind.SubKindsArray ?: @[];
        [self pp_reloadFieldWithTag:ksubcategory];
    }

    NSNumber *subKindID = storedValues[@"subcategoryID"];
    if ([subKindID respondsToSelector:@selector(integerValue)] && self.selectedKind) {
        SubKindModel *subKind = nil;
        for (SubKindModel *candidate in self.selectedKind.SubKindsArray) {
            if (candidate.ID == subKindID.integerValue) {
                subKind = candidate;
                break;
            }
        }
        if (subKind) {
            [self applyDraftValue:subKind toRowTag:ksubcategory triggerBlock:YES];
        }
    }

    if (storedValues[@"isFemale"] != nil) {
        [self applyDraftValue:@([storedValues[@"isFemale"] boolValue]) toRowTag:@"isFemale" triggerBlock:YES];
    }

    if ([storedValues[@"petAgeMonths"] respondsToSelector:@selector(integerValue)]) {
        [self applyDraftValue:storedValues[@"petAgeMonths"] toRowTag:kpetAge triggerBlock:YES];
    }

    if ([storedValues[@"price"] respondsToSelector:@selector(integerValue)]) {
        [self applyDraftValue:storedValues[@"price"] toRowTag:kprice triggerBlock:YES];
    }

    NSString *desc = PPSafeString(storedValues[@"desc"]);
    if (desc.length) {
        [self applyDraftValue:desc toRowTag:kdesc triggerBlock:YES];
    }

    NSString *locationName = PPSafeString(storedValues[@"locationName"]);
    NSNumber *latitude = storedValues[@"latitude"];
    NSNumber *longitude = storedValues[@"longitude"];
    if (locationName.length) {
        self.selectedAdLocationName = locationName;
        self.adModel.locationName = locationName;
        [self applyDraftValue:locationName toRowTag:kadLocation triggerBlock:NO];
    }
    if ([latitude respondsToSelector:@selector(doubleValue)] &&
        [longitude respondsToSelector:@selector(doubleValue)]) {
        CLLocationCoordinate2D coordinate =
        CLLocationCoordinate2DMake(latitude.doubleValue, longitude.doubleValue);
        if (PPIsValidAdCoordinate(coordinate)) {
            self.selectedAdCoordinate = coordinate;
            self.hasSelectedAdCoordinate = YES;
            self.adModel.latitude = coordinate.latitude;
            self.adModel.longitude = coordinate.longitude;
        }
    }

    self.didMutateMediaAfterPrefill = [storedValues[PPAddNewAdDraftMediaMutatedKey] boolValue];
    self.hasUserModifiedForm = NO;
    self.isHydratingFormData = NO;
    [self pp_restoreDraftImagesFromPaths:payload[PPAddNewAdDraftImagePathsKey]];
    [self.tableView reloadData];
    return YES;
}

- (BOOL)pp_shouldPromptForDraftOptions
{
    return self.hasUserModifiedForm || [self hasSavedDraft];
}

- (void)pp_dismissForm
{
    BOOL isRootOfPresentedNav = (self.navigationController.presentingViewController != nil &&
                                 self.navigationController.viewControllers.firstObject == self);
    if (isRootOfPresentedNav) {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
        return;
    }

    [self.navigationController popViewControllerAnimated:YES];
}

- (void)presentUnsavedChangesPrompt
{
    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showThreeActionConfirmationIn:self
                                           title:kLang(@"form_draft_prompt_title")
                                        subtitle:kLang(@"form_draft_prompt_message")
                                   primaryButton:kLang(@"form_draft_save_and_close")
                                    primaryStyle:UIAlertActionStyleDefault
                                 secondaryButton:kLang(@"form_draft_discard")
                                  secondaryStyle:UIAlertActionStyleDestructive
                                  tertiaryButton:kLang(@"form_draft_keep_editing")
                                   tertiaryStyle:UIAlertActionStyleCancel
                                    primaryBlock:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf saveDraftForLater];
        [strongSelf pp_dismissForm];
    } secondaryBlock:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf clearSavedDraft];
        [strongSelf pp_dismissForm];
    } tertiaryBlock:^{
    }];
}

- (void)pp_handleBackNavigation
{
    if (self.isSubmittingAd) {
        return;
    }

    [self.view endEditing:YES];
    if ([self pp_shouldPromptForDraftOptions]) {
        [self presentUnsavedChangesPrompt];
        return;
    }

    [self pp_dismissForm];
}



























- (void)forceLTRRecursively:(UIView *)view {
    view.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    for (UIView *sub in view.subviews) {
        [self forceLTRRecursively:sub];
    }
}

- (void)pp_updateImageCollectionFooterLayoutIfNeeded
{
    if (!self.imageCollectionFooterContainerView) {
        return;
    }

    CGFloat footerWidth = CGRectGetWidth(self.tableView.bounds);
    if (footerWidth <= 0.0) {
        footerWidth = CGRectGetWidth(self.view.bounds);
    }
    if (footerWidth <= 0.0) {
        return;
    }

    CGFloat footerHeight = 236.0;
    if (fabs(self.lastAppliedImageCollectionFooterWidth - footerWidth) < 0.5 &&
        fabs(CGRectGetHeight(self.imageCollectionFooterContainerView.frame) - footerHeight) < 0.5) {
        return;
    }

    self.lastAppliedImageCollectionFooterWidth = footerWidth;
    self.imageCollectionFooterContainerView.frame = CGRectMake(0.0, 0.0, footerWidth, footerHeight);
    self.tableView.tableFooterView = self.imageCollectionFooterContainerView;
}

- (void)setupImageCollection {
    self.imageCollection =
        [[PPImageCollection alloc] initWithFrame:CGRectZero
                                   maxImageCount:8
                                       useArabic:Language.isRTL];
    self.imageCollection.delegate = self;
    self.imageCollection.allowsEditing = YES;
    self.imageCollection.useArabic = Language.isRTL;
    self.imageCollection.headerContentInsets = UIEdgeInsetsMake(0.0, 16.0, 0.0, 16.0);
    self.imageCollection.backgroundColor = UIColor.clearColor;
    [self pp_refreshMediaLocalizedText];

    UIView *footerContainer = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.bounds), 236.0)];
    footerContainer.backgroundColor = UIColor.clearColor;
    footerContainer.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    self.imageCollectionFooterContainerView = footerContainer;

    [footerContainer addSubview:self.imageCollection];
    self.imageCollection.translatesAutoresizingMaskIntoConstraints = NO;

    CGFloat height = 212.0;

    [NSLayoutConstraint activateConstraints:@[
        [self.imageCollection.topAnchor constraintEqualToAnchor:footerContainer.topAnchor constant:8.0],
        [self.imageCollection.leadingAnchor constraintEqualToAnchor:footerContainer.leadingAnchor constant:16.0],
        [self.imageCollection.trailingAnchor constraintEqualToAnchor:footerContainer.trailingAnchor constant:-16.0],
        [self.imageCollection.bottomAnchor constraintEqualToAnchor:footerContainer.bottomAnchor constant:-16.0],
        [self.imageCollection.heightAnchor constraintEqualToConstant:height]
    ]];

    self.tableView.tableFooterView = footerContainer;
    self.tableView.scrollEnabled = YES;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.contentInset = UIEdgeInsetsMake(6.0, 0.0, 24.0, 0.0);
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(6.0, 0.0, 24.0, 0.0);
    [self pp_updateImageCollectionFooterLayoutIfNeeded];
}

- (void)pp_presentAdLocationPicker
{
    LocationPickerViewController *picker = [[LocationPickerViewController alloc] init];
    if (self.hasSelectedAdCoordinate && PPIsValidAdCoordinate(self.selectedAdCoordinate)) {
        picker.initialCoordinate = self.selectedAdCoordinate;
    }
    __weak typeof(self) weakSelf = self;
    void (^applyCoordinate)(CLLocationCoordinate2D, NSString *) =
    ^(CLLocationCoordinate2D coordinate, NSString *title) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !PPIsValidAdCoordinate(coordinate)) {
            return;
        }
        self.selectedAdCoordinate = coordinate;
        self.hasSelectedAdCoordinate = YES;
        self.selectedAdLocationName = PPSafeString(title);
        if (self.selectedAdLocationName.length == 0) {
            self.selectedAdLocationName = [NSString stringWithFormat:@"%.6f, %.6f",
                                           coordinate.latitude, coordinate.longitude];
        }
        self.adModel.latitude = coordinate.latitude;
        self.adModel.longitude = coordinate.longitude;
        self.adModel.locationName = self.selectedAdLocationName;

        PPAdFormField *locField = [weakSelf fieldForTag:kadLocation];
        locField.value = self.selectedAdLocationName.length
            ? self.selectedAdLocationName
            : kLang(@"select_location");
        [weakSelf pp_reloadFieldWithTag:kadLocation];
        if (!self.isHydratingFormData) {
            self.hasUserModifiedForm = YES;
        }
    };
    picker.onLocationConfirmed = ^(GMSAddress *gmsAddress) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !gmsAddress) return;

        CLLocationCoordinate2D coordinate = gmsAddress.coordinate;
        if (!PPIsValidAdCoordinate(coordinate)) {
            [PPAlertHelper showErrorIn:self
                                 title:kLang(@"Location")
                              subtitle:[self pp_localizedStringForKey:@"location_invalid"
                                                              fallback:@"Please choose a valid location from the map."]];
            return;
        }

        NSString *resolvedTitle = [LocationPickerViewController titleFromAddress:gmsAddress];
        if (resolvedTitle.length == 0 && gmsAddress.country.length > 0) {
            resolvedTitle = gmsAddress.country;
        }
        applyCoordinate(coordinate, resolvedTitle);
    };
    picker.onCoordinateConfirmed = ^(CLLocationCoordinate2D coordinate, NSString *locationTitle) {
        applyCoordinate(coordinate, locationTitle);
    };
    [self.navigationController pushViewController:picker animated:YES];
}

// didSelectFormRow removed — replaced by tableView:didSelectRowAtIndexPath: above

- (NSArray<NSString *> *)pp_sectionHeaderContentForSection:(NSInteger)section
{
    if (section == 0) {
        return @[
            [self pp_localizedStringForKey:@"basicInfoSection" fallback:@"Ad basics"],
            [self pp_localizedStringForKey:@"basic_info_subtitle" fallback:@"Choose the title and category details buyers will scan first."]
        ];
    }

    if (section == 1) {
        return @[
            [self pp_localizedStringForKey:@"pet_details_section" fallback:@"Pet details"],
            [self pp_localizedStringForKey:@"pet_details_subtitle" fallback:@"Add the specific facts people compare before they open the ad."]
        ];
    }

    return @[
        [self pp_localizedStringForKey:@"listing_details_section" fallback:@"Listing details"],
        [self pp_localizedStringForKey:@"listing_details_subtitle" fallback:@"Finish the post with price, place, and a sharp description."]
    ];
}

- (UIView *)pp_sectionHeaderViewForTitle:(NSString *)title subtitle:(NSString *)subtitle
{
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = UIColor.clearColor;

    UIView *accentBar = [[UIView alloc] init];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = PPAdFormAccentColor();
    accentBar.layer.cornerRadius = 3.0;
    [container addSubview:accentBar];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = PPAdFormPrimaryTextColor();
    titleLabel.text = title ?: @"";
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [container addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.88];
    subtitleLabel.text = subtitle ?: @"";
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
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

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSArray<NSString *> *content = [self pp_sectionHeaderContentForSection:section];
    return [self pp_sectionHeaderViewForTitle:content.firstObject subtitle:content.lastObject];
}

 

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 1 || indexPath.row == 2) {
        return 74.0;
    }
    
    return UITableViewAutomaticDimension;
}



- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section
{
    return [self tableView:tableView heightForHeaderInSection:section];
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

// Style cell before display and after creation
- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = UIColor.clearColor;
    cell.clipsToBounds = NO;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.contentView.backgroundColor = [self pp_adSurfaceColor];
    cell.contentView.layer.cornerRadius = 20.0;
    cell.contentView.layer.masksToBounds = YES;
    cell.contentView.layer.borderWidth = 1.0;
    [cell.contentView pp_setBorderColor:[self pp_adSurfaceBorderColor]];
    [cell pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    cell.layer.shadowOpacity = 0.05;
    cell.layer.shadowRadius = 12.0;
    cell.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    cell.layer.masksToBounds = NO;
}

// cellForRowAtIndexPath moved to Form Field Helpers section above
 

// Removed didHighlightItemAtIndexPath to fix out-of-bounds and confusion with image index.

- (void)initBase {
    self.uploadManager = [FileUploadManager new];
    self.formSections = [NSMutableArray array];
    self.selectedAdCoordinate = kCLLocationCoordinate2DInvalid;
    self.hasSelectedAdCoordinate = NO;
    self.selectedAdLocationName = nil;
    self.formDisabled = NO;
    
    
    // Auto-detect edit mode if editingAd was set but mode was not
    if (self.editingAd && self.mode == AdEditorModeCreate) {
        self.mode = AdEditorModeEdit;
    }

    if (self.mode == AdEditorModeCreate) {
        self.adModel = [PetAd new];
    } else {
        if (self.editingAd) {
            self.adModel =
            [[PetAd alloc] initWithDictionary:[self.editingAd toFirestoreDictionary]
                                    documentID:self.editingAd.adID];
            self.adModel.adID = self.editingAd.adID;
            self.adModel.ownerID = self.editingAd.ownerID;
            self.adModel.postedDate = self.editingAd.postedDate;
            if (self.adModel.status == 0) {
                self.adModel.status = self.editingAd.status;
            }
        } else {
            self.adModel = [PetAd new];
        }
    }
    
}

#pragma mark - Form Field Helpers

- (PPAdFormField *)fieldForTag:(NSString *)tag {
    for (NSMutableArray<PPAdFormField *> *section in self.formSections) {
        for (PPAdFormField *field in section) {
            if ([field.tag isEqualToString:tag]) return field;
        }
    }
    return nil;
}

- (NSIndexPath *)indexPathForFieldTag:(NSString *)tag {
    for (NSInteger s = 0; s < (NSInteger)self.formSections.count; s++) {
        NSMutableArray<PPAdFormField *> *section = self.formSections[s];
        for (NSInteger r = 0; r < (NSInteger)section.count; r++) {
            if ([section[r].tag isEqualToString:tag]) {
                return [NSIndexPath indexPathForRow:r inSection:s];
            }
        }
    }
    return nil;
}

- (void)pp_reloadFieldWithTag:(NSString *)tag {
    NSIndexPath *ip = [self indexPathForFieldTag:tag];
    if (ip) {
        CGPoint savedOffset = self.tableView.contentOffset;
        [UIView performWithoutAnimation:^{
            [self.tableView reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
        }];
        [self.tableView layoutIfNeeded];
        self.tableView.contentOffset = savedOffset;
    }
}

- (void)pp_presentSelectorForField:(PPAdFormField *)field {
    if (!field.selectorOptions.count) return;
    __weak typeof(self) weakSelf = self;
    PPSelectOptionViewController *vc = [[PPSelectOptionViewController alloc]
        initWithOptions:field.selectorOptions
                  title:field.selectorTitle ?: field.title
                    row:nil
       presentationStyle:PPSelectOptionPresentationSheet
             completion:^(id _Nullable selectedObject) {
        dispatch_async(dispatch_get_main_queue(), ^{
            id oldValue = field.value;
            field.value = selectedObject;
            if (field.onChangeBlock) field.onChangeBlock(oldValue, selectedObject);
            [weakSelf pp_reloadFieldWithTag:field.tag];
            if (!weakSelf.isHydratingFormData) {
                weakSelf.hasUserModifiedForm = YES;
            }
        });
    }];
    [self presentViewController:vc animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.formSections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section < 0 || section >= (NSInteger)self.formSections.count) return 0;
    return self.formSections[section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPAdFormField *field = self.formSections[indexPath.section][indexPath.row];
    __weak typeof(self) weakSelf = self;
    BOOL effectiveDisabled = field.disabled || self.formDisabled;

    switch (field.fieldType) {
        case PPAdFieldTypeText:
        case PPAdFieldTypeInteger: {
            PPAdTextFieldCell *cell = [tableView dequeueReusableCellWithIdentifier:PPAdTextFieldCellID forIndexPath:indexPath];
            [cell configureWithField:field];
            cell.textField.enabled = !effectiveDisabled;
            [cell applyDisabledState:effectiveDisabled];
            cell.onValueChanged = ^(NSString *text) {
                id oldValue = field.value;
                if (field.fieldType == PPAdFieldTypeInteger) {
                    field.value = text.length > 0 ? @(text.integerValue) : nil;
                } else {
                    field.value = text;
                }
                if (field.onChangeBlock) field.onChangeBlock(oldValue, field.value);
                if (!weakSelf.isHydratingFormData) weakSelf.hasUserModifiedForm = YES;
            };
            return cell;
        }
        case PPAdFieldTypeSelector: {
            PPAdSelectorCell *cell = [tableView dequeueReusableCellWithIdentifier:PPAdSelectorCellID forIndexPath:indexPath];
            [cell configureWithField:field];
            cell.userInteractionEnabled = !effectiveDisabled;
            [cell applyDisabledState:effectiveDisabled];
            return cell;
        }
        case PPAdFieldTypeSwitch: {
            PPAdSwitchCell *cell = [tableView dequeueReusableCellWithIdentifier:PPAdSwitchCellID forIndexPath:indexPath];
            [cell configureWithField:field];
            cell.toggleSwitch.enabled = !effectiveDisabled;
            [cell applyDisabledState:effectiveDisabled];
            cell.onSwitchChanged = ^(BOOL isOn) {
                id oldValue = field.value;
                field.value = @(isOn);
                if (field.onChangeBlock) field.onChangeBlock(oldValue, field.value);
                if (!weakSelf.isHydratingFormData) weakSelf.hasUserModifiedForm = YES;
            };
            return cell;
        }
        case PPAdFieldTypeTextView: {
            PPAdTextViewCell *cell = [tableView dequeueReusableCellWithIdentifier:PPAdTextViewCellID forIndexPath:indexPath];
            [cell configureWithField:field];
            cell.textView.editable = !effectiveDisabled;
            [cell applyDisabledState:effectiveDisabled];
            cell.onTextChanged = ^(NSString *text) {
                id oldValue = field.value;
                field.value = text;
                if (field.onChangeBlock) field.onChangeBlock(oldValue, text);
                if (!weakSelf.isHydratingFormData) weakSelf.hasUserModifiedForm = YES;
            };
            return cell;
        }
    }
    return [UITableViewCell new];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.formDisabled) return;
    PPAdFormField *field = self.formSections[indexPath.section][indexPath.row];
    
    if ([field.tag isEqualToString:kadLocation]) {
        [self pp_presentAdLocationPicker];
        return;
    }
    if (field.fieldType == PPAdFieldTypeSelector && !field.disabled) {
        [self pp_presentSelectorForField:field];
    }
}

#pragma mark - Build Form
- (void)initForm {
    
    __weak typeof(self) weakSelf = self;
    CGFloat rowHeight = 64;

    // Section 0: Basic Info
    NSMutableArray<PPAdFormField *> *basicSection = [NSMutableArray array];

    PPAdFormField *titleField = [PPAdFormField new];
    titleField.tag = @"adTitle";
    titleField.title = kLang(@"adTitle");
    titleField.placeholder = kLang(@"enter_title");
    titleField.fieldType = PPAdFieldTypeText;
    titleField.required = YES;
    titleField.height = rowHeight;
    titleField.onChangeBlock = ^(id oldValue, id newValue) {
        weakSelf.adModel.adTitle = newValue;
    };
    [basicSection addObject:titleField];

    if (self.selectedMainKind) {
        weakSelf.selectedKind = self.selectedMainKind;
        weakSelf.adModel.category = self.selectedMainKind.ID;

        PPAdFormField *subField = [PPAdFormField new];
        subField.tag = ksubcategory;
        subField.title = kLang(@"Breed");
        subField.selectorTitle = kLang(@"Breed");
        subField.fieldType = PPAdFieldTypeSelector;
        subField.required = YES;
        subField.height = rowHeight;
        subField.disabled = NO;
        subField.selectorOptions = self.selectedMainKind.SubKindsArray ?: @[];
        subField.onChangeBlock = ^(id oldValue, id newValue) {
            if (![newValue isKindOfClass:[SubKindModel class]]) return;
            weakSelf.adModel.subcategory = ((SubKindModel *)newValue).ID;
        };
        [basicSection addObject:subField];
    } else {
        PPAdFormField *catField = [PPAdFormField new];
        catField.tag = kcategory;
        catField.title = kLang(@"Species");
        catField.selectorTitle = kLang(@"Species");
        catField.fieldType = PPAdFieldTypeSelector;
        catField.required = YES;
        catField.height = rowHeight;
        catField.selectorOptions = MKM.MainKindsArray;
        catField.onChangeBlock = ^(id oldValue, id newValue) {
            PPAdFormField *subF = [weakSelf fieldForTag:ksubcategory];
            if (![newValue isKindOfClass:[MainKindsModel class]]) {
                weakSelf.selectedKind = nil;
                weakSelf.adModel.category = 0;
                subF.disabled = YES; subF.selectorOptions = @[]; subF.value = nil;
                [weakSelf pp_reloadFieldWithTag:ksubcategory];
                return;
            }
            MainKindsModel *kind = newValue;
            weakSelf.selectedKind = kind;
            weakSelf.adModel.category = kind.ID;
            subF.disabled = NO;
            subF.selectorOptions = kind.SubKindsArray ?: @[];
            [weakSelf pp_reloadFieldWithTag:ksubcategory];
        };
        [basicSection addObject:catField];

        PPAdFormField *subField = [PPAdFormField new];
        subField.tag = ksubcategory;
        subField.title = kLang(@"Breed");
        subField.selectorTitle = kLang(@"Breed");
        subField.fieldType = PPAdFieldTypeSelector;
        subField.required = YES;
        subField.height = rowHeight;
        subField.disabled = YES;
        subField.onChangeBlock = ^(id oldValue, id newValue) {
            if (![newValue isKindOfClass:[SubKindModel class]]) return;
            weakSelf.adModel.subcategory = ((SubKindModel *)newValue).ID;
        };
        [basicSection addObject:subField];
    }
    [self.formSections addObject:basicSection];

    // Section 1: Pet Details
    NSMutableArray<PPAdFormField *> *petSection = [NSMutableArray array];

    PPAdFormField *genderField = [PPAdFormField new];
    genderField.tag = @"isFemale";
    genderField.title = kLang(@"isFemale");
    genderField.fieldType = PPAdFieldTypeSwitch;
    genderField.value = @(weakSelf.adModel.isFemale);
    genderField.height = rowHeight;
    genderField.onChangeBlock = ^(id oldValue, id newValue) {
        weakSelf.adModel.isFemale = [newValue boolValue];
    };
    [petSection addObject:genderField];

    PPAdFormField *ageField = [PPAdFormField new];
    ageField.tag = kpetAge;
    ageField.title = kLang(@"age_months");
    ageField.placeholder = kLang(@"enter_pet_age_in_months");
    ageField.fieldType = PPAdFieldTypeInteger;
    ageField.required = YES;
    ageField.height = rowHeight;
    ageField.onChangeBlock = ^(id oldValue, id newValue) {
        weakSelf.adModel.petAgeMonths = newValue;
    };
    [petSection addObject:ageField];
    [self.formSections addObject:petSection];

    // Section 2: Listing Details
    NSMutableArray<PPAdFormField *> *listingSection = [NSMutableArray array];

    PPAdFormField *priceField = [PPAdFormField new];
    priceField.tag = kprice;
    priceField.title = kLang(@"price");
    priceField.placeholder = kLang(@"enter_price");
    priceField.fieldType = PPAdFieldTypeInteger;
    priceField.required = YES;
    priceField.height = rowHeight;
    priceField.onChangeBlock = ^(id oldValue, id newValue) {
        weakSelf.adModel.price = newValue;
    };
    [listingSection addObject:priceField];

    PPAdFormField *locationField = [PPAdFormField new];
    locationField.tag = kadLocation;
    locationField.title = kLang(@"adLocation");
    locationField.selectorTitle = kLang(@"select_location");
    locationField.placeholder = kLang(@"select_location");
    locationField.fieldType = PPAdFieldTypeSelector;
    locationField.required = YES;
    locationField.height = rowHeight + 6;
    locationField.onChangeBlock = ^(id oldValue, id newValue) {
        if (newValue && [newValue isKindOfClass:NSString.class]) {
            weakSelf.adModel.locationName = (NSString *)newValue;
        }
    };
    [listingSection addObject:locationField];

    PPAdFormField *descField = [PPAdFormField new];
    descField.tag = kdesc;
    descField.title = nil;
    descField.placeholder = kLang(@"enter_description");
    descField.fieldType = PPAdFieldTypeTextView;
    descField.height = 116;
    descField.required = YES;
    descField.onChangeBlock = ^(id oldValue, id newValue) {
        weakSelf.adModel.adDescription = newValue;
    };
    [listingSection addObject:descField];
    [self.formSections addObject:listingSection];

    [self.tableView registerClass:[PPAdTextFieldCell class] forCellReuseIdentifier:PPAdTextFieldCellID];
    [self.tableView registerClass:[PPAdSelectorCell class] forCellReuseIdentifier:PPAdSelectorCellID];
    [self.tableView registerClass:[PPAdSwitchCell class] forCellReuseIdentifier:PPAdSwitchCellID];
    [self.tableView registerClass:[PPAdTextViewCell class] forCellReuseIdentifier:PPAdTextViewCellID];

    self.tableView.estimatedSectionFooterHeight = 0.000001;
    self.tableView.sectionFooterHeight = 0.000001;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 68.0;
}


#pragma mark - Prefill when Editing

- (void)configureForEditingIfNeeded {
    if (self.mode != AdEditorModeEdit || !self.editingAd) return;
    
    // Use the passed model as source-of-truth
    //self.adModel = self.editingAd;
    self.adModel =
    [[PetAd alloc] initWithDictionary:[self.editingAd toFirestoreDictionary]
                            documentID:self.editingAd.adID];
    // 🔒 Protect immutable fields
    self.adModel.adID = self.editingAd.adID;
    self.adModel.ownerID = self.editingAd.ownerID;
    self.adModel.postedDate = self.editingAd.postedDate;

    // Editing does NOT reset status unless explicitly changed
    if (self.adModel.status == 0) {
        self.adModel.status = self.editingAd.status;
    }
    
    // Prefill category + subcategory
    MainKindsModel *kind = [MKM mainKindForID:self.adModel.category];
    if (kind) {
        self.selectedKind = kind;
        [self fieldForTag:kcategory].value = kind;
        [self fieldForTag:ksubcategory].disabled = NO;
        [self fieldForTag:ksubcategory].selectorOptions = kind.SubKindsArray;
        
        SubKindModel *sub = [kind subKindForID:self.adModel.subcategory];
        if (!sub) {
            // fallback: find in array by ID
            for (SubKindModel *s in kind.SubKindsArray) if (s.ID == self.adModel.subcategory) { sub = s; break; }
        }
        [self fieldForTag:ksubcategory].value = sub;
        [self pp_reloadFieldWithTag:kcategory];
        [self pp_reloadFieldWithTag:ksubcategory];
    }
    
    // Prefill scalar fields
    [self fieldForTag:kpetAge].value = self.adModel.petAgeMonths;
    [self fieldForTag:kprice].value  = self.adModel.price;
    [self fieldForTag:kdesc].value   = self.adModel.adDescription;
    [self fieldForTag:@"adTitle"].value   = self.adModel.adTitle;
    [self fieldForTag:@"isFemale"].value  = @(self.adModel.isFemale);
    NSString *prefillLocation = self.adModel.locationName;
    if (prefillLocation.length == 0 && self.adModel.adLocation > 0) {
        prefillLocation = [CitiesManager.shared cityNameForID:self.adModel.adLocation];
    }
    [self fieldForTag:kadLocation].value = prefillLocation;
    self.selectedAdLocationName = prefillLocation;
    self.selectedAdCoordinate = CLLocationCoordinate2DMake(self.adModel.latitude, self.adModel.longitude);
    self.hasSelectedAdCoordinate = PPIsValidAdCoordinate(self.selectedAdCoordinate);
    
    [self.tableView reloadData];
    
    self.didMutateMediaAfterPrefill = NO;
    [self pp_setSubmitEnabled:NO];
    [self prefillPhotosForEdit];
    
}
//self.assetArray
- (void)showPopupPreview:(UIImage *)image {
    
}


#pragma mark - Search Metadata

- (void)prepareSearchMetadataForAd:(PetAd *)ad {

    // Title lowercase index
    ad.name_lowercase = ad.adTitle.lowercaseString ?: @"";

    // Keywords (very important)
    NSMutableSet *keys = [NSMutableSet set];

    if (ad.adTitle.length) {
        [[ad.adTitle.lowercaseString componentsSeparatedByCharactersInSet:
          NSCharacterSet.whitespaceAndNewlineCharacterSet]
         enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
            if (obj.length > 1) [keys addObject:obj];
        }];
    }
    
    
    PPAdFormField *subField = [self fieldForTag:ksubcategory];
    if (subField.value &&
        [subField.value respondsToSelector:@selector(SubKindName)]) {

        NSString *sub =
        [[subField.value SubKindName] lowercaseString];
        if (sub.length) [keys addObject:sub];
    }
    
    

    if (self.selectedKind.KindName.length) {
        [keys addObject:self.selectedKind.KindName.lowercaseString];
    }

    ad.keywords = keys.allObjects;
}

- (void)setBackAndCorners
{
    self.view.layer.cornerRadius = 0.0;
    self.view.clipsToBounds = NO;
    self.view.backgroundColor = [self pp_adCanvasColor];
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
    self.tableView.layer.cornerRadius = 0.0;
    self.tableView.clipsToBounds = NO;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self pp_updateFormHeroHeaderLayoutIfNeeded];
    [self pp_updateImageCollectionFooterLayoutIfNeeded];
   /*
    if (!self.uploadProgressView) {
        GSIndeterminateProgressView *pv = [[GSIndeterminateProgressView alloc] initWithFrame:CGRectMake(0,  self.navigationController.navigationBar.hx_maxy , self.view.hx_w, 4)];
        pv.progressTintColor = [GM appPrimaryColor];
        pv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        pv.backgroundColor = [PPColorUtils pp_selectedCellColorFromPrimary]; //UIColor.whiteColor;
        [self.view addSubview:pv];
        self.uploadProgressView = pv;
    }
    */
}





-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    self.tableView.alpha = 1;

    self.imageCollection.layer.cornerRadius = 0.0;
    self.imageCollection.layer.borderWidth = 0.0;
    self.imageCollection.layer.shadowOpacity = 0.0;
    self.imageCollection.layer.shadowRadius = 0.0;
    self.imageCollection.layer.shadowOffset = CGSizeZero;
    self.imageCollection.layer.shadowPath = nil;
    self.imageCollection.layer.masksToBounds = NO;
    self.imageCollection.backgroundColor = UIColor.clearColor;

    if (self.formHeroCardView) {
        self.formHeroCardView.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:self.formHeroCardView.bounds
                                       cornerRadius:self.formHeroCardView.layer.cornerRadius].CGPath;
    }
    [self.view bringSubviewToFront:self.tableView];
    if (self.imageCollection.superview == self.view) {
        [self.view bringSubviewToFront:self.imageCollection];
    }
    
}

- (void)pp_updateFormHeroHeaderLayoutIfNeeded
{
    if (!self.formHeroContainerView) {
        return;
    }

    CGFloat fullWidth = CGRectGetWidth(self.tableView.bounds);
    if (fullWidth <= 0.0) {
        fullWidth = CGRectGetWidth(self.view.bounds);
    }
    if (fullWidth <= 0.0) {
        return;
    }

    CGFloat targetHeight = [self pp_formHeroHeaderHeightForWidth:fullWidth];

    if (fabs(self.lastAppliedFormHeroHeaderHeight - targetHeight) > 0.5 ||
        fabs(self.lastAppliedFormHeroHeaderWidth - fullWidth) > 0.5) {
        self.lastAppliedFormHeroHeaderHeight = targetHeight;
        self.lastAppliedFormHeroHeaderWidth = fullWidth;
        CGRect headerFrame = self.formHeroContainerView.frame;
        headerFrame.size.height = targetHeight;
        headerFrame.origin.x = 0.0;
        headerFrame.origin.y = 0.0;
        headerFrame.size.width = fullWidth;
        self.formHeroContainerView.frame = headerFrame;
        self.tableView.tableHeaderView = self.formHeroContainerView;
    }
}

- (void)saveFormData:(UIBarButtonItem *)sender {
    if (self.isSubmittingAd) {
        return;
    }

    if (self.mode == AdEditorModeEdit && self.isPrefillInProgress) {
        NSString *title = [self pp_localizedStringForKey:@"loading_images" fallback:@"Loading images..."];
        NSString *subtitle = [self pp_localizedStringForKey:@"please_wait_prefill"
                                                    fallback:@"Please wait until images finish loading."];
        [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
        return;
    }

    if (self.mode == AdEditorModeEdit) {
        [self updateAdFlow];
    } else {
        [self createAdFlow];
    }
    
}


#pragma mark - Submit flows
#pragma mark - Unified Submit Handler
- (void)pp_handleAdSubmitIsEditing:(BOOL)isEditing {
    if (self.isSubmittingAd) {
        return;
    }
    [PPHUD dismiss];

    if (isEditing && self.isPrefillInProgress) {
        NSString *title = [self pp_localizedStringForKey:@"loading_images" fallback:@"Loading images..."];
        NSString *subtitle = [self pp_localizedStringForKey:@"please_wait_prefill"
                                                    fallback:@"Please wait until images finish loading."];
        [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
        return;
    }

    // 1️⃣ Validate user form
    NSMutableArray *errors = [NSMutableArray array];
    for (NSMutableArray<PPAdFormField *> *section in self.formSections) {
        for (PPAdFormField *f in section) {
            if (f.required && (f.value == nil || ([f.value isKindOfClass:NSString.class] && [f.value length] == 0))) {
                [errors addObject:f];
            }
        }
    }
    if (errors.count > 0) {
        [self highlightErrors:errors];
        return;
    }

    // 1b – Custom field-level validation
    PPAdFormField *priceF = [self fieldForTag:kprice];
    PPAdFormField *ageF = [self fieldForTag:kpetAge];

    if ([priceF.value respondsToSelector:@selector(integerValue)] &&
        [priceF.value integerValue] <= 0) {
        NSString *title = [self pp_localizedStringForKey:@"error" fallback:@"Error"];
        NSString *subtitle = [self pp_localizedStringForKey:@"validation_price_invalid"
                                                    fallback:@"Please enter a valid price greater than zero."];
        UITableViewCell *priceCell = [self.tableView cellForRowAtIndexPath:[self indexPathForFieldTag:kprice]];
        [GM animateCell:priceCell];
        [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
        return;
    }

    if ([ageF.value respondsToSelector:@selector(integerValue)] &&
        [ageF.value integerValue] <= 0) {
        NSString *title = [self pp_localizedStringForKey:@"error" fallback:@"Error"];
        NSString *subtitle = [self pp_localizedStringForKey:@"validation_age_invalid"
                                                    fallback:@"Please enter a valid age in months."];
        UITableViewCell *ageCell = [self.tableView cellForRowAtIndexPath:[self indexPathForFieldTag:kpetAge]];
        [GM animateCell:ageCell];
        [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
        return;
    }

    if (!isEditing && ![self pp_validateCreateHasAtLeastOneImage]) {
        return;
    }

    if (![self pp_validateAdLocationBeforeSubmit]) {
        return;
    }

    if (![self pp_ensureAuthenticatedSessionForSubmit]) {
        return;
    }
    
    // 2️⃣ Prepare the ad model
    if (!isEditing) {
        if (self.createFlowAdID.length == 0) {
            self.createFlowAdID = NSUUID.UUID.UUIDString;
        }
        self.adModel.adID = self.createFlowAdID;
        if (!self.adModel.postedDate) {
            self.adModel.postedDate = NSDate.date;
        }
        self.adModel.ownerID = [self pp_submitOwnerID];

        // 🔥 New production defaults
        self.adModel.status = PetAdStatusActive;
        self.adModel.visibility = PetAdVisibilityPublic;

        self.adModel.favoritesCount = @(0);
        self.adModel.sharesCount = @(0);

        self.adModel.rankScore = @(0);
        self.adModel.priorityScore = @(0);

        self.adModel.isMine = YES;
        self.adModel.isFavorite = NO;
        self.adModel.isApproved = YES;
        self.adModel.isDeleted = NO;
        self.adModel.isBlocked = NO;
    }

    [self prepareSearchMetadataForAd:self.adModel];
    
    // 3️⃣ Upload media + save on server
    [self sendFormDataToServerIsEditing:isEditing];
}
#pragma mark - Create / Update Entry Points
- (void)createAdFlow {
    [self pp_handleAdSubmitIsEditing:NO];
}

- (void)updateAdFlow {
    [self pp_handleAdSubmitIsEditing:YES];
}


- (void)highlightErrors:(NSArray *)errors {
    for (PPAdFormField *field in errors) {
        NSIndexPath *ip = [self indexPathForFieldTag:field.tag];
        if (ip) {
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:ip];
            [GM animateCell:cell];
        }
    }
    NSString *title = [self pp_localizedStringForKey:@"error" fallback:@"Error"];
    NSString *subtitle = [self pp_localizedStringForKey:@"validation_fill_required"
                                                fallback:@"Please fill in all required fields."];
    [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
}

- (BOOL)pp_validateAdLocationBeforeSubmit
{
    if (!self.hasSelectedAdCoordinate || !PPIsValidAdCoordinate(self.selectedAdCoordinate)) {
        NSString *title = kLang(@"Location");
        NSString *subtitle = [self pp_localizedStringForKey:@"location_invalid"
                                                    fallback:@"Please choose a valid location from the map."];
        [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
        return NO;
    }

    self.adModel.latitude = self.selectedAdCoordinate.latitude;
    self.adModel.longitude = self.selectedAdCoordinate.longitude;
    self.adModel.locationName = self.selectedAdLocationName.length
        ? self.selectedAdLocationName
        : ([self fieldForTag:kadLocation].value ?: @"");

    return [self.adModel hasValidGeoLocation];
}


#pragma mark - Submit to Server (Refactored)
- (void)sendFormDataToServerIsEditing:(BOOL)isEditing
{
    NSArray<UIImage *> *imagesToUpload = [self safeMediaOutputArray];
    self.isSubmittingAd = YES;
    [self pp_refreshFormHeroContent];

    [self pp_showUploadIndicatorOnNavBar];
    [self pp_setCircularUploadProgressVisible:YES];
    [self pp_updateCircularUploadProgress:0.0];
    [self pp_setSubmitEnabled:NO];
    [self pp_setMediaLoadingVisible:NO textKey:@"uploading_images" fallback:@"Uploading images..."];

    dispatch_async(dispatch_get_main_queue(), ^{
        self.formDisabled = YES;
        [self.tableView reloadData];
        self.imageCollection.userInteractionEnabled = NO;
    });

    if (isEditing) {
        [self pp_updateExistingAdWithImages:imagesToUpload];
    } else {
        [self pp_createNewAdWithImages:imagesToUpload];
    }
}
- (void)pp_showUploadIndicatorOnNavBar
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.ppOriginalRightItem) {
            self.ppOriginalRightItem = self.navigationItem.rightBarButtonItem;
        }

        self.navigationItem.rightBarButtonItem =
            [self pp_uploadSpinnerBarItem];
    });
}


- (void)pp_createNewAdWithImages:(NSArray<UIImage *> *)images
{
    if (self.adModel.adID.length == 0) {
        [self pp_handleSubmitFailure:[self pp_uploadErrorWithCode:406 description:@"Missing adID before create flow."]];
        return;
    }

    self.adModel.imageItems = @[];
    [self prepareSearchMetadataForAd:self.adModel];

    __weak typeof(self) weakSelf = self;
    [[PetAdManager sharedManager] addPetAd:self.adModel
                                completion:^(NSError *error)
    {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        if (error) {
            [self pp_handleSubmitFailure:error];
            return;
        }

        if (images.count == 0) {
            [self pp_finishCreateSuccess];
            return;
        }

        [self uploadUIImages:images
                       forAd:self.adModel
                   completion:^(PetAd *updatedAd, NSError *uploadError)
        {
            if (uploadError) {
                [self pp_cleanupFailedCreatedAd:self.adModel originalError:uploadError];
                return;
            }

            [self prepareSearchMetadataForAd:updatedAd];
            [[PetAdManager sharedManager] updatePetAd:updatedAd
                                           completion:^(NSError *updateError)
            {
                if (updateError) {
                    [self pp_cleanupFailedCreatedAd:updatedAd originalError:updateError];
                    return;
                }

                self.adModel = updatedAd;
                [self pp_finishCreateSuccess];
            }];
        }];
    }];
}

- (void)pp_updateExistingAdWithImages:(NSArray<UIImage *> *)images
{
    
    NSArray *originalImageItems = self.editingAd.imageItems ?: @[];
    
    
    void (^performUpdate)(void) = ^{
        [self prepareSearchMetadataForAd:self.adModel];
        [[PetAdManager sharedManager] updatePetAd:self.adModel
                                       completion:^(NSError *error)
        {
            if (error) {
                NSLog(@"❌ [UpdateAd] Firestore update failed: %@", error);
                [self pp_handleSubmitFailure:error];
                return;
            }
            [self pp_finishUpdateSuccess];
        }];
    };

    if (!self.didMutateMediaAfterPrefill) {
        self.adModel.imageItems = originalImageItems;
        performUpdate();
        return;
    }
    
    
    // User changed media and removed all images.
    if (images.count == 0) {
        self.adModel.imageItems = @[];
        performUpdate();
        return;
    }

    // Upload images first
    [self uploadUIImages:images
                   forAd:self.adModel
               completion:^(PetAd *updatedAd, NSError *error)
    {
        if (error) {
            NSLog(@"❌ [UpdateAd] Image upload failed: %@", error);
            [self pp_handleSubmitFailure:error];
            return;
        }

        self.adModel = updatedAd;
        self.didMutateMediaAfterPrefill = NO;
        performUpdate();
    }];
}

- (void)pp_finishCreateSuccess
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.createFlowAdID = nil;
        [[NSNotificationCenter defaultCenter]
         postNotificationName:PPAdDidFinishUploadNotification
         object:nil
         userInfo:@{
            @"ad": self.adModel,
            @"isEditing": @(NO)
         }];

        if ([self.delegate respondsToSelector:@selector(addNewAd:didCreateAd:)]) {
            [self.delegate addNewAd:self didCreateAd:self.adModel];
        }

        [self clearSavedDraft];
        [self pp_finishSubmitUI];
        [self closeAfterSuccess:NO];
    });
}

- (void)pp_finishUpdateSuccess
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.didMutateMediaAfterPrefill = NO;
        [[NSNotificationCenter defaultCenter]
         postNotificationName:PPAdDidFinishUploadNotification
         object:nil
         userInfo:@{
            @"ad": self.adModel,
            @"isEditing": @(YES)
         }];

        if ([self.delegate respondsToSelector:@selector(addNewAd:didUpdateAd:)]) {
            [self.delegate addNewAd:self didUpdateAd:self.adModel];
        }

        [self clearSavedDraft];
        [self pp_finishSubmitUI];
        [self closeAfterSuccess:YES];
    });
}

- (void)pp_handleSubmitFailure:(NSError *)error
{
    NSString *title = [self pp_localizedStringForKey:@"error" fallback:@"Error"];
    NSString *fallbackSubtitle =
        [self pp_localizedStringForKey:@"submit_failed"
                              fallback:@"Unable to save your ad right now. Please try again."];
    NSLog(@"❌ [AdSubmit] Failure | domain=%@ | code=%ld | message=%@",
          error.domain ?: @"",
          (long)error.code,
          error.localizedDescription ?: @"");
    NSString *subtitle = [self pp_userFacingSubmitMessageForError:error
                                                         fallback:fallbackSubtitle];
    dispatch_async(dispatch_get_main_queue(), ^{
        [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
        [self pp_finishSubmitUI];
    });
}






- (void)pp_hideUploadIndicatorOnNavBar
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.ppUploadSpinner stopAnimating];

        if (self.ppOriginalRightItem) {
            self.ppOriginalRightItem.enabled = (!self.isSubmittingAd && !self.isPrefillInProgress);
            self.navigationItem.rightBarButtonItem =
                self.ppOriginalRightItem;
        }

        self.ppOriginalRightItem = nil;
    });
}






- (void)pp_finishSubmitUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isSubmittingAd = NO;
        self.formDisabled = NO;
        [self pp_refreshFormHeroContent];
        [self.tableView reloadData];
        self.imageCollection.userInteractionEnabled = !self.isPrefillInProgress;
        [self pp_setCircularUploadProgressVisible:NO];

        if (self.isPrefillInProgress) {
            [self pp_setMediaLoadingVisible:YES textKey:@"loading_images" fallback:@"Loading images..."];
        } else {
            [self pp_setMediaLoadingVisible:NO textKey:@"uploading_images" fallback:@"Uploading images..."];
        }

        [self pp_setSubmitEnabled:!self.isPrefillInProgress];

        [self pp_hideUploadIndicatorOnNavBar];
    });
}

- (void)closeAfterSuccess:(BOOL)isEditing {
    // Success alert
    NSString *title = isEditing
        ? [self pp_localizedStringForKey:@"adUpdatedTitle" fallback:@"Ad updated"]
        : [self pp_localizedStringForKey:@"adDoneTitle" fallback:@"Ad posted"];
    NSString *msg = isEditing
        ? [self pp_localizedStringForKey:@"adUpdatedDesc" fallback:@"Your ad was updated successfully."]
        : [self pp_localizedStringForKey:@"adDoneDesc" fallback:@"Your ad was posted successfully."];
    
    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showSuccessIn:self title:title subtitle:msg confirmAction:^(NSString * _Nullable text, BOOL didConfirm) {
        if(!didConfirm) return;
        [weakSelf pp_dismissForm];
    } cancelAction:^{
        
    }];
   
    
}

#pragma mark - Close / nav

- (void)closeForm:(UIBarButtonItem *)sender {
    (void)sender;
    [self pp_handleBackNavigation];
}

- (void)onBack
{
    [self pp_handleBackNavigation];
}

- (void)onBack:(id)sender
{
    (void)sender;
    [self pp_handleBackNavigation];
}




#pragma mark - Progress bar host



-(void)dismiss
{
    [self popoverPresentationController];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_setPremiumTabDockHidden:YES animated:animated];
    //[PPBarMgr hide];
    self.view.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    self.tableView.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    self.imageCollectionFooterContainerView.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    [self pp_refreshMediaLocalizedText];
    [self pp_updateImageCollectionFooterLayoutIfNeeded];
    
    if(!self.presented)
    {
         self.presented=YES;
    }
    
   
    NSString *title = (self.mode == AdEditorModeEdit)? kLang(@"EditAdTitle")   : kLang(@"PostAdTitle");       // add to Localizable
    NSString *subKindName = nil;
    if (self.selectedMainKind) {  subKindName = [NSString stringWithFormat:@"%@",self.selectedMainKind.KindName]; }
 
    
     [self ios26Bar];
    [self pp_setSubmitEnabled:!self.isSubmittingAd && !self.isPrefillInProgress];
    
    UIView *topView = [self pp_modernBlurTitleViewWithTitle:title
                                                   subtitle:subKindName ?: nil];
    [self pp_navBarSetTitleViewCenteredSmallWidth:topView];
  
}

- (void)pp_setPremiumTabDockHidden:(BOOL)hidden animated:(BOOL)animated
{
    if ([self.tabBarController respondsToSelector:@selector(setPremiumTabDockViewHidden:animation:)]) {
        [(id)self.tabBarController setPremiumTabDockViewHidden:hidden animation:animated];
    }
}

- (UIView *)pp_modernBlurTitleViewWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
    NSString *safeTitle = title ?: @"";
    NSString *safeSubtitle = subtitle ?: @"";
    UIFont *titleFont = [GM boldFontWithSize:16];
    UIFont *subtitleFont = [GM MidFontWithSize:12];
    CGFloat maxWidth = MIN(UIScreen.mainScreen.bounds.size.width * 0.62, 240.0);

    CGFloat titleWidth =
    ceil([safeTitle boundingRectWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)
                                 options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                              attributes:@{NSFontAttributeName: titleFont}
                                 context:nil].size.width);

    CGFloat subtitleWidth = 0.0;
    if (safeSubtitle.length) {
        subtitleWidth =
        ceil([safeSubtitle boundingRectWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)
                                        options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                     attributes:@{NSFontAttributeName: subtitleFont}
                                        context:nil].size.width);
    }

    CGFloat width = MIN(MAX(MAX(titleWidth, subtitleWidth) + 36.0, 156.0), maxWidth);
    CGFloat height = safeSubtitle.length ? 50.0 : 42.0;

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    container.backgroundColor = AppClearClr;
    container.userInteractionEnabled = NO;
    container.semanticContentAttribute =
    Language.isRTL ? UISemanticContentAttributeForceRightToLeft
                   : UISemanticContentAttributeForceLeftToRight;

    CGFloat cornerRadius = height / 2.0;
    container.layer.cornerRadius = cornerRadius;
    container.layer.borderWidth = 0.0;
    [container pp_setBorderColor:[[UIColor clearColor] colorWithAlphaComponent:0.0]];
    [container pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:0.0]];
    container.layer.shadowOffset = CGSizeMake(0, 0);
    container.layer.shadowOpacity = 0.00;
    container.layer.shadowRadius = 0.0;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = safeSubtitle.length ? 1.0 : 0.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.userInteractionEnabled = NO;
    [container addSubview:stack];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.font = titleFont;
    titleLabel.textColor = AppPrimaryTextClr;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    titleLabel.numberOfLines = 1;
    titleLabel.text = safeTitle;
    [stack addArrangedSubview:titleLabel];

    if (safeSubtitle.length) {
        UILabel *subtitleLabel = [[UILabel alloc] init];
        subtitleLabel.font = subtitleFont;
        subtitleLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.72];
        subtitleLabel.textAlignment = NSTextAlignmentCenter;
        subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        subtitleLabel.numberOfLines = 1;
        subtitleLabel.text = safeSubtitle;
        [stack addArrangedSubview:subtitleLabel];
    }

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:container.leadingAnchor constant:22.0],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor constant:-22.0],
        [stack.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:container.centerYAnchor]
    ]];

    return container;
}



- (UIView *)pp_navigationTitleViewWithTitle:(NSString *)title
                                   subtitle:(NSString * _Nullable)subtitle
                                   textColor:(UIColor * _Nullable)textColor
                                       image:(UIImage * _Nullable)image
                              showBackground:(BOOL)showBackground
{
    UIButtonConfiguration *cfg = nil;

    if (@available(iOS 26.0, *)) {
        // 🧊 Native iOS 26 glass button
        cfg = showBackground
            ? [UIButtonConfiguration glassButtonConfiguration]
            : [UIButtonConfiguration plainButtonConfiguration];

        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.buttonSize  = UIButtonConfigurationSizeMedium;

        cfg.baseForegroundColor = textColor ?: AppPrimaryTextClr;

        // Title
        cfg.title = title ?: @"";
        cfg.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;

        cfg.titleTextAttributesTransformer =
        ^NSDictionary<NSAttributedStringKey,id> *(NSDictionary<NSAttributedStringKey,id> *incoming) {
            NSMutableDictionary *attrs = incoming.mutableCopy;
            attrs[NSFontAttributeName] = [GM boldFontWithSize:16];
            attrs[NSForegroundColorAttributeName] = textColor ?: AppPrimaryTextClr;
            return attrs;
        };

        // Subtitle (iOS 16+ supported)
        if (subtitle.length > 0) {
            cfg.subtitle = subtitle;
            cfg.subtitleTextAttributesTransformer =
            ^NSDictionary<NSAttributedStringKey,id> *(NSDictionary<NSAttributedStringKey,id> *incoming) {
                NSMutableDictionary *attrs = incoming.mutableCopy;
                attrs[NSFontAttributeName] = [GM MidFontWithSize:13];
                attrs[NSForegroundColorAttributeName] =
                [textColor ?: AppPrimaryTextClr colorWithAlphaComponent:0.75];
                return attrs;
            };
            cfg.titlePadding = 2;
        }

        // Leading icon
        if (image) {
            cfg.image = image;
            cfg.imagePlacement = NSDirectionalRectEdgeLeading;
            cfg.imagePadding = 6;
        }

        if (!showBackground) {
            cfg.background.backgroundColor =
                [UIColor.labelColor colorWithAlphaComponent:0.20];
        }
    }
    else {
        // 🧱 iOS ≤25 fallback (modern pill, blur)
        cfg = [UIButtonConfiguration filledButtonConfiguration];
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.baseForegroundColor = textColor ?: AppPrimaryTextClr;
        cfg.title = title ?: @"";
        cfg.image = image;
    }

    UIButton *button =
        [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.clipsToBounds = YES;
    button.userInteractionEnabled = NO; // titleView behavior

    // Navigation title sizing (important!)
    [NSLayoutConstraint activateConstraints:@[
        [button.heightAnchor constraintGreaterThanOrEqualToConstant:36]
    ]];

    return button;
}

-(void)ios26Bar
{
    NSString *buttonTitle = (self.mode == AdEditorModeEdit) ? kLang(@"saveChanges") : kLang(@"postAd");
    UIButton *savBtn = [PPButtonHelper pp_buttonWithTitle:buttonTitle font:[GM MidFontWithSize:16] imageName:@"" target:self config:[UIButtonConfiguration tintedButtonConfiguration] action:@selector(saveFormData:)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:savBtn];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:PPSYSImage(PPChevronName) style:UIBarButtonItemStylePlain target:self action:@selector(onBack:)];
    [self pp_setSubmitEnabled:!self.isSubmittingAd && !self.isPrefillInProgress];
}

// generateRawWithType and formRowDescriptorValueHasChanged removed — no longer needed













 
#pragma mark - UI Reload

- (void)pp_reloadMediaUI {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_reloadMediaUI];
        });
        return;
    }

    [self pp_refreshFormHeroContent];
}


@end
