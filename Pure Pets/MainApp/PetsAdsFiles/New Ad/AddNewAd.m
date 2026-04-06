#import "AddNewAd.h"
#import "PPImageCollection.h"
#import "PPMenuHelper.h"
#import "LocationPickerViewController.h"
#import "ZYCircleProgressView.h"
#import "PPSelectOptionViewController.h"
#import <Pure_Pets-Swift.h>
#import <math.h>
#import <float.h>

static NSString * const PPAddNewAdUploadErrorDomain = @"PPAddNewAdUploadErrorDomain";
static NSString * const PPAddNewAdLanguageDidChangeNotification = @"LanguageDidChangeNotification";
static NSString * const PPAddNewAdDraftDefaultsPrefix = @"pp.add_pet_ad.draft";
static NSString * const PPAddNewAdDraftFormDataKey = @"formData";
static NSString * const PPAddNewAdDraftImagePathsKey = @"imagePaths";
static NSString * const PPAddNewAdDraftMediaMutatedKey = @"didMutateMedia";
static NSInteger const PPAddNewAdCardBackgroundTag = 73041;

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
    if (self) { _height = 48.0; _required = NO; _disabled = NO; }
    return self;
}
@end

#pragma mark - PPAdTextFieldCell

@interface PPAdTextFieldCell : UITableViewCell <UITextFieldDelegate>
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, copy) void(^onValueChanged)(NSString *text);
@end

@implementation PPAdTextFieldCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.clearColor;

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
        _titleLabel.textColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.9];
        _titleLabel.textAlignment = NSTextAlignmentNatural;
        [self.contentView addSubview:_titleLabel];

        _textField = [[UITextField alloc] init];
        _textField.translatesAutoresizingMaskIntoConstraints = NO;
        _textField.font = [GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightRegular];
        _textField.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
        _textField.textAlignment = NSTextAlignmentNatural;
        _textField.delegate = self;
        _textField.returnKeyType = UIReturnKeyDone;
        [_textField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        [self.contentView addSubview:_textField];

        [NSLayoutConstraint activateConstraints:@[
            [_titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12.0],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20.0],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20.0],
            [_textField.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:6.0],
            [_textField.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_textField.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
            [_textField.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12.0],
            [_textField.heightAnchor constraintGreaterThanOrEqualToConstant:28.0]
        ]];
    }
    return self;
}

- (void)configureWithField:(PPAdFormField *)field {
    self.titleLabel.text = field.title;
    self.textField.placeholder = field.placeholder;
    self.textField.enabled = !field.disabled;
    if (field.fieldType == PPAdFieldTypeInteger) {
        self.textField.keyboardType = UIKeyboardTypeNumberPad;
        self.textField.text = field.value ? [NSString stringWithFormat:@"%@", field.value] : @"";
    } else {
        self.textField.keyboardType = UIKeyboardTypeDefault;
        self.textField.text = [field.value isKindOfClass:NSString.class] ? field.value : @"";
    }
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

@interface PPAdSelectorCell : UITableViewCell
@property (nonatomic, strong) UILabel *fieldTitleLabel;
@property (nonatomic, strong) UILabel *valueLabel;
@property (nonatomic, strong) UIImageView *chevronView;
@end

@implementation PPAdSelectorCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        self.backgroundColor = UIColor.clearColor;

        _fieldTitleLabel = [[UILabel alloc] init];
        _fieldTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _fieldTitleLabel.font = [GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
        _fieldTitleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
        _fieldTitleLabel.textAlignment = NSTextAlignmentNatural;
        [self.contentView addSubview:_fieldTitleLabel];

        _valueLabel = [[UILabel alloc] init];
        _valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _valueLabel.font = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightRegular];
        _valueLabel.textAlignment = NSTextAlignmentNatural;
        [self.contentView addSubview:_valueLabel];

        _chevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
        _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
        _chevronView.tintColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.6];
        _chevronView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_chevronView];

        [_fieldTitleLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
        [_valueLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        [_valueLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

        [NSLayoutConstraint activateConstraints:@[
            [_fieldTitleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20.0],
            [_fieldTitleLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_chevronView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
            [_chevronView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_chevronView.widthAnchor constraintEqualToConstant:12.0],
            [_chevronView.heightAnchor constraintEqualToConstant:14.0],
            [_valueLabel.trailingAnchor constraintEqualToAnchor:_chevronView.leadingAnchor constant:-8.0],
            [_valueLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_valueLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:_fieldTitleLabel.trailingAnchor constant:12.0],
            [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:48.0]
        ]];
    }
    return self;
}

- (void)configureWithField:(PPAdFormField *)field {
    self.fieldTitleLabel.text = field.title;
    NSString *displayValue = nil;
    if (field.value) {
        if ([field.value isKindOfClass:NSString.class]) {
            displayValue = (NSString *)field.value;
        } else if ([field.value respondsToSelector:@selector(KindName)]) {
            displayValue = [field.value KindName];
        } else if ([field.value respondsToSelector:@selector(SubKindName)]) {
            displayValue = [field.value SubKindName];
        } else {
            displayValue = [NSString stringWithFormat:@"%@", field.value];
        }
    }
    if (displayValue.length > 0) {
        self.valueLabel.text = displayValue;
        self.valueLabel.textColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    } else {
        self.valueLabel.text = field.placeholder ?: field.selectorTitle;
        self.valueLabel.textColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.6];
    }
    self.userInteractionEnabled = !field.disabled;
    self.contentView.alpha = field.disabled ? 0.45 : 1.0;
}
@end

#pragma mark - PPAdSwitchCell

@interface PPAdSwitchCell : UITableViewCell
@property (nonatomic, strong) UILabel *fieldTitleLabel;
@property (nonatomic, strong) UISwitch *toggleSwitch;
@property (nonatomic, copy) void(^onSwitchChanged)(BOOL isOn);
@end

@implementation PPAdSwitchCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.clearColor;

        _fieldTitleLabel = [[UILabel alloc] init];
        _fieldTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _fieldTitleLabel.font = [GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
        _fieldTitleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
        _fieldTitleLabel.textAlignment = NSTextAlignmentNatural;
        [self.contentView addSubview:_fieldTitleLabel];

        _toggleSwitch = [[UISwitch alloc] init];
        _toggleSwitch.onTintColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
        _toggleSwitch.translatesAutoresizingMaskIntoConstraints = NO;
        [_toggleSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        [self.contentView addSubview:_toggleSwitch];

        [NSLayoutConstraint activateConstraints:@[
            [_fieldTitleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20.0],
            [_fieldTitleLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_toggleSwitch.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20.0],
            [_toggleSwitch.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_fieldTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_toggleSwitch.leadingAnchor constant:-12.0],
            [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:48.0]
        ]];
    }
    return self;
}

- (void)configureWithField:(PPAdFormField *)field {
    self.fieldTitleLabel.text = field.title;
    self.toggleSwitch.on = [field.value boolValue];
    self.toggleSwitch.enabled = !field.disabled;
}

- (void)switchChanged:(UISwitch *)sender {
    if (self.onSwitchChanged) self.onSwitchChanged(sender.isOn);
}
@end

#pragma mark - PPAdTextViewCell

@interface PPAdTextViewCell : UITableViewCell <UITextViewDelegate>
@property (nonatomic, strong) UILabel *fieldTitleLabel;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (nonatomic, copy) void(^onTextChanged)(NSString *text);
@end

@implementation PPAdTextViewCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.clearColor;

        _fieldTitleLabel = [[UILabel alloc] init];
        _fieldTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _fieldTitleLabel.font = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
        _fieldTitleLabel.textColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.9];
        _fieldTitleLabel.textAlignment = NSTextAlignmentNatural;
        [self.contentView addSubview:_fieldTitleLabel];

        _textView = [[UITextView alloc] init];
        _textView.translatesAutoresizingMaskIntoConstraints = NO;
        _textView.font = [GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightRegular];
        _textView.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
        _textView.backgroundColor = UIColor.clearColor;
        _textView.textAlignment = NSTextAlignmentNatural;
        _textView.delegate = self;
        _textView.scrollEnabled = NO;
        [self.contentView addSubview:_textView];

        _placeholderLabel = [[UILabel alloc] init];
        _placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _placeholderLabel.font = _textView.font;
        _placeholderLabel.textColor = [UIColor.placeholderTextColor colorWithAlphaComponent:0.6];
        _placeholderLabel.textAlignment = NSTextAlignmentNatural;
        [_textView addSubview:_placeholderLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_fieldTitleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12.0],
            [_fieldTitleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20.0],
            [_fieldTitleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20.0],
            [_textView.topAnchor constraintEqualToAnchor:_fieldTitleLabel.bottomAnchor constant:6.0],
            [_textView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
            [_textView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],
            [_textView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10.0],
            [_textView.heightAnchor constraintGreaterThanOrEqualToConstant:88.0],
            [_placeholderLabel.topAnchor constraintEqualToAnchor:_textView.topAnchor constant:8.0],
            [_placeholderLabel.leadingAnchor constraintEqualToAnchor:_textView.leadingAnchor constant:5.0],
            [_placeholderLabel.trailingAnchor constraintEqualToAnchor:_textView.trailingAnchor constant:-5.0]
        ]];
    }
    return self;
}

- (void)configureWithField:(PPAdFormField *)field {
    self.fieldTitleLabel.text = field.title ?: kLang(@"enter_description");
    self.textView.text = [field.value isKindOfClass:NSString.class] ? field.value : @"";
    self.placeholderLabel.text = field.placeholder;
    self.placeholderLabel.hidden = (self.textView.text.length > 0);
    self.textView.editable = !field.disabled;
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
@property (nonatomic, strong) UILabel *formHeroEyebrowLabel;
@property (nonatomic, strong) UILabel *formHeroTitleLabel;
@property (nonatomic, strong) UILabel *formHeroSubtitleLabel;
@property (nonatomic, strong) UILabel *formHeroMetaLabel;
@property (nonatomic, assign) BOOL isSubmittingAd;
@property (nonatomic, assign) BOOL isPrefillInProgress;
@property (nonatomic, copy) NSString *createFlowAdID;
@property (nonatomic, assign) BOOL didMutateMediaAfterPrefill;
@property (nonatomic, assign) BOOL hasUserModifiedForm;
@property (nonatomic, assign) BOOL isHydratingFormData;
@property (nonatomic, assign) BOOL isHydratingMedia;
@property (nonatomic, assign) BOOL formDisabled;
@end


@implementation AddNewAd

- (UIColor *)pp_adCanvasColor
{
    return [UIColor colorWithRed:0.969 green:0.961 blue:0.949 alpha:1.0];
}

- (UIColor *)pp_adSurfaceColor
{
    return [[UIColor whiteColor] colorWithAlphaComponent:0.84];
}

- (UIColor *)pp_adSurfaceBorderColor
{
    return [UIColor colorWithRed:0.25 green:0.17 blue:0.18 alpha:0.08];
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
    self.isHydratingFormData = YES;
    self.isHydratingMedia = NO;
    self.hasUserModifiedForm = NO;

    [self initBase];
    [self initForm];
    [self setBackAndCorners];
    [self pp_applyAdCanvasBackground];
    [self setupImageCollection];
    [self setupPrefillLoadingUI];
    [self setupUploadProgressUI];
    [self setupModernBackdrop];
    [self setupFormHeroHeader];
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
    dispatch_async(dispatch_get_main_queue(), ^{
        self.photoBrowserBridge.useArabic = Language.isRTL;
        self.imageCollection.useArabic = Language.isRTL;
        NSString *title = [self pp_localizedStringForKey:@"add.images.here"
                                                 fallback:@"Add images here"];
        [self.imageCollection setTitle:title icon:nil];
    });
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
    [self pp_refreshMediaLocalizedText];
    self.uploadProgressTitleLabel.text = [self pp_localizedStringForKey:@"uploading_images" fallback:@"Uploading images..."];
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
        [overlay.centerXAnchor constraintEqualToAnchor:self.imageCollection.centerXAnchor],
        [overlay.centerYAnchor constraintEqualToAnchor:self.imageCollection.centerYAnchor],
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
    topGlow.layer.shadowColor = [UIColor colorWithRed:0.97 green:0.80 blue:0.64 alpha:1.0].CGColor;
    topGlow.layer.shadowOpacity = 0.10;
    topGlow.layer.shadowRadius = 62.0;
    topGlow.layer.shadowOffset = CGSizeZero;

    UIView *bottomGlow = [[UIView alloc] init];
    bottomGlow.translatesAutoresizingMaskIntoConstraints = NO;
    bottomGlow.userInteractionEnabled = NO;
    bottomGlow.backgroundColor = [[UIColor colorWithRed:0.72 green:0.45 blue:0.42 alpha:1.0] colorWithAlphaComponent:0.06];
    bottomGlow.layer.shadowColor = [UIColor colorWithRed:0.73 green:0.31 blue:0.32 alpha:1.0].CGColor;
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
    UIColor *accentColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    UIColor *primaryTextColor = AppPrimaryTextClr ?: UIColor.labelColor;

    UIView *heroView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.bounds), 176.0)];
    heroView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    heroView.userInteractionEnabled = NO;
    heroView.backgroundColor = [self pp_adSurfaceColor];
    heroView.layer.cornerRadius = 26.0;
    heroView.layer.masksToBounds = NO;
    heroView.layer.borderWidth = 1.0;
    heroView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.56].CGColor;
    heroView.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:1.0].CGColor;
    heroView.layer.shadowOpacity = 0.08;
    heroView.layer.shadowRadius = 22.0;
    heroView.layer.shadowOffset = CGSizeMake(0.0, 10.0);

    UIView *tintView = [[UIView alloc] initWithFrame:heroView.bounds];
    tintView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tintView.backgroundColor = [[UIColor colorWithRed:0.98 green:0.94 blue:0.90 alpha:1.0] colorWithAlphaComponent:0.52];
    tintView.layer.cornerRadius = 26.0;
    tintView.layer.masksToBounds = YES;
    [heroView addSubview:tintView];

    UIView *accentBand = [[UIView alloc] init];
    accentBand.translatesAutoresizingMaskIntoConstraints = NO;
    accentBand.backgroundColor = accentColor;
    accentBand.layer.cornerRadius = 2.0;
    accentBand.layer.masksToBounds = YES;
    [heroView addSubview:accentBand];

    UILabel *eyebrowLabel = [[UILabel alloc] init];
    eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    eyebrowLabel.textColor = [accentColor colorWithAlphaComponent:0.92];
    eyebrowLabel.textAlignment = NSTextAlignmentNatural;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:28.0] ?: [UIFont systemFontOfSize:28.0 weight:UIFontWeightBold];
    titleLabel.textColor = primaryTextColor;
    titleLabel.numberOfLines = 2;
    titleLabel.textAlignment = NSTextAlignmentNatural;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.88];
    subtitleLabel.numberOfLines = 3;
    subtitleLabel.textAlignment = NSTextAlignmentNatural;

    UILabel *metaLabel = [[UILabel alloc] init];
    metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    metaLabel.font = [GM MidFontWithSize:11.5] ?: [UIFont systemFontOfSize:11.5 weight:UIFontWeightSemibold];
    metaLabel.textColor = [primaryTextColor colorWithAlphaComponent:0.70];
    metaLabel.textAlignment = NSTextAlignmentNatural;
    metaLabel.numberOfLines = 1;
    metaLabel.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.62];
    metaLabel.layer.cornerRadius = 14.0;
    metaLabel.layer.masksToBounds = YES;

    UIView *metaContainer = [[UIView alloc] init];
    metaContainer.translatesAutoresizingMaskIntoConstraints = NO;
    metaContainer.backgroundColor = UIColor.clearColor;
    [metaContainer addSubview:metaLabel];

    [heroView addSubview:eyebrowLabel];
    [heroView addSubview:titleLabel];
    [heroView addSubview:subtitleLabel];
    [heroView addSubview:metaContainer];

    [NSLayoutConstraint activateConstraints:@[
        [accentBand.topAnchor constraintEqualToAnchor:heroView.topAnchor constant:18.0],
        [accentBand.leadingAnchor constraintEqualToAnchor:heroView.leadingAnchor constant:20.0],
        [accentBand.widthAnchor constraintEqualToConstant:34.0],
        [accentBand.heightAnchor constraintEqualToConstant:4.0],

        [eyebrowLabel.topAnchor constraintEqualToAnchor:accentBand.bottomAnchor constant:16.0],
        [eyebrowLabel.leadingAnchor constraintEqualToAnchor:heroView.leadingAnchor constant:20.0],
        [eyebrowLabel.trailingAnchor constraintEqualToAnchor:heroView.trailingAnchor constant:-20.0],

        [titleLabel.topAnchor constraintEqualToAnchor:eyebrowLabel.bottomAnchor constant:8.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:eyebrowLabel.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:eyebrowLabel.trailingAnchor],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

        [metaContainer.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:14.0],
        [metaContainer.leadingAnchor constraintEqualToAnchor:subtitleLabel.leadingAnchor],
        [metaContainer.trailingAnchor constraintLessThanOrEqualToAnchor:subtitleLabel.trailingAnchor],
        [metaContainer.bottomAnchor constraintEqualToAnchor:heroView.bottomAnchor constant:-18.0],

        [metaLabel.leadingAnchor constraintEqualToAnchor:metaContainer.leadingAnchor],
        [metaLabel.trailingAnchor constraintEqualToAnchor:metaContainer.trailingAnchor],
        [metaLabel.topAnchor constraintEqualToAnchor:metaContainer.topAnchor],
        [metaLabel.bottomAnchor constraintEqualToAnchor:metaContainer.bottomAnchor],
        [metaLabel.heightAnchor constraintEqualToConstant:30.0]
    ]];

    self.formHeroContainerView = heroView;
    self.formHeroEyebrowLabel = eyebrowLabel;
    self.formHeroTitleLabel = titleLabel;
    self.formHeroSubtitleLabel = subtitleLabel;
    self.formHeroMetaLabel = metaLabel;

    self.tableView.tableHeaderView = heroView;
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
        ? kindName
        : [self pp_localizedStringForKey:@"compose_listing_hint" fallback:@"Lead with the right details, then add a strong photo set."];

    NSString *imageText =
        [NSString stringWithFormat:@"%@ %ld/%ld",
         [self pp_localizedStringForKey:@"photos" fallback:@"Photos"],
         (long)[self safeMediaOutputCount],
         (long)self.imageCollection.maxImageCount];
    NSString *stateText = self.isPrefillInProgress
        ? [self pp_localizedStringForKey:@"loading_images" fallback:@"Loading images..."]
        : ((self.mode == AdEditorModeEdit)
           ? [self pp_localizedStringForKey:@"ready_to_update" fallback:@"Ready to update"]
           : [self pp_localizedStringForKey:@"draft_ready" fallback:@"Draft ready"]);

    self.formHeroEyebrowLabel.text = [eyebrow uppercaseString];
    self.formHeroTitleLabel.text = title;
    self.formHeroSubtitleLabel.text = subtitle;
    self.formHeroMetaLabel.text = [NSString stringWithFormat:@"  %@  •  %@  ", imageText, stateText];
}

- (void)pp_setCircularUploadProgressVisible:(BOOL)visible
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (visible) {
            self.uploadProgressTitleLabel.text = [self pp_localizedStringForKey:@"uploading_images" fallback:@"Uploading images..."];
            self.uploadProgressValueLabel.text = @"0%";
            self.uploadCircleProgressView.progress = 0.0;
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
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[PPImages] Updated images count=%ld", (long)images.count);
        if (!self.isHydratingFormData && !self.isHydratingMedia && !self.isPrefillInProgress) {
            self.hasUserModifiedForm = YES;
        }
        if (self.mode == AdEditorModeEdit && !self.isPrefillInProgress && !self.isHydratingMedia) {
            self.didMutateMediaAfterPrefill = YES;
        }
        [self pp_refreshMediaLocalizedText];
        [self pp_reloadMediaUI];
    });
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

        NSString *fileName = [self pp_storageFileNameForAdID:ad.adID index:idx];

        FIRStorageReference *ref =
        [rootRef child:[NSString stringWithFormat:@"pet_ads/%@/%@", ad.adID, fileName]];

        FIRStorageUploadTask *uploadTask =
            [ref putData:data metadata:nil completion:^(FIRStorageMetadata *meta, NSError *error) {

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
        UIImage *image = [UIImage imageWithContentsOfFile:path];
        if (image) {
            [images addObject:image];
        }
    }
    return images.copy;
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

    NSArray<UIImage *> *draftImages = [self imagesFromDraftPaths:payload[PPAddNewAdDraftImagePathsKey]];
    self.isHydratingMedia = YES;
    [self.imageCollection clearAllImages];
    if (draftImages.count > 0) {
        [self.imageCollection addImages:draftImages];
    }
    self.isHydratingMedia = NO;

    self.didMutateMediaAfterPrefill = [storedValues[PPAddNewAdDraftMediaMutatedKey] boolValue];
    self.hasUserModifiedForm = NO;
    self.isHydratingFormData = NO;
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
- (void)setupImageCollection {
    self.imageCollection =
        [[PPImageCollection alloc] initWithFrame:CGRectZero
                                   maxImageCount:8
                                       useArabic:Language.isRTL];
    self.imageCollection.delegate = self;
    self.imageCollection.allowsEditing = YES;
    self.imageCollection.useArabic = Language.isRTL;
    [self pp_refreshMediaLocalizedText];

    [self.view addSubview:self.imageCollection];
    self.imageCollection.translatesAutoresizingMaskIntoConstraints = NO;

     float height = 172;

    [NSLayoutConstraint activateConstraints:@[
        [self.imageCollection.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.imageCollection.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.imageCollection.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-14.0],
        [self.imageCollection.heightAnchor constraintEqualToConstant:height]
    ]];

    self.tableView.scrollEnabled = YES;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.contentInset = UIEdgeInsetsMake(4.0, 0.0, height + 34.0, 0.0);
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(0.0, 0.0, height + 24.0, 0.0);
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
            [self pp_localizedStringForKey:@"basic_info_subtitle" fallback:@"Shape the listing title and taxonomy first."]
        ];
    }

    if (section == 1) {
        return @[
            [self pp_localizedStringForKey:@"pet_details_section" fallback:@"Pet details"],
            [self pp_localizedStringForKey:@"pet_details_subtitle" fallback:@"Describe the pet's gender and age."]
        ];
    }

    return @[
        [self pp_localizedStringForKey:@"listing_details_section" fallback:@"Listing details"],
        [self pp_localizedStringForKey:@"listing_details_subtitle" fallback:@"Set the price, location, and write a description."]
    ];
}

- (UIView *)pp_sectionHeaderViewForTitle:(NSString *)title subtitle:(NSString *)subtitle
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
    titleLabel.text = title;
    [container addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.9];
    subtitleLabel.text = subtitle;
    [container addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [accentBar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:18.0],
        [accentBar.topAnchor constraintEqualToAnchor:container.topAnchor constant:14.0],
        [accentBar.widthAnchor constraintEqualToConstant:28.0],
        [accentBar.heightAnchor constraintEqualToConstant:4.0],

        [titleLabel.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:9.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:accentBar.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-18.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor]
    ]];

    return container;
}

// Modern form cell styling using layout margins and constraints
- (void)pp_styleModernFormCell:(UITableViewCell *)cell tableView:(UITableView *)tableView indexPath:(NSIndexPath *)indexPath
{
    if (!cell || !indexPath) {
        return;
    }

    cell.backgroundColor = UIColor.clearColor;
    cell.clipsToBounds = NO;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    UIEdgeInsets layoutMargins = UIEdgeInsetsMake(3.0, 16.0, 3.0, 16.0);
    cell.separatorInset = UIEdgeInsetsMake(0.0, CGRectGetWidth(tableView.bounds), 0.0, 0.0);
    cell.layoutMargins = layoutMargins;
    cell.preservesSuperviewLayoutMargins = NO;
    cell.contentView.layoutMargins = layoutMargins;
    cell.contentView.preservesSuperviewLayoutMargins = NO;

    UIView *cardView = [cell.contentView viewWithTag:PPAddNewAdCardBackgroundTag];
    if (!cardView) {
        cardView = [[UIView alloc] initWithFrame:CGRectZero];
        cardView.translatesAutoresizingMaskIntoConstraints = NO;
        cardView.tag = PPAddNewAdCardBackgroundTag;
        cardView.userInteractionEnabled = NO;
        [cell.contentView insertSubview:cardView atIndex:0];

        [NSLayoutConstraint activateConstraints:@[
            [cardView.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:3.0],
            [cardView.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-3.0],
            [cardView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor],
            [cardView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor]
        ]];
    }

    cardView.backgroundColor = [self pp_adSurfaceColor];
    cardView.layer.cornerRadius = 18.0;
    cardView.layer.masksToBounds = YES;
    cardView.layer.borderWidth = 1.0;
    cardView.layer.borderColor = [self pp_adSurfaceBorderColor].CGColor;

    cell.contentView.backgroundColor = UIColor.clearColor;
    cell.contentView.layer.cornerRadius = 0.0;
    cell.contentView.layer.masksToBounds = NO;

    cell.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:1.0].CGColor;
    cell.layer.shadowOpacity = 0.05;
    cell.layer.shadowRadius = 12.0;
    cell.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    cell.layer.masksToBounds = NO;
    cell.layer.shadowPath = nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSArray<NSString *> *content = [self pp_sectionHeaderContentForSection:section];
    return [self pp_sectionHeaderViewForTitle:content.firstObject subtitle:content.lastObject];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return section < (NSInteger)self.formSections.count ? 58.0 : 0.0001;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section
{
    return [self tableView:tableView heightForHeaderInSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 8.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    return [UIView new];
}

// Style cell before display and after creation
- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self pp_styleModernFormCell:cell tableView:tableView indexPath:indexPath];
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
    
    
    // default is Create
    if (self.mode == AdEditorModeCreate) {
        self.mode = AdEditorModeCreate;
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
        [self.tableView reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
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
            [self pp_styleModernFormCell:cell tableView:tableView indexPath:indexPath];
            return cell;
        }
        case PPAdFieldTypeSelector: {
            PPAdSelectorCell *cell = [tableView dequeueReusableCellWithIdentifier:PPAdSelectorCellID forIndexPath:indexPath];
            [cell configureWithField:field];
            cell.userInteractionEnabled = !effectiveDisabled;
            cell.contentView.alpha = effectiveDisabled ? 0.45 : 1.0;
            [self pp_styleModernFormCell:cell tableView:tableView indexPath:indexPath];
            return cell;
        }
        case PPAdFieldTypeSwitch: {
            PPAdSwitchCell *cell = [tableView dequeueReusableCellWithIdentifier:PPAdSwitchCellID forIndexPath:indexPath];
            [cell configureWithField:field];
            cell.toggleSwitch.enabled = !effectiveDisabled;
            cell.onSwitchChanged = ^(BOOL isOn) {
                id oldValue = field.value;
                field.value = @(isOn);
                if (field.onChangeBlock) field.onChangeBlock(oldValue, field.value);
                if (!weakSelf.isHydratingFormData) weakSelf.hasUserModifiedForm = YES;
            };
            [self pp_styleModernFormCell:cell tableView:tableView indexPath:indexPath];
            return cell;
        }
        case PPAdFieldTypeTextView: {
            PPAdTextViewCell *cell = [tableView dequeueReusableCellWithIdentifier:PPAdTextViewCellID forIndexPath:indexPath];
            [cell configureWithField:field];
            cell.textView.editable = !effectiveDisabled;
            cell.onTextChanged = ^(NSString *text) {
                id oldValue = field.value;
                field.value = text;
                if (field.onChangeBlock) field.onChangeBlock(oldValue, text);
                if (!weakSelf.isHydratingFormData) weakSelf.hasUserModifiedForm = YES;
            };
            [self pp_styleModernFormCell:cell tableView:tableView indexPath:indexPath];
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
    CGFloat rowHeight = 48;

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

    self.tableView.estimatedSectionFooterHeight = 10;
    self.tableView.sectionFooterHeight = 10;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 64.0;
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
    NSString *prefillLocation = self.adModel.locationName;
    if (prefillLocation.length == 0 && self.adModel.adLocation > 0) {
        prefillLocation = [CitiesManager.shared cityNameForID:self.adModel.adLocation];
    }
    [self fieldForTag:kadLocation].value = prefillLocation;
    self.selectedAdLocationName = prefillLocation;
    self.selectedAdCoordinate = CLLocationCoordinate2DMake(self.adModel.latitude, self.adModel.longitude);
    self.hasSelectedAdCoordinate = PPIsValidAdCoordinate(self.selectedAdCoordinate);
    
    [self pp_reloadFieldWithTag:kpetAge];
    [self pp_reloadFieldWithTag:kprice];
    [self pp_reloadFieldWithTag:kdesc];
    [self pp_reloadFieldWithTag:kadLocation];
    
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


-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self pp_applyAdCanvasBackground];
    if (self.backgroundGlowViewTop) {
        self.backgroundGlowViewTop.layer.cornerRadius = CGRectGetWidth(self.backgroundGlowViewTop.bounds) * 0.5;
        self.backgroundGlowViewBottom.layer.cornerRadius = CGRectGetWidth(self.backgroundGlowViewBottom.bounds) * 0.5;
        [self.view sendSubviewToBack:self.backgroundGlowViewBottom];
        [self.view sendSubviewToBack:self.backgroundGlowViewTop];
    }
    self.tableView.alpha = 1;

    if (self.formHeroContainerView) {
        CGFloat width = CGRectGetWidth(self.view.bounds) - 32.0;
        CGFloat fittingHeight =
            [self.formHeroContainerView systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)].height;
        if (fittingHeight < 160.0) {
            fittingHeight = 184.0;
        }
        CGRect headerFrame = self.formHeroContainerView.frame;
        headerFrame.origin.x = 0.0;
        headerFrame.origin.y = 0.0;
        headerFrame.size.width = width;
        headerFrame.size.height = fittingHeight;
        if (!CGRectEqualToRect(self.formHeroContainerView.frame, headerFrame)) {
            self.formHeroContainerView.frame = headerFrame;
            self.tableView.tableHeaderView = self.formHeroContainerView;
        }
        self.formHeroContainerView.layer.cornerRadius = 26.0;
        self.formHeroContainerView.layer.borderWidth = 1.0;
        self.formHeroContainerView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.56].CGColor;
    }

    self.imageCollection.layer.cornerRadius = 26.0;
    self.imageCollection.layer.borderWidth = 1.0;
    self.imageCollection.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.48].CGColor;
    self.imageCollection.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:1.0].CGColor;
    self.imageCollection.layer.shadowOpacity = 0.06;
    self.imageCollection.layer.shadowRadius = 14.0;
    self.imageCollection.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    self.imageCollection.layer.masksToBounds = NO;
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
    
    // 2️⃣ Prepare the ad model
    if (!isEditing) {
        if (self.createFlowAdID.length == 0) {
            self.createFlowAdID = NSUUID.UUID.UUIDString;
        }
        self.adModel.adID = self.createFlowAdID;
        if (!self.adModel.postedDate) {
            self.adModel.postedDate = NSDate.date;
        }
        self.adModel.ownerID = [UserManager sharedManager].currentUser.ID;

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

    [self pp_showUploadIndicatorOnNavBar];
    [self pp_setCircularUploadProgressVisible:YES];
    [self pp_updateCircularUploadProgress:0.0];
    [self pp_setSubmitEnabled:NO];
    [self pp_setMediaLoadingVisible:YES textKey:@"uploading_images" fallback:@"Uploading images..."];

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

    // 🔒 IMPORTANT: Start with EMPTY imageItems
    self.adModel.imageItems = @[];

    [self uploadUIImages:images
                   forAd:self.adModel
               completion:^(PetAd *updatedAd, NSError *error)
    {
        if (error) {
            [self pp_handleSubmitFailure:error];
            return;
        }

        // 🔒 SINGLE SOURCE OF TRUTH
        [self prepareSearchMetadataForAd:updatedAd];
        [[PetAdManager sharedManager] addPetAd:updatedAd
                                    completion:^(NSError *error)
        {
            if (error) {
                [self pp_handleSubmitFailure:error];
                return;
            }
            self.adModel = updatedAd;
            [self pp_finishCreateSuccess];
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
    NSString *subtitle = error.localizedDescription.length ? error.localizedDescription : fallbackSubtitle;
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

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
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

-(void)dismiss
{
    [self popoverPresentationController];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    //[PPBarMgr hide];
    [self pp_refreshMediaLocalizedText];
    
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
    container.backgroundColor = [self pp_adSurfaceColor];
    container.userInteractionEnabled = NO;
    container.semanticContentAttribute =
    Language.isRTL ? UISemanticContentAttributeForceRightToLeft
                   : UISemanticContentAttributeForceLeftToRight;

    CGFloat cornerRadius = height / 2.0;
    container.layer.cornerRadius = cornerRadius;
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.52].CGColor;
    container.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:1.0].CGColor;
    container.layer.shadowOffset = CGSizeMake(0, 6);
    container.layer.shadowOpacity = 0.06;
    container.layer.shadowRadius = 14.0;

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
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:container.leadingAnchor constant:16.0],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor constant:-16.0],
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
    //NSString *buttonTitle = (self.mode == AdEditorModeEdit) ? kLang(@"saveChanges") : kLang(@"postAd");
    //UIButton *saveBTN = [PPButtonHelper pp_buttonWithTitleForBar:nil imageName:@"checkmark" target:self action:@selector(saveFormData:)];
    UIBarButtonItem *saveBarButton = [[UIBarButtonItem alloc] initWithImage:PPSYSImage(@"checkmark") style:UIBarButtonItemStylePlain target:self action:@selector(saveFormData:)];
    self.navigationItem.rightBarButtonItem = saveBarButton;
    
    //UIButton *backBTN = [PPButtonHelper pp_buttonWithTitleForBar:nil imageName:PPChevronName target:self action:@selector(onBack:)];
    UIBarButtonItem *backBarButton = [[UIBarButtonItem alloc] initWithImage:PPSYSImage(PPChevronName) style:UIBarButtonItemStylePlain target:self action:@selector(onBack:)];
    self.navigationItem.leftBarButtonItem = backBarButton;
    [self pp_setSubmitEnabled:!self.isSubmittingAd && !self.isPrefillInProgress];
}

// generateRawWithType and formRowDescriptorValueHasChanged removed — no longer needed













 
#pragma mark - UI Reload

- (void)pp_reloadMediaUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self pp_refreshFormHeroContent];
        [self.imageCollection reloadCollectionView];
    });
}


@end
