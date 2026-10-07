#import "AddNewAd.h"
#import "PPImageCollection.h"
#import "PPMenuHelper.h"
#import "PPFormEngine.h"
#import "LocationPickerViewController.h"
#import "ZYCircleProgressView.h"
#import "PPSelectOptionViewController.h"
#import <Pure_Pets-Swift.h>
#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import <float.h>
#import "Lottie.h"
#import <lottie_ios_Oc/Lottie.h>
@import FirebaseAuth;
@import FirebaseFirestore;
@import FirebaseStorage;

static NSString * const PPAddNewAdUploadErrorDomain = @"PPAddNewAdUploadErrorDomain";
static NSString * const PPAddNewAdLanguageDidChangeNotification = @"LanguageDidChangeNotification";
static NSString * const PPAddNewAdDraftDefaultsPrefix = @"pp.add_pet_ad.draft";
static NSString * const PPAddNewAdDraftFormDataKey = @"formData";
static NSString * const PPAddNewAdDraftImagePathsKey = @"imagePaths";
static NSString * const PPAddNewAdDraftMediaMutatedKey = @"didMutateMedia";
static NSString * const PPAdGenderDraftKey = @"gender";
static NSString * const PPAdGenderValueMale = @"male";
static NSString * const PPAdGenderValueFemale = @"female";
static NSString * const PPAdGenderValueUndefined = @"undefined";
static CGFloat const PPAddNewAdDraftImageMaxPixelSize = 1800.0;

static NSString * const PPAdTextFieldCellID  = @"PPAdTextFieldCell";
static NSString * const PPAdSelectorCellID   = @"PPAdSelectorCell";
static NSString * const PPAdSwitchCellID     = @"PPAdSwitchCell";
static NSString * const PPAdTextViewCellID   = @"PPAdTextViewCell";
static NSString * const PPAdPairFieldCellID  = @"PPAdPairFieldCell";

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
@property (nonatomic, strong) PPAdFormField *pairedField;
@end

@implementation PPAdFormField
- (instancetype)init {
    self = [super init];
    if (self) { _height = 52.0; _required = NO; _disabled = NO; }
    return self;
}
@end

#pragma mark - PPAdGenderOption

@interface PPAdGenderOption : NSObject
@property (nonatomic, copy, readonly) NSString *storageValue;
@property (nonatomic, copy, readonly) NSString *localizedTitle;
@property (nonatomic, copy, readonly) NSString *systemImageName;
+ (instancetype)optionWithStorageValue:(NSString *)storageValue
                        localizedTitle:(NSString *)localizedTitle
                        systemImageName:(NSString *)systemImageName;
- (NSString *)formDisplayText;
@end

@implementation PPAdGenderOption

+ (instancetype)optionWithStorageValue:(NSString *)storageValue
                        localizedTitle:(NSString *)localizedTitle
                        systemImageName:(NSString *)systemImageName
{
    PPAdGenderOption *option = [PPAdGenderOption new];
    option->_storageValue = [storageValue ?: @"" copy];
    option->_localizedTitle = [localizedTitle ?: @"" copy];
    option->_systemImageName = [systemImageName ?: @"" copy];
    return option;
}

- (NSString *)formDisplayText
{
    return self.localizedTitle ?: @"";
}

- (NSString *)description
{
    return self.formDisplayText;
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:PPAdGenderOption.class]) return NO;
    PPAdGenderOption *other = (PPAdGenderOption *)object;
    return [self.storageValue isEqualToString:other.storageValue];
}

- (NSUInteger)hash
{
    return self.storageValue.hash;
}

@end

#pragma mark - Studio Redesign Components

@interface PPDashedAddMediaButton : UIButton
@property (nonatomic, strong) CAShapeLayer *dashLayer;
@end

@implementation PPDashedAddMediaButton
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _dashLayer = [CAShapeLayer layer];
        _dashLayer.strokeColor = [UIColor colorWithRed:0.39 green:0.40 blue:0.95 alpha:0.45].CGColor;
        _dashLayer.fillColor = nil;
        _dashLayer.lineDashPattern = @[@4, @4];
        _dashLayer.lineWidth = 1.5;
        [self.layer addSublayer:_dashLayer];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    _dashLayer.frame = self.bounds;
    _dashLayer.path = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:16.0].CGPath;
}
@end

@interface PPRadarProgressRingView : UIView
@property (nonatomic, strong) CAShapeLayer *trackLayer;
@property (nonatomic, strong) CAShapeLayer *progressLayer;
@property (nonatomic, strong) UILabel *percentLabel;
@property (nonatomic, assign) NSInteger currentPercentage;
- (void)setProgress:(CGFloat)progress animated:(BOOL)animated;
@end

@implementation PPRadarProgressRingView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _trackLayer = [CAShapeLayer layer];
        _trackLayer.fillColor = nil;
        _trackLayer.lineWidth = 4.5;
        _trackLayer.strokeColor = [UIColor colorWithRed:0.98 green:0.55 blue:0.25 alpha:0.18].CGColor;
        [self.layer addSublayer:_trackLayer];

        _progressLayer = [CAShapeLayer layer];
        _progressLayer.fillColor = nil;
        _progressLayer.lineWidth = 4.5;
        _progressLayer.lineCap = kCALineCapRound;
        _progressLayer.strokeColor = [UIColor colorWithRed:0.98 green:0.55 blue:0.25 alpha:1.0].CGColor;
        _progressLayer.strokeEnd = 0.0;
        [self.layer addSublayer:_progressLayer];

        _percentLabel = [[UILabel alloc] init];
        _percentLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _percentLabel.font = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold];
        _percentLabel.textColor = PPAdFormPrimaryTextColor();
        _percentLabel.textAlignment = NSTextAlignmentCenter;
        _percentLabel.text = @"0%";
        [self addSubview:_percentLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_percentLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_percentLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
        ]];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat side = MIN(self.bounds.size.width, self.bounds.size.height);
    if (side <= 0.0) return;
    CGFloat radius = (side - 4.5) / 2.0;
    CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    UIBezierPath *circlePath = [UIBezierPath bezierPathWithArcCenter:center
                                                              radius:radius
                                                          startAngle:-M_PI_2
                                                            endAngle:3.0 * M_PI_2
                                                           clockwise:YES];
    _trackLayer.path = circlePath.CGPath;
    _progressLayer.path = circlePath.CGPath;
}

- (void)setProgress:(CGFloat)progress animated:(BOOL)animated {
    CGFloat clamped = MAX(0.0, MIN(1.0, progress));
    NSInteger pct = (NSInteger)round(clamped * 100.0);
    _currentPercentage = pct;
    _percentLabel.text = [NSString stringWithFormat:@"%ld%%", (long)pct];

    UIColor *tintColor = (pct >= 100)
        ? [UIColor colorWithRed:0.06 green:0.73 blue:0.51 alpha:1.0]
        : [UIColor colorWithRed:0.98 green:0.48 blue:0.18 alpha:1.0];
    _progressLayer.strokeColor = tintColor.CGColor;

    if (animated) {
        CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        anim.fromValue = @(_progressLayer.strokeEnd);
        anim.toValue = @(clamped);
        anim.duration = 0.4;
        anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [_progressLayer addAnimation:anim forKey:@"progressAnim"];
    }
    _progressLayer.strokeEnd = clamped;
}
@end

#pragma mark - PPAdPairedFieldSlotView

@interface PPAdPairedFieldSlotView : UIControl <UITextFieldDelegate>
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *valueLabel;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, strong) UISwitch *toggleSwitch;
@property (nonatomic, strong) PPAdFormField *field;
@property (nonatomic, assign) BOOL effectiveDisabled;
@property (nonatomic, copy) void(^onSelectField)(PPAdFormField *field);
@property (nonatomic, copy) void(^onTextChanged)(PPAdFormField *field, NSString *text);
@property (nonatomic, copy) void(^onSwitchChanged)(PPAdFormField *field, BOOL isOn);
- (void)configureWithField:(PPAdFormField *)field disabled:(BOOL)disabled;
@end

@implementation PPAdPairedFieldSlotView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = PPAdFormSurfaceColor();
        self.clipsToBounds = NO;
        self.layer.cornerRadius = 20.0;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.layer.borderWidth = 1.0;
        [self pp_setBorderColor:PPAdFormBorderColor()];
        [self pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
        self.layer.shadowOpacity = 0.045;
        self.layer.shadowRadius = 10.0;
        self.layer.shadowOffset = CGSizeMake(0.0, 5.0);
        self.semanticContentAttribute = PPAdCurrentSemanticAttribute();
        [self addTarget:self action:@selector(pp_handleTap) forControlEvents:UIControlEventTouchUpInside];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
        _titleLabel.textColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.82];
        _titleLabel.textAlignment = PPAdCurrentTextAlignment();
        _titleLabel.adjustsFontSizeToFitWidth = YES;
        _titleLabel.minimumScaleFactor = 0.76;
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_titleLabel];

        _valueLabel = [[UILabel alloc] init];
        _valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _valueLabel.font = [GM MidFontWithSize:14.5] ?: [UIFont systemFontOfSize:14.5 weight:UIFontWeightMedium];
        _valueLabel.textColor = PPAdFormPrimaryTextColor();
        _valueLabel.textAlignment = PPAdCurrentTextAlignment();
        _valueLabel.adjustsFontSizeToFitWidth = YES;
        _valueLabel.minimumScaleFactor = 0.72;
        _valueLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_valueLabel];

        _chevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:PPAdForwardSymbolName()]];
        _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
        _chevronView.tintColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.56];
        _chevronView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:_chevronView];

        _textField = [[UITextField alloc] init];
        _textField.translatesAutoresizingMaskIntoConstraints = NO;
        _textField.font = [GM MidFontWithSize:14.5] ?: [UIFont systemFontOfSize:14.5 weight:UIFontWeightMedium];
        _textField.textColor = PPAdFormPrimaryTextColor();
        _textField.textAlignment = PPAdCurrentTextAlignment();
        _textField.semanticContentAttribute = PPAdCurrentSemanticAttribute();
        _textField.backgroundColor = UIColor.clearColor;
        _textField.delegate = self;
        _textField.returnKeyType = UIReturnKeyDone;
        _textField.clearButtonMode = UITextFieldViewModeNever;
        _textField.adjustsFontSizeToFitWidth = YES;
        _textField.minimumFontSize = 10.0;
        [_textField addTarget:self action:@selector(pp_textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        [self addSubview:_textField];

        _toggleSwitch = [[UISwitch alloc] init];
        _toggleSwitch.translatesAutoresizingMaskIntoConstraints = NO;
        _toggleSwitch.onTintColor = PPAdFormAccentColor();
        _toggleSwitch.transform = CGAffineTransformMakeScale(0.84, 0.84);
        [_toggleSwitch addTarget:self action:@selector(pp_switchDidChange:) forControlEvents:UIControlEventValueChanged];
        [self addSubview:_toggleSwitch];

        [_toggleSwitch setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [_toggleSwitch setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [_valueLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        [_textField setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

        [NSLayoutConstraint activateConstraints:@[
            [_titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:9.0],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14.0],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14.0],
            [_titleLabel.heightAnchor constraintGreaterThanOrEqualToConstant:14.0],

            [_chevronView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14.0],
            [_chevronView.centerYAnchor constraintEqualToAnchor:_valueLabel.centerYAnchor],
            [_chevronView.widthAnchor constraintEqualToConstant:10.0],
            [_chevronView.heightAnchor constraintEqualToConstant:10.0],

            [_valueLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_valueLabel.trailingAnchor constraintEqualToAnchor:_chevronView.leadingAnchor constant:-6.0],
            [_valueLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:7.0],
            [_valueLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-8.0],

            [_textField.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_textField.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14.0],
            [_textField.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:5.0],
            [_textField.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-7.0],
            [_textField.heightAnchor constraintGreaterThanOrEqualToConstant:24.0],

            [_toggleSwitch.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4.0],
            [_toggleSwitch.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-10.0],
            [_toggleSwitch.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor constant:10.0],
            [_toggleSwitch.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-4.0]
        ]];
    }
    return self;
}

- (NSString *)pp_displayValueForField:(PPAdFormField *)field
{
    id value = field.value;
    if (!value) {
        return nil;
    }
    if ([value isKindOfClass:NSString.class]) {
        return (NSString *)value;
    }
    if ([value respondsToSelector:@selector(formDisplayText)]) {
        return [value performSelector:@selector(formDisplayText)];
    }
    if ([value respondsToSelector:@selector(KindName)]) {
        return [value performSelector:@selector(KindName)];
    }
    if ([value respondsToSelector:@selector(SubKindName)]) {
        return [value performSelector:@selector(SubKindName)];
    }
    return [NSString stringWithFormat:@"%@", value];
}

- (void)configureWithField:(PPAdFormField *)field disabled:(BOOL)disabled
{
    self.field = field;
    self.effectiveDisabled = disabled;
    self.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    self.titleLabel.textAlignment = PPAdCurrentTextAlignment();
    self.valueLabel.textAlignment = PPAdCurrentTextAlignment();
    self.textField.textAlignment = PPAdCurrentTextAlignment();
    self.textField.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    self.chevronView.image = [UIImage systemImageNamed:PPAdForwardSymbolName()];

    self.titleLabel.text = field.title ?: @"";
    BOOL isSelector = (field.fieldType == PPAdFieldTypeSelector);
    BOOL isText = (field.fieldType == PPAdFieldTypeText || field.fieldType == PPAdFieldTypeInteger);
    BOOL isSwitch = (field.fieldType == PPAdFieldTypeSwitch);

    self.valueLabel.hidden = !isSelector;
    self.chevronView.hidden = !isSelector || disabled;
    self.textField.hidden = !isText;
    self.toggleSwitch.hidden = !isSwitch;

    self.enabled = !disabled;
    self.userInteractionEnabled = !disabled;
    BOOL lockedDisplayValue = disabled && isSelector && field.value != nil;
    self.alpha = lockedDisplayValue ? 1.0 : (disabled ? 0.56 : 1.0);
    self.textField.enabled = !disabled;
    self.toggleSwitch.enabled = !disabled;

    if (isSelector) {
        NSString *displayValue = [self pp_displayValueForField:field];
        if (displayValue.length > 0) {
            self.valueLabel.text = displayValue;
            self.valueLabel.textColor = PPAdFormAccentColor();
        } else {
            self.valueLabel.text = field.placeholder ?: field.selectorTitle;
            self.valueLabel.textColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.68];
        }
    } else if (isText) {
        UIColor *placeholderColor = [UIColor.placeholderTextColor colorWithAlphaComponent:0.70];
        self.textField.attributedPlaceholder = field.placeholder.length
            ? [[NSAttributedString alloc] initWithString:field.placeholder
                                             attributes:@{NSForegroundColorAttributeName: placeholderColor}]
            : nil;
        self.textField.keyboardType = (field.fieldType == PPAdFieldTypeInteger) ? UIKeyboardTypeNumberPad : UIKeyboardTypeDefault;
        self.textField.text = field.value ? [NSString stringWithFormat:@"%@", field.value] : @"";
    } else if (isSwitch) {
        self.toggleSwitch.on = [field.value boolValue];
    }
}

- (void)pp_handleTap
{
    if (self.effectiveDisabled || self.field.fieldType != PPAdFieldTypeSelector) {
        return;
    }
    if (self.onSelectField) {
        self.onSelectField(self.field);
    }
}

- (void)pp_textFieldDidChange:(UITextField *)textField
{
    if (self.onTextChanged) {
        self.onTextChanged(self.field, textField.text);
    }
}

- (void)pp_switchDidChange:(UISwitch *)sender
{
    if (self.onSwitchChanged) {
        self.onSwitchChanged(self.field, sender.isOn);
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

@end

#pragma mark - PPAdPairFieldCell

@interface PPAdPairFieldCell : PPAdBaseCell
@property (nonatomic, strong) UIStackView *fieldStackView;
@property (nonatomic, strong) PPAdPairedFieldSlotView *primarySlotView;
@property (nonatomic, strong) PPAdPairedFieldSlotView *secondarySlotView;
@property (nonatomic, copy) void(^onSelectField)(PPAdFormField *field);
@property (nonatomic, copy) void(^onTextChanged)(PPAdFormField *field, NSString *text);
@property (nonatomic, copy) void(^onSwitchChanged)(PPAdFormField *field, BOOL isOn);
- (void)configureWithPrimaryField:(PPAdFormField *)primaryField
                   secondaryField:(PPAdFormField *)secondaryField
                   primaryDisabled:(BOOL)primaryDisabled
                 secondaryDisabled:(BOOL)secondaryDisabled;
@end

@implementation PPAdPairFieldCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _primarySlotView = [[PPAdPairedFieldSlotView alloc] initWithFrame:CGRectZero];
        _primarySlotView.translatesAutoresizingMaskIntoConstraints = NO;

        _secondarySlotView = [[PPAdPairedFieldSlotView alloc] initWithFrame:CGRectZero];
        _secondarySlotView.translatesAutoresizingMaskIntoConstraints = NO;

        _fieldStackView = [[UIStackView alloc] initWithArrangedSubviews:@[_primarySlotView, _secondarySlotView]];
        _fieldStackView.translatesAutoresizingMaskIntoConstraints = NO;
        _fieldStackView.axis = UILayoutConstraintAxisHorizontal;
        _fieldStackView.alignment = UIStackViewAlignmentFill;
        _fieldStackView.distribution = UIStackViewDistributionFillEqually;
        _fieldStackView.spacing = 14.0;
        _fieldStackView.semanticContentAttribute = PPAdCurrentSemanticAttribute();
        [self.contentView addSubview:_fieldStackView];

        __weak typeof(self) weakSelf = self;
        void (^selectBlock)(PPAdFormField *) = ^(PPAdFormField *field) {
            if (weakSelf.onSelectField) weakSelf.onSelectField(field);
        };
        void (^textBlock)(PPAdFormField *, NSString *) = ^(PPAdFormField *field, NSString *text) {
            if (weakSelf.onTextChanged) weakSelf.onTextChanged(field, text);
        };
        void (^switchBlock)(PPAdFormField *, BOOL) = ^(PPAdFormField *field, BOOL isOn) {
            if (weakSelf.onSwitchChanged) weakSelf.onSwitchChanged(field, isOn);
        };

        _primarySlotView.onSelectField = selectBlock;
        _primarySlotView.onTextChanged = textBlock;
        _primarySlotView.onSwitchChanged = switchBlock;
        _secondarySlotView.onSelectField = selectBlock;
        _secondarySlotView.onTextChanged = textBlock;
        _secondarySlotView.onSwitchChanged = switchBlock;

        [NSLayoutConstraint activateConstraints:@[
            [_fieldStackView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8.0],
            [_fieldStackView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_fieldStackView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_fieldStackView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8.0]
        ]];
    }
    return self;
}

- (void)configureWithPrimaryField:(PPAdFormField *)primaryField
                   secondaryField:(PPAdFormField *)secondaryField
                  primaryDisabled:(BOOL)primaryDisabled
                secondaryDisabled:(BOOL)secondaryDisabled
{
    self.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    self.contentView.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    self.fieldStackView.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    [self.primarySlotView configureWithField:primaryField disabled:primaryDisabled];
    [self.secondarySlotView configureWithField:secondaryField disabled:secondaryDisabled];
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

@interface AddNewAd ()<UISheetPresentationControllerDelegate,UIAdaptivePresentationControllerDelegate,UITextFieldDelegate,PPImageCollectionDelegate>
// form + data
@property (nonatomic, strong) PPFormEngineView *basicFormView;
@property (nonatomic, strong) PPFormEngineView *petFormView;
@property (nonatomic, strong) PPFormEngineView *listingFormView;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) NSLayoutConstraint *heroHeightConstraint;
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
@property (nonatomic, assign) BOOL selectorSheetFocusActive;

// Studio Redesign Properties
@property (nonatomic, strong) UIView *studioApexHeaderView;
@property (nonatomic, strong) UIView *studioRadarCardView;
@property (nonatomic, strong) PPRadarProgressRingView *studioRadarRingView;
@property (nonatomic, strong) UILabel *studioRadarAdviceLabel;
@property (nonatomic, strong) UIView *studioRadarCompleteBadge;
@property (nonatomic, strong) UIView *studioMediaCardView;
@property (nonatomic, strong) UILabel *studioMediaCountBadgeLabel;
@property (nonatomic, strong) UIScrollView *studioMediaScrollView;
@property (nonatomic, strong) UIStackView *studioMediaThumbnailsStack;
@property (nonatomic, strong) UIView *studioCategoryCardView;
@property (nonatomic, strong) UIStackView *studioSpeciesChipsStack;
@property (nonatomic, strong) UIView *studioAppearanceCardView;
@property (nonatomic, strong) UIButton *studioGenderMaleButton;
@property (nonatomic, strong) UIButton *studioGenderFemaleButton;
@property (nonatomic, strong) UIButton *studioGenderUndefinedButton;
@property (nonatomic, strong) UIView *studioListingCardView;
@property (nonatomic, strong) UIView *studioFloatingDockView;
@property (nonatomic, strong) UIView *studioDockGuidancePill;
@property (nonatomic, strong) UILabel *studioDockGuidanceLabel;
@property (nonatomic, strong) UIButton *studioDockHeroButton;
@property (nonatomic, strong) CAGradientLayer *studioDockHeroGradient;
@property (nonatomic, strong) UIActivityIndicatorView *studioDockSpinner;

- (void)initBase;
- (NSArray<PPAdGenderOption *> *)pp_genderSelectorOptions;
- (nullable PPAdGenderOption *)pp_genderOptionFromValue:(id _Nullable)value;
- (nullable PPAdGenderOption *)pp_genderOptionForAdModel;
- (void)pp_applyGenderSelectionToAdModel:(id _Nullable)value;
- (void)pp_animateInvalidFormRow:(PPFormFieldRowView *)row;
@end


@implementation AddNewAd

- (void)initBase {
    if (!self.editingAd && self.initialAd) {
        self.editingAd = self.initialAd;
    }

    if (self.editingAd) {
        self.mode = AdEditorModeEdit;
    }

    if (!self.adModel) {
        if (self.mode == AdEditorModeEdit && self.editingAd) {
            self.adModel = [[PetAd alloc] initWithDictionary:[self.editingAd toFirestoreDictionary]
                                                  documentID:self.editingAd.adID];
            self.adModel.adID = self.editingAd.adID;
            self.adModel.ownerID = self.editingAd.ownerID;
            self.adModel.postedDate = self.editingAd.postedDate;
            if (self.adModel.status == 0) {
                self.adModel.status = self.editingAd.status;
            }
            if (self.adModel.visibility == 0) {
                self.adModel.visibility = self.editingAd.visibility;
            }
        } else {
            self.adModel = [[PetAd alloc] init];
            self.adModel.gender = PPAdGenderValueUndefined;
        }
    }

    if (self.selectedMainKind) {
        self.selectedKind = self.selectedMainKind;
        self.adModel.category = self.selectedMainKind.ID;
    } else if (!self.selectedKind && self.adModel.category > 0) {
        self.selectedKind = [MKM mainKindForID:self.adModel.category];
    }

    if (!self.uploadManager) {
        self.uploadManager = [[FileUploadManager alloc] init];
    }
    [self setBackAndCorners];
}

- (UIColor *)pp_adCanvasColor
{
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0.09 green:0.09 blue:0.11 alpha:1.0]
            : [UIColor colorWithRed:0.98 green:0.97 blue:0.95 alpha:1.0];
    }];
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

    self.scrollView.backgroundColor = UIColor.clearColor;
    self.scrollView.opaque = NO;
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
      self = [super init];
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
    [self setupImageCollection];
    [self initForm];
    [self setBackAndCorners];
    [self pp_applyAdCanvasBackground];
    [self setupPrefillLoadingUI];
    [self setupUploadProgressUI];
    [self setupModernBackdrop];
    // [self setupFormHeroHeader];
    // [self pp_updateFormHeroHeaderLayoutIfNeeded];
    self.photoBrowserBridge = [PPPhotoBrowserBridge new];
    self.photoBrowserBridge.useArabic = Language.isRTL;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleLanguageDidChange:)
                                               name:PPAddNewAdLanguageDidChangeNotification
                                               object:nil];
    [self pp_refreshMediaLocalizedText];
    if (![self restoreDraftIfNeeded]) {
        [self configureForEditingIfNeeded];
    }
    self.isHydratingFormData = NO;
    [self pp_syncSpeciesChipsState];
    [self pp_syncGenderButtonsState];
    [self pp_refreshStudioMediaThumbnails];
    [self pp_updateStudioReadinessRadarAnimated:NO];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];
}

- (void)pp_dismissKeyboard {
    [self.view endEditing:YES];
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
        if (self.studioDockHeroButton) {
            self.studioDockHeroButton.enabled = enabled;
            self.studioDockHeroButton.alpha = enabled ? 1.0 : 0.45;
            if (!enabled && self.isSubmittingAd) {
                [self.studioDockSpinner startAnimating];
            } else {
                [self.studioDockSpinner stopAnimating];
            }
        }
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
    self.scrollView.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    self.contentStack.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    self.imageCollectionFooterContainerView.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    [self pp_refreshMediaLocalizedText];
    self.uploadProgressTitleLabel.text = [self pp_localizedStringForKey:@"uploading_images" fallback:@"Uploading images..."];
    [self pp_refreshFormHeroContent];
    [self pp_rebuildFormFields];
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
    UIView *loadingHostView = self.imageCollectionFooterContainerView ?: self.view;
    [loadingHostView addSubview:self.prefillLoadingView];

    [NSLayoutConstraint activateConstraints:@[
        [self.prefillLoadingView.centerXAnchor constraintEqualToAnchor:loadingHostView.centerXAnchor],
        [self.prefillLoadingView.centerYAnchor constraintEqualToAnchor:loadingHostView.centerYAnchor],
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
    if (self.backgroundGlowViewTop) {
        return;
    }

    UIView *topGlow = [[UIView alloc] init];
    topGlow.translatesAutoresizingMaskIntoConstraints = NO;
    topGlow.userInteractionEnabled = NO;

    CAGradientLayer *glowGrad = [CAGradientLayer layer];
    glowGrad.colors = @[
        (id)[[UIColor colorWithRed:0.98 green:0.55 blue:0.25 alpha:1.0] colorWithAlphaComponent:0.12].CGColor,
        (id)[[UIColor colorWithRed:0.98 green:0.55 blue:0.25 alpha:1.0] colorWithAlphaComponent:0.0].CGColor
    ];
    glowGrad.startPoint = CGPointMake(0.5, 0.0);
    glowGrad.endPoint = CGPointMake(0.5, 1.0);
    [topGlow.layer addSublayer:glowGrad];

    [self.view insertSubview:topGlow belowSubview:self.scrollView];

    [NSLayoutConstraint activateConstraints:@[
        [topGlow.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [topGlow.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [topGlow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [topGlow.heightAnchor constraintEqualToConstant:240.0]
    ]];

    self.backgroundGlowViewTop = topGlow;
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
    [cardView pp_setBorderColor:[UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return (tc.userInterfaceStyle == UIUserInterfaceStyleDark)
            ? [UIColor.whiteColor colorWithAlphaComponent:0.08]
            : [UIColor.whiteColor colorWithAlphaComponent:0.68];
    }]];
    [cardView pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    cardView.layer.shadowOpacity = 0.08;
    cardView.layer.shadowRadius = 24.0;
    cardView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    [heroRoot addSubview:cardView];

    UIView *tintView = [[UIView alloc] init];
    tintView.translatesAutoresizingMaskIntoConstraints = NO;
    tintView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return (tc.userInterfaceStyle == UIUserInterfaceStyleDark)
            ? [UIColor colorWithWhite:0.06 alpha:0.55]
            : [[UIColor colorWithRed:0.99 green:0.96 blue:0.93 alpha:1.0] colorWithAlphaComponent:0.72];
    }];
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
    secondaryGlow.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return (tc.userInterfaceStyle == UIUserInterfaceStyleDark)
            ? [accentColor colorWithAlphaComponent:0.08]
            : [UIColor.whiteColor colorWithAlphaComponent:0.38];
    }];
    secondaryGlow.userInteractionEnabled = NO;
    secondaryGlow.layer.cornerRadius = 58.0;
    [secondaryGlow pp_setShadowColor:[UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return (tc.userInterfaceStyle == UIUserInterfaceStyleDark)
            ? [accentColor colorWithAlphaComponent:0.12]
            : [UIColor.whiteColor colorWithAlphaComponent:0.44];
    }]];
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
    iconBadge.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return (tc.userInterfaceStyle == UIUserInterfaceStyleDark)
            ? [AppForgroundColr colorWithAlphaComponent:0.14]
            : [UIColor.whiteColor colorWithAlphaComponent:0.66];
    }];
    iconBadge.layer.cornerRadius = 31.0;
    iconBadge.layer.cornerCurve = kCACornerCurveContinuous;
    iconBadge.layer.borderWidth = 1.0;
    [iconBadge pp_setBorderColor:[accentColor colorWithAlphaComponent:0.18]];
    [iconBadge pp_setShadowColor:[UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return (tc.userInterfaceStyle == UIUserInterfaceStyleDark)
            ? [accentColor colorWithAlphaComponent:0.10]
            : [accentColor colorWithAlphaComponent:0.30];
    }]];
    iconBadge.layer.shadowOpacity = 0.16;
    iconBadge.layer.shadowRadius = 18.0;
    iconBadge.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    [cardView addSubview:iconBadge];

    UIImageView *iconFallback = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"square.and.pencil"]];
    iconFallback.translatesAutoresizingMaskIntoConstraints = NO;
    iconFallback.tintColor = accentColor;
    iconFallback.contentMode = UIViewContentModeScaleAspectFit;
    [iconBadge addSubview:iconFallback];

    LOTAnimationView *iconLottie = [[LOTAnimationView alloc] init];
    iconLottie.translatesAutoresizingMaskIntoConstraints = NO;
    iconLottie.contentMode = UIViewContentModeScaleAspectFit;
    iconLottie.loopAnimation = YES;
    iconLottie.alpha = 0.0;
    [iconBadge addSubview:iconLottie];
    [Styling setAnimationNamed:@"Speaker.lottie" toView:iconLottie withSpeed:0.8 loopAnimation:YES autoplay:YES completion:^(BOOL success) {
        if (success) {
            iconFallback.alpha = 0.0;
            [UIView animateWithDuration:0.3 animations:^{
                iconLottie.alpha = 1.0;
            }];
        }
    }];

    UIView *eyebrowPill = [[UIView alloc] init];
    eyebrowPill.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowPill.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return (tc.userInterfaceStyle == UIUserInterfaceStyleDark)
            ? [AppForgroundColr colorWithAlphaComponent:0.08]
            : [UIColor.whiteColor colorWithAlphaComponent:0.74];
    }];
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
    metaLabel.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return (tc.userInterfaceStyle == UIUserInterfaceStyleDark)
            ? [AppForgroundColr colorWithAlphaComponent:0.10]
            : [UIColor.whiteColor colorWithAlphaComponent:0.78];
    }];
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

        [iconFallback.centerXAnchor constraintEqualToAnchor:iconBadge.centerXAnchor],
        [iconFallback.centerYAnchor constraintEqualToAnchor:iconBadge.centerYAnchor],
        [iconFallback.widthAnchor constraintEqualToConstant:28.0],
        [iconFallback.heightAnchor constraintEqualToConstant:28.0],

        [iconLottie.centerXAnchor constraintEqualToAnchor:iconBadge.centerXAnchor],
        [iconLottie.centerYAnchor constraintEqualToAnchor:iconBadge.centerYAnchor],
        [iconLottie.widthAnchor constraintEqualToConstant:88.0],
        [iconLottie.heightAnchor constraintEqualToConstant:88.0],

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
    // Hero is now managed by contentStack in pp_rebuildFormFields
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

    NSArray<NSDictionary *> *mediaMetadata = [self.adModel.imageItemsRaw isKindOfClass:NSArray.class] ? self.adModel.imageItemsRaw : @[];
    if (mediaMetadata.count == 0 && self.adModel.imageItems.count > 0) {
        NSMutableArray<NSDictionary *> *legacyItems = [NSMutableArray arrayWithCapacity:self.adModel.imageItems.count];
        for (PetImageItem *item in self.adModel.imageItems) {
            NSDictionary *dict = [item toDictionary];
            if (dict) {
                [legacyItems addObject:dict];
            }
        }
        mediaMetadata = legacyItems.copy;
    }

    if (mediaMetadata.count == 0) {
        [self pp_finishPrefillFlow];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageCollection.userInteractionEnabled = NO;
    });

    [self.imageCollection preloadMediaMetadata:mediaMetadata completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"Prefilled %ld media item(s) for editing", (long)mediaMetadata.count);
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
        metadata.customMetadata = @{
            @"uploaded_by": [self pp_submitOwnerID] ?: @"",
            @"entity_type": @"ads",
            @"entity_id": ad.adID ?: @""
        };

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
        [self.navigationController setNavigationBarHidden:NO animated:animated];
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

    PPAdGenderOption *genderOption = [self pp_genderOptionFromValue:[self fieldForTag:@"isFemale"].value];
    if (genderOption.storageValue.length > 0) {
        snapshot[PPAdGenderDraftKey] = genderOption.storageValue;
        if ([genderOption.storageValue isEqualToString:PPAdGenderValueFemale] ||
            [genderOption.storageValue isEqualToString:PPAdGenderValueMale]) {
            snapshot[@"isFemale"] = @([genderOption.storageValue isEqualToString:PPAdGenderValueFemale]);
        }
    }

    if ([[self fieldForTag:kpetAge].value respondsToSelector:@selector(integerValue)]) {
        NSInteger age = [[self fieldForTag:kpetAge].value integerValue];
        if (age > 0) {
            snapshot[@"petAgeMonths"] = @(age);
        }
    }

    NSNumber *snapshotPrice = [GM moneyNumberFromInput:[self fieldForTag:kprice].value];
    if (snapshotPrice.doubleValue > 0.0) {
        snapshot[@"price"] = snapshotPrice;
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

- (nullable PPAdGenderOption *)pp_genderOptionForStorageValue:(NSString *)storageValue
{
    NSArray<PPAdGenderOption *> *options = [self pp_genderSelectorOptions];
    NSString *normalized = [[PPSafeString(storageValue) lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (normalized.length == 0) return nil;
    for (PPAdGenderOption *option in options) {
        if ([option.storageValue isEqualToString:normalized]) {
            return option;
        }
    }
    return nil;
}

- (nullable PPAdGenderOption *)pp_genderOptionForLegacyFemaleValue:(BOOL)isFemale
{
    return [self pp_genderOptionForStorageValue:(isFemale ? PPAdGenderValueFemale : PPAdGenderValueMale)];
}

- (NSArray<PPAdGenderOption *> *)pp_genderSelectorOptions
{
    return @[
        [PPAdGenderOption optionWithStorageValue:PPAdGenderValueMale
                                  localizedTitle:[self pp_localizedStringForKey:@"Male" fallback:@"ذكر"]
                                 systemImageName:@"male"],
        [PPAdGenderOption optionWithStorageValue:PPAdGenderValueFemale
                                  localizedTitle:[self pp_localizedStringForKey:@"Female" fallback:@"أنثى"]
                                 systemImageName:@"female"],
        [PPAdGenderOption optionWithStorageValue:PPAdGenderValueUndefined
                                  localizedTitle:[self pp_localizedStringForKey:@"no_value" fallback:@"غير محدد"]
                                 systemImageName:@"questionmark.circle"]
    ];
}

- (nullable PPAdGenderOption *)pp_genderOptionFromValue:(id)value
{
    if ([value isKindOfClass:PPAdGenderOption.class]) {
        return value;
    }

    if ([value isKindOfClass:NSNumber.class]) {
        return [self pp_genderOptionForLegacyFemaleValue:[value boolValue]];
    }

    if ([value isKindOfClass:NSString.class]) {
        NSString *normalized =
            [[[PPSafeString(value) lowercaseString] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
                stringByReplacingOccurrencesOfString:@" " withString:@"_"];
        PPAdGenderOption *storageOption = [self pp_genderOptionForStorageValue:normalized];
        if (storageOption) return storageOption;

        NSString *raw = PPSafeString(value);
        for (PPAdGenderOption *option in [self pp_genderSelectorOptions]) {
            if ([raw isEqualToString:option.localizedTitle] ||
                [normalized isEqualToString:[[option.localizedTitle lowercaseString] stringByReplacingOccurrencesOfString:@" " withString:@"_"]]) {
                return option;
            }
        }
    }

    if ([value respondsToSelector:@selector(formDisplayText)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        NSString *display = [value performSelector:@selector(formDisplayText)];
#pragma clang diagnostic pop
        return [self pp_genderOptionFromValue:display];
    }

    return nil;
}

- (nullable PPAdGenderOption *)pp_genderOptionForAdModel
{
    PPAdGenderOption *stored = [self pp_genderOptionForStorageValue:self.adModel.gender];
    if (stored) return stored;

    if (self.mode == AdEditorModeEdit || self.editingAd) {
        return [self pp_genderOptionForLegacyFemaleValue:self.adModel.isFemale];
    }

    return nil;
}

- (void)pp_applyGenderSelectionToAdModel:(id)value
{
    PPAdGenderOption *option = [self pp_genderOptionFromValue:value];
    if (!option) return;

    self.adModel.gender = option.storageValue;
    if ([option.storageValue isEqualToString:PPAdGenderValueFemale]) {
        self.adModel.isFemale = YES;
    } else {
        self.adModel.isFemale = NO;
    }
    [self pp_syncGenderButtonsState];
    [self pp_updateStudioReadinessRadarAnimated:YES];
}

- (nullable PPAdFormField *)fieldForTag:(NSString *)tag
{
    PPAdFormField *f = [PPAdFormField new];
    f.tag = tag;
    if ([tag isEqualToString:@"adTitle"]) {
        f.value = self.adModel.adTitle;
    } else if ([tag isEqualToString:kcategory]) {
        f.value = self.selectedKind;
    } else if ([tag isEqualToString:ksubcategory]) {
        f.value = [self.selectedKind subKindForID:self.adModel.subcategory];
    } else if ([tag isEqualToString:kpetAge]) {
        f.value = self.adModel.petAgeMonths;
    } else if ([tag isEqualToString:@"isFemale"]) {
        f.value = [self pp_genderOptionForAdModel];
    } else if ([tag isEqualToString:kprice]) {
        f.value = self.adModel.price;
    } else if ([tag isEqualToString:kadLocation]) {
        f.value = self.selectedAdLocationName;
    } else if ([tag isEqualToString:kdesc]) {
        f.value = self.adModel.adDescription;
    }
    return f;
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
        self.adModel.adTitle = title;
    }

    MainKindsModel *mainKind = self.selectedMainKind;
    NSNumber *mainKindID = storedValues[@"categoryID"];
    if (!mainKind && [mainKindID respondsToSelector:@selector(integerValue)]) {
        mainKind = [MKM mainKindForID:mainKindID.integerValue];
    }

    if (mainKind) {
        self.selectedKind = mainKind;
        self.adModel.category = mainKind.ID;
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
            self.adModel.subcategory = subKind.ID;
        }
    }

    PPAdGenderOption *storedGenderOption = [self pp_genderOptionForStorageValue:storedValues[PPAdGenderDraftKey]];
    if (storedGenderOption) {
        [self pp_applyGenderSelectionToAdModel:storedGenderOption];
    } else if (storedValues[@"isFemale"] != nil) {
        PPAdGenderOption *legacyGenderOption = [self pp_genderOptionForLegacyFemaleValue:[storedValues[@"isFemale"] boolValue]];
        if (legacyGenderOption) {
            [self pp_applyGenderSelectionToAdModel:legacyGenderOption];
        }
    }

    if ([storedValues[@"petAgeMonths"] respondsToSelector:@selector(integerValue)]) {
        self.adModel.petAgeMonths = storedValues[@"petAgeMonths"];
    }

    NSNumber *restoredPrice = [GM moneyNumberFromInput:storedValues[@"price"]];
    if (restoredPrice) {
        self.adModel.price = restoredPrice;
    }

    NSString *desc = PPSafeString(storedValues[@"desc"]);
    if (desc.length) {
        self.adModel.adDescription = desc;
    }

    NSString *locationName = PPSafeString(storedValues[@"locationName"]);
    NSNumber *latitude = storedValues[@"latitude"];
    NSNumber *longitude = storedValues[@"longitude"];
    if (locationName.length) {
        self.selectedAdLocationName = locationName;
        self.adModel.locationName = locationName;
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
    [self pp_rebuildFormFields];
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

    CGFloat footerWidth = CGRectGetWidth(self.scrollView.bounds);
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
    // Footer is now managed by contentStack in pp_rebuildFormFields
}

- (void)setupImageCollection {
    self.imageCollection =
        [[PPImageCollection alloc] initWithFrame:CGRectZero
                                   maxImageCount:8
                                       useArabic:Language.isRTL];
    self.imageCollection.delegate = self;
    self.imageCollection.allowsEditing = YES;
    self.imageCollection.allowsVideoSelection = PPReusableVideoMediaEnabled();
    self.imageCollection.useArabic = Language.isRTL;
    self.imageCollection.headerContentInsets = UIEdgeInsetsMake(0.0, 16.0, 0.0, 16.0);
    self.imageCollection.backgroundColor = UIColor.clearColor;
    [self pp_refreshMediaLocalizedText];

    self.imageCollection.translatesAutoresizingMaskIntoConstraints = NO;
    self.imageCollection.hidden = YES;
    [self.view addSubview:self.imageCollection];

    [NSLayoutConstraint activateConstraints:@[
        [self.imageCollection.widthAnchor constraintEqualToConstant:1.0],
        [self.imageCollection.heightAnchor constraintEqualToConstant:1.0],
        [self.imageCollection.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.imageCollection.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor]
    ]];
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

        [self.listingFormView setValue:(self.selectedAdLocationName.length ? self.selectedAdLocationName : [self pp_localizedStringForKey:@"select_location" fallback:@"حدد الموقع على الخريطة"]) forIdentifier:kadLocation];
        if (!self.isHydratingFormData) {
            self.hasUserModifiedForm = YES;
        }
        [self pp_updateStudioReadinessRadarAnimated:YES];
    };
    picker.onLocationConfirmed = ^(GMSAddress *gmsAddress) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !gmsAddress) return;

        CLLocationCoordinate2D coordinate = gmsAddress.coordinate;
        if (!PPIsValidAdCoordinate(coordinate)) {
            [PPAlertHelper showErrorIn:self
                                 title:[self pp_localizedStringForKey:@"Location" fallback:@"الموقع"]
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

    NSString *symbolName = @"doc.text.fill";
    if ([title containsString:@"أساسية"] || [title containsString:@"basics"] || [title containsString:@"Basics"]) {
        symbolName = @"sparkles";
    } else if ([title containsString:@"الحيوان"] || [title containsString:@"Pet"] || [title containsString:@"pet"]) {
        symbolName = @"pawprint.fill";
    } else if ([title containsString:@"تفاصيل"] || [title containsString:@"Listing"] || [title containsString:@"listing"]) {
        symbolName = @"tag.fill";
    }

    UIView *iconBadge = [[UIView alloc] init];
    iconBadge.translatesAutoresizingMaskIntoConstraints = NO;
    iconBadge.backgroundColor = [PPAdFormAccentColor() colorWithAlphaComponent:0.12];
    iconBadge.layer.cornerRadius = 8.0;
    if (@available(iOS 13.0, *)) iconBadge.layer.cornerCurve = kCACornerCurveContinuous;
    [container addSubview:iconBadge];

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:12.0 weight:UIImageSymbolWeightBold];
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbolName withConfiguration:config]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = PPAdFormAccentColor();
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconBadge addSubview:iconView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:16.5] ?: [UIFont systemFontOfSize:16.5 weight:UIFontWeightBold];
    titleLabel.textColor = PPAdFormPrimaryTextColor();
    titleLabel.text = title ?: @"";
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [container addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:12.5] ?: [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.85];
    subtitleLabel.text = subtitle ?: @"";
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.numberOfLines = 2;
    [container addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [iconBadge.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:2.0],
        [iconBadge.topAnchor constraintEqualToAnchor:container.topAnchor constant:12.0],
        [iconBadge.widthAnchor constraintEqualToConstant:28.0],
        [iconBadge.heightAnchor constraintEqualToConstant:28.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconBadge.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconBadge.centerYAnchor],

        [titleLabel.centerYAnchor constraintEqualToAnchor:iconBadge.centerYAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconBadge.trailingAnchor constant:10.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-4.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:iconBadge.bottomAnchor constant:5.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:iconBadge.leadingAnchor constant:2.0],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:container.bottomAnchor constant:-6.0]
    ]];

    return container;
}

- (void)pp_animateSelectorTouchForField:(NSString *)tag
{
    PPFormFieldRowView *row = nil;
    if (self.basicFormView.rowsByIdentifier[tag]) {
        row = self.basicFormView.rowsByIdentifier[tag];
    } else if (self.petFormView.rowsByIdentifier[tag]) {
        row = self.petFormView.rowsByIdentifier[tag];
    } else if (self.listingFormView.rowsByIdentifier[tag]) {
        row = self.listingFormView.rowsByIdentifier[tag];
    }
    if (!row) return;

    if (!UIAccessibilityIsReduceMotionEnabled()) {
        UIImpactFeedbackGenerator *feedback =
            [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [feedback prepare];
        [feedback impactOccurred];
    }

    UIView *targetView = row;
    [UIView animateWithDuration:0.09
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        targetView.transform = CGAffineTransformMakeScale(0.985, 0.985);
    } completion:^(BOOL finished) {
        (void)finished;
        [UIView animateWithDuration:0.24
                              delay:0.0
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.28
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            targetView.transform = self.selectorSheetFocusActive
                ? CGAffineTransformMakeScale(0.995, 0.995)
                : CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (void)pp_setSelectorSheetFocusActive:(BOOL)active
                              forField:(NSString *)tag
                              animated:(BOOL)animated
{
    if (self.selectorSheetFocusActive == active && active) {
        return;
    }
    self.selectorSheetFocusActive = active;

    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    PPFormFieldRowView *selectedRow = nil;
    if (tag) {
        if (self.basicFormView.rowsByIdentifier[tag]) {
            selectedRow = self.basicFormView.rowsByIdentifier[tag];
        } else if (self.petFormView.rowsByIdentifier[tag]) {
            selectedRow = self.petFormView.rowsByIdentifier[tag];
        } else if (self.listingFormView.rowsByIdentifier[tag]) {
            selectedRow = self.listingFormView.rowsByIdentifier[tag];
        }
    }

    void (^changes)(void) = ^{
        self.formHeroCardView.alpha = active ? 0.86 : 1.0;
        self.formHeroCardView.transform = (active && !reduceMotion)
            ? CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -5.0),
                                      CGAffineTransformMakeScale(0.982, 0.982))
            : CGAffineTransformIdentity;

        self.formHeroTitleLabel.alpha = active ? 0.88 : 1.0;
        self.formHeroSubtitleLabel.alpha = active ? 0.76 : 1.0;
        self.formHeroMetaLabel.alpha = active ? 0.86 : 1.0;
        self.backgroundGlowViewTop.alpha = active ? 0.68 : 1.0;
        self.backgroundGlowViewBottom.alpha = active ? 0.66 : 1.0;

        NSArray<PPFormEngineView *> *forms = @[self.basicFormView, self.petFormView, self.listingFormView];
        for (PPFormEngineView *form in forms) {
            for (NSString *key in form.rowsByIdentifier) {
                PPFormFieldRowView *row = form.rowsByIdentifier[key];
                BOOL selected = (selectedRow && row == selectedRow);
                row.alpha = active ? (selected ? 1.0 : 0.74) : 1.0;
                if (reduceMotion) {
                    row.transform = CGAffineTransformIdentity;
                } else if (active) {
                    row.transform = selected
                        ? CGAffineTransformMakeScale(0.995, 0.995)
                        : CGAffineTransformMakeTranslation(0.0, -3.0);
                } else {
                    row.transform = CGAffineTransformIdentity;
                }
            }
        }
    };

    if (!animated) {
        changes();
        return;
    }

    if (reduceMotion) {
        [UIView animateWithDuration:0.18
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:changes
                         completion:nil];
        return;
    }

    NSTimeInterval duration = active ? 0.34 : 0.42;
    CGFloat damping = active ? 0.90 : 0.84;
    [UIView animateWithDuration:duration
                          delay:0.0
         usingSpringWithDamping:damping
          initialSpringVelocity:0.22
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:changes
                     completion:nil];
}

- (void)pp_prepareSelectorSheetPresentationForField:(NSString *)tag
{
    [self.view endEditing:YES];
    [self pp_animateSelectorTouchForField:tag];
    [self pp_setSelectorSheetFocusActive:YES forField:tag animated:YES];
}

- (void)pp_restoreSelectorSheetPresentationFocusAnimated:(BOOL)animated
{
    [self pp_setSelectorSheetFocusActive:NO forField:nil animated:animated];
}

- (void)pp_presentMainCategoryPickerForConfig:(PPFormFieldConfig *)config {
    __weak typeof(self) weakSelf = self;
    PPSelectOptionViewController *vc = [[PPSelectOptionViewController alloc]
        initWithOptions:MKM.MainKindsArray
                  title:config.title
                    row:nil
       presentationStyle:PPSelectOptionPresentationSheet
             completion:^(id _Nullable selectedObject) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf pp_restoreSelectorSheetPresentationFocusAnimated:YES];
            if (![selectedObject isKindOfClass:[MainKindsModel class]]) {
                weakSelf.selectedKind = nil;
                weakSelf.adModel.category = 0;
                [weakSelf pp_rebuildFormFields];
                return;
            }
            MainKindsModel *kind = selectedObject;
            weakSelf.selectedKind = kind;
            weakSelf.adModel.category = kind.ID;
            weakSelf.adModel.subcategory = 0;
            [weakSelf pp_rebuildFormFields];
            if (!weakSelf.isHydratingFormData) {
                weakSelf.hasUserModifiedForm = YES;
            }
        });
    }];
    vc.selectedOption = self.selectedKind;
    vc.modalPresentationStyle = UIModalPresentationPageSheet;
    vc.presentationController.delegate = self;
    if (@available(iOS 15.0, *)) {
        vc.sheetPresentationController.delegate = self;
    }
    [self pp_prepareSelectorSheetPresentationForField:config.identifier];
    
    [PPFunc presentSheetFrom:self sheetVC:vc detentStyle:PPSheetDetentStyle80];
   // [self presentViewController:vc animated:YES completion:nil];
}

- (void)pp_presentSubCategoryPickerForConfig:(PPFormFieldConfig *)config {
    if (!self.selectedKind.SubKindsArray.count) return;
    __weak typeof(self) weakSelf = self;
    PPSelectOptionViewController *vc = [[PPSelectOptionViewController alloc]
        initWithOptions:self.selectedKind.SubKindsArray
                  title:config.title
                    row:nil
       presentationStyle:PPSelectOptionPresentationSheet
             completion:^(id _Nullable selectedObject) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf pp_restoreSelectorSheetPresentationFocusAnimated:YES];
            if (![selectedObject isKindOfClass:[SubKindModel class]]) return;
            SubKindModel *sub = selectedObject;
            weakSelf.adModel.subcategory = sub.ID;
            [weakSelf pp_rebuildFormFields];
            if (!weakSelf.isHydratingFormData) {
                weakSelf.hasUserModifiedForm = YES;
            }
        });
    }];
    SubKindModel *currentSub = nil;
    if (self.adModel.subcategory > 0) {
        currentSub = [self.selectedKind subKindForID:self.adModel.subcategory];
    }
    vc.selectedOption = currentSub;
    vc.modalPresentationStyle = UIModalPresentationPageSheet;
    vc.presentationController.delegate = self;
    if (@available(iOS 15.0, *)) {
        vc.sheetPresentationController.delegate = self;
    }
    [self pp_prepareSelectorSheetPresentationForField:config.identifier];
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)pp_presentGenderPickerForConfig:(PPFormFieldConfig *)config {
    __weak typeof(self) weakSelf = self;
    NSArray *options = [self pp_genderSelectorOptions];
    PPSelectOptionViewController *vc = [[PPSelectOptionViewController alloc]
        initWithOptions:options
                  title:config.title
                    row:nil
       presentationStyle:PPSelectOptionPresentationSheet
             completion:^(id _Nullable selectedObject) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf pp_restoreSelectorSheetPresentationFocusAnimated:YES];
            PPAdGenderOption *option = [weakSelf pp_genderOptionFromValue:selectedObject];
            [weakSelf pp_applyGenderSelectionToAdModel:option];
            [weakSelf pp_rebuildFormFields];
            if (!weakSelf.isHydratingFormData) {
                weakSelf.hasUserModifiedForm = YES;
            }
        });
    }];
    vc.selectedOption = [self pp_genderOptionForAdModel];
    vc.showSearchBar = NO;
    vc.isGenderSelector = YES;

    // Keep UIKit's floating sheet chrome direction-neutral. The option
    // controller continues to apply Arabic/English semantics to its own
    // table, header, and cells, while the outer presentation remains centered
    // with equal physical margins in both layout directions.
    UINavigationController *sheetContainer = [[UINavigationController alloc] initWithRootViewController:vc];
    sheetContainer.navigationBarHidden = YES;
    sheetContainer.modalPresentationStyle = UIModalPresentationPageSheet;
    sheetContainer.view.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    sheetContainer.presentationController.delegate = self;
    if (@available(iOS 15.0, *)) {
        sheetContainer.sheetPresentationController.delegate = self;
    }
    [self pp_prepareSelectorSheetPresentationForField:config.identifier];
    [self presentViewController:sheetContainer animated:YES completion:nil];
}

#pragma mark - Build Form
- (void)initForm {
    self.view.backgroundColor = [self pp_adCanvasColor];
    self.view.clipsToBounds = YES;

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.backgroundColor = UIColor.clearColor;
    scroll.showsVerticalScrollIndicator = NO;
    scroll.showsHorizontalScrollIndicator = NO;
    scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    scroll.contentInset = UIEdgeInsetsMake(6, 0, 140, 0);
    scroll.scrollIndicatorInsets = UIEdgeInsetsMake(6, 0, 140, 0);
    [self.view addSubview:scroll];
    self.scrollView = scroll;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.distribution = UIStackViewDistributionFill;
    stack.spacing = 18.0;
    stack.layoutMarginsRelativeArrangement = YES;
    stack.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(8.0, 18.0, 24.0, 18.0);
    [scroll addSubview:stack];
    self.contentStack = stack;

    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor]
    ]];

    [self pp_setupFloatingActionDock];
    [self pp_rebuildFormFields];
}

- (PPFormStyle *)pp_adFormStyle {
    PPFormStyle *style = [PPFormStyle defaultStyle];
    style.groupedMode = YES;
    style.hideAccentStrip = YES;
    style.cardBackgroundColor = UIColor.clearColor;
    style.cardBorderColor = UIColor.clearColor;
    style.cardBorderWidth = 0.0;
    style.cardCornerRadius = 0.0;
    style.fieldLeading = 0.0;
    style.fieldTrailing = 0.0;
    style.fieldHorizontalInset = 14.0;
    style.fieldTopInset = 4.0;
    style.fieldBottomInset = 4.0;
    style.rowBottomInset = 8.0;
    style.minimumSingleLineFieldHeight = 48.0;
    style.minimumTextViewFieldHeight = 110.0;
    style.fieldBackgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.06]
            : [UIColor colorWithRed:0.96 green:0.95 blue:0.93 alpha:1.0];
    }];
    style.fieldBorderWidth = 0.8;
    style.fieldBorderColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.1]
            : [UIColor colorWithWhite:0.0 alpha:0.06];
    }];
    style.accentColor = PPAdFormAccentColor();
    style.primaryTextColor = PPAdFormPrimaryTextColor();
    style.secondaryTextColor = UIColor.secondaryLabelColor;
    style.titleFont = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold];
    style.inputFont = [GM MidFontWithSize:14.5] ?: [UIFont systemFontOfSize:14.5 weight:UIFontWeightMedium];
    style.placeholderFont = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    style.fieldCornerRadius = 13.0;
    style.stackSpacing = 10.0;
    style.shadowOpacity = 0.0;
    return style;
}

#pragma mark - Studio Helpers & Cards

- (UIView *)pp_createStudioCardContainer {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0.16 green:0.16 blue:0.18 alpha:1.0]
            : UIColor.whiteColor;
    }];
    card.layer.cornerRadius = 22.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 0.8;
    card.layer.borderColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.08]
            : [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.06];
    }].CGColor;
    card.layer.shadowColor = UIColor.blackColor.CGColor;
    card.layer.shadowOpacity = 0.035;
    card.layer.shadowRadius = 12.0;
    card.layer.shadowOffset = CGSizeMake(0.0, 3.0);
    return card;
}

- (UIView *)pp_createStudioCardHeaderWithIcon:(NSString *)symbolName
                                    iconColor:(UIColor *)iconColor
                                  iconBgColor:(UIColor *)iconBgColor
                                        title:(NSString *)title
                                     subtitle:(NSString *)subtitle
                                 trailingView:(nullable UIView *)trailingView
{
    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    iconView.image = [[UIImage systemImageNamed:symbolName withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    iconView.tintColor = iconColor;
    iconView.contentMode = UIViewContentModeCenter;
    iconView.backgroundColor = iconBgColor;
    iconView.layer.cornerRadius = 10.0;
    iconView.layer.masksToBounds = YES;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightBold];
    titleLabel.textColor = PPAdFormPrimaryTextColor();
    titleLabel.text = title;

    UILabel *subLabel = [[UILabel alloc] init];
    subLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subLabel.font = [GM fontWithSize:11.5] ?: [UIFont systemFontOfSize:11.5 weight:UIFontWeightRegular];
    subLabel.textColor = UIColor.secondaryLabelColor;
    subLabel.numberOfLines = 2;
    subLabel.text = subtitle;

    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, subLabel]];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 2.0;

    UIStackView *leadingStack = [[UIStackView alloc] initWithArrangedSubviews:@[iconView, textStack]];
    leadingStack.translatesAutoresizingMaskIntoConstraints = NO;
    leadingStack.axis = UILayoutConstraintAxisHorizontal;
    leadingStack.spacing = 10.0;
    leadingStack.alignment = UIStackViewAlignmentCenter;

    [header addSubview:leadingStack];

    [NSLayoutConstraint activateConstraints:@[
        [iconView.widthAnchor constraintEqualToConstant:36.0],
        [iconView.heightAnchor constraintEqualToConstant:36.0],
        [leadingStack.topAnchor constraintEqualToAnchor:header.topAnchor],
        [leadingStack.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [leadingStack.bottomAnchor constraintEqualToAnchor:header.bottomAnchor]
    ]];

    if (trailingView) {
        trailingView.translatesAutoresizingMaskIntoConstraints = NO;
        [header addSubview:trailingView];
        [NSLayoutConstraint activateConstraints:@[
            [trailingView.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],
            [trailingView.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
            [leadingStack.trailingAnchor constraintLessThanOrEqualToAnchor:trailingView.leadingAnchor constant:-8.0]
        ]];
    } else {
        [leadingStack.trailingAnchor constraintLessThanOrEqualToAnchor:header.trailingAnchor];
    }

    return header;
}

- (UIView *)pp_buildApexHeaderView {
    UIView *apex = [[UIView alloc] init];
    apex.translatesAutoresizingMaskIntoConstraints = NO;
    self.studioApexHeaderView = apex;

    // Badge capsule pill
    UIView *badge = [[UIView alloc] init];
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.backgroundColor = [UIColor colorWithRed:1.0 green:0.95 blue:0.88 alpha:1.0];
    badge.layer.cornerRadius = 12.0;

    UIImageView *badgeIcon = [[UIImageView alloc] init];
    badgeIcon.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *badgeSym = [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightBold];
    badgeIcon.image = [UIImage systemImageNamed:@"pawprint.fill" withConfiguration:badgeSym];
    badgeIcon.tintColor = [UIColor colorWithRed:0.92 green:0.35 blue:0.05 alpha:1.0];

    UILabel *badgeLabel = [[UILabel alloc] init];
    badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    badgeLabel.font = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold];
    badgeLabel.textColor = [UIColor colorWithRed:0.92 green:0.35 blue:0.05 alpha:1.0];
    badgeLabel.text = (self.mode == AdEditorModeEdit)
        ? ([self pp_localizedStringForKey:@"EditAdTitle" fallback:@"تعديل الإعلان"])
        : [self pp_localizedStringForKey:@"ad_badge_pet_listing" fallback:@"إعلان حيوان أليف"];

    UIStackView *badgeStack = [[UIStackView alloc] initWithArrangedSubviews:@[badgeIcon, badgeLabel]];
    badgeStack.translatesAutoresizingMaskIntoConstraints = NO;
    badgeStack.axis = UILayoutConstraintAxisHorizontal;
    badgeStack.spacing = 6.0;
    badgeStack.alignment = UIStackViewAlignmentCenter;
    [badge addSubview:badgeStack];

    [NSLayoutConstraint activateConstraints:@[
        [badge.heightAnchor constraintEqualToConstant:24.0],
        [badgeStack.leadingAnchor constraintEqualToAnchor:badge.leadingAnchor constant:9.0],
        [badgeStack.trailingAnchor constraintEqualToAnchor:badge.trailingAnchor constant:-9.0],
        [badgeStack.centerYAnchor constraintEqualToAnchor:badge.centerYAnchor]
    ]];

    // Title label
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:22.0] ?: [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold];
    titleLabel.textColor = PPAdFormPrimaryTextColor();
    titleLabel.text = (self.mode == AdEditorModeEdit)
        ? ([self pp_localizedStringForKey:@"EditAdTitle" fallback:@"تعديل الإعلان"])
        : ([self pp_localizedStringForKey:@"addNewAd" fallback:@"إضافة إعلان جديد"]);

    UIStackView *leadingStack = [[UIStackView alloc] initWithArrangedSubviews:@[badge, titleLabel]];
    leadingStack.translatesAutoresizingMaskIntoConstraints = NO;
    leadingStack.axis = UILayoutConstraintAxisVertical;
    leadingStack.spacing = 4.0;
    leadingStack.alignment = UIStackViewAlignmentLeading;
    [apex addSubview:leadingStack];

    // Cancel capsule button
    UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    cancelBtn.translatesAutoresizingMaskIntoConstraints = NO;
    cancelBtn.layer.cornerRadius = 17.0;
    cancelBtn.layer.cornerCurve = kCACornerCurveContinuous;
    cancelBtn.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.12]
            : UIColor.whiteColor;
    }];
    cancelBtn.layer.borderWidth = 0.8;
    cancelBtn.layer.borderColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.1]
            : [UIColor colorWithWhite:0.0 alpha:0.08];
    }].CGColor;
    cancelBtn.layer.shadowColor = UIColor.blackColor.CGColor;
    cancelBtn.layer.shadowOpacity = 0.04;
    cancelBtn.layer.shadowRadius = 4.0;
    cancelBtn.layer.shadowOffset = CGSizeMake(0.0, 2.0);

    [cancelBtn setTitle:([self pp_localizedStringForKey:@"Cancel" fallback:@"إلغاء"]) forState:UIControlStateNormal];
    [cancelBtn setTitleColor:UIColor.secondaryLabelColor forState:UIControlStateNormal];
    cancelBtn.titleLabel.font = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];

    UIImageSymbolConfiguration *xSym = [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightBold];
    [cancelBtn setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:xSym] forState:UIControlStateNormal];
    cancelBtn.tintColor = UIColor.secondaryLabelColor;
    cancelBtn.contentEdgeInsets = UIEdgeInsetsMake(7, 14, 7, 14);
    cancelBtn.imageEdgeInsets = UIEdgeInsetsMake(0, Language.isRTL ? 5 : -5, 0, Language.isRTL ? -5 : 5);

    [cancelBtn addTarget:self action:@selector(pp_handleBackNavigation) forControlEvents:UIControlEventTouchUpInside];
    [apex addSubview:cancelBtn];

    [NSLayoutConstraint activateConstraints:@[
        [leadingStack.topAnchor constraintEqualToAnchor:apex.topAnchor],
        [leadingStack.leadingAnchor constraintEqualToAnchor:apex.leadingAnchor],
        [leadingStack.bottomAnchor constraintEqualToAnchor:apex.bottomAnchor],

        [cancelBtn.trailingAnchor constraintEqualToAnchor:apex.trailingAnchor],
        [cancelBtn.centerYAnchor constraintEqualToAnchor:apex.centerYAnchor],
        [cancelBtn.heightAnchor constraintEqualToConstant:34.0],
        [leadingStack.trailingAnchor constraintLessThanOrEqualToAnchor:cancelBtn.leadingAnchor constant:-12.0]
    ]];

    return apex;
}

- (UIView *)pp_buildRadarCardView {
    UIView *card = [self pp_createStudioCardContainer];
    self.studioRadarCardView = card;

    // Left circular ring view
    self.studioRadarRingView = [[PPRadarProgressRingView alloc] init];
    self.studioRadarRingView.translatesAutoresizingMaskIntoConstraints = NO;

    // Right title & advice
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:14.5] ?: [UIFont systemFontOfSize:14.5 weight:UIFontWeightBold];
    titleLabel.textColor = PPAdFormPrimaryTextColor();
    titleLabel.text = [self pp_localizedStringForKey:@"ad_radar_title" fallback:@"رادار اكتمال الإعلان"];

    // Seal complete badge
    UIView *sealBadge = [[UIView alloc] init];
    sealBadge.translatesAutoresizingMaskIntoConstraints = NO;
    sealBadge.backgroundColor = [UIColor colorWithRed:0.06 green:0.73 blue:0.51 alpha:0.12];
    sealBadge.layer.cornerRadius = 10.0;
    sealBadge.hidden = YES;
    self.studioRadarCompleteBadge = sealBadge;

    UIImageView *sealIcon = [[UIImageView alloc] init];
    sealIcon.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *sealConfig = [UIImageSymbolConfiguration configurationWithPointSize:10 weight:UIImageSymbolWeightBold];
    sealIcon.image = [UIImage systemImageNamed:@"checkmark.seal.fill" withConfiguration:sealConfig];
    sealIcon.tintColor = [UIColor colorWithRed:0.06 green:0.73 blue:0.51 alpha:1.0];

    UILabel *sealLabel = [[UILabel alloc] init];
    sealLabel.translatesAutoresizingMaskIntoConstraints = NO;
    sealLabel.font = [GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    sealLabel.textColor = [UIColor colorWithRed:0.06 green:0.73 blue:0.51 alpha:1.0];
    sealLabel.text = [self pp_localizedStringForKey:@"ad_radar_completed" fallback:@"مكتمل"];

    UIStackView *sealStack = [[UIStackView alloc] initWithArrangedSubviews:@[sealIcon, sealLabel]];
    sealStack.translatesAutoresizingMaskIntoConstraints = NO;
    sealStack.axis = UILayoutConstraintAxisHorizontal;
    sealStack.spacing = 3.0;
    sealStack.alignment = UIStackViewAlignmentCenter;
    [sealBadge addSubview:sealStack];

    [NSLayoutConstraint activateConstraints:@[
        [sealBadge.heightAnchor constraintEqualToConstant:20.0],
        [sealStack.leadingAnchor constraintEqualToAnchor:sealBadge.leadingAnchor constant:6.0],
        [sealStack.trailingAnchor constraintEqualToAnchor:sealBadge.trailingAnchor constant:-6.0],
        [sealStack.centerYAnchor constraintEqualToAnchor:sealBadge.centerYAnchor]
    ]];

    UIStackView *titleRow = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, sealBadge]];
    titleRow.translatesAutoresizingMaskIntoConstraints = NO;
    titleRow.axis = UILayoutConstraintAxisHorizontal;
    titleRow.spacing = 6.0;
    titleRow.alignment = UIStackViewAlignmentCenter;

    UILabel *adviceLabel = [[UILabel alloc] init];
    adviceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    adviceLabel.font = [GM fontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightRegular];
    adviceLabel.textColor = UIColor.secondaryLabelColor;
    adviceLabel.numberOfLines = 2;
    adviceLabel.text = [self pp_currentReadinessAdvice];
    self.studioRadarAdviceLabel = adviceLabel;

    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleRow, adviceLabel]];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 3.0;

    UIStackView *mainStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.studioRadarRingView, textStack]];
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    mainStack.axis = UILayoutConstraintAxisHorizontal;
    mainStack.spacing = 12.0;
    mainStack.alignment = UIStackViewAlignmentCenter;
    [card addSubview:mainStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.studioRadarRingView.widthAnchor constraintEqualToConstant:46.0],
        [self.studioRadarRingView.heightAnchor constraintEqualToConstant:46.0],
        [mainStack.topAnchor constraintEqualToAnchor:card.topAnchor constant:14.0],
        [mainStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14.0],
        [mainStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14.0],
        [mainStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14.0]
    ]];

    return card;
}

- (UIView *)pp_buildMediaStudioCardView {
    UIView *card = [self pp_createStudioCardContainer];
    self.studioMediaCardView = card;

    // Trailing badge
    UILabel *countBadge = [[UILabel alloc] init];
    countBadge.translatesAutoresizingMaskIntoConstraints = NO;
    countBadge.font = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold];
    countBadge.textColor = UIColor.secondaryLabelColor;
    countBadge.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.08]
            : [UIColor colorWithRed:0.95 green:0.94 blue:0.92 alpha:1.0];
    }];
    countBadge.layer.cornerRadius = 12.0;
    countBadge.layer.masksToBounds = YES;
    countBadge.textAlignment = NSTextAlignmentCenter;
    countBadge.text = [NSString stringWithFormat:[self pp_localizedStringForKey:@"community_media_count" fallback:@"%d من %d"], (int)[self safeMediaOutputCount], 8];
    self.studioMediaCountBadgeLabel = countBadge;

    UIView *header = [self pp_createStudioCardHeaderWithIcon:@"photo.stack.fill"
                                                   iconColor:[UIColor colorWithRed:0.39 green:0.40 blue:0.95 alpha:1.0]
                                                 iconBgColor:[UIColor colorWithRed:0.93 green:0.95 blue:1.0 alpha:1.0]
                                                       title:[self pp_localizedStringForKey:@"community_media_title" fallback:@"وسائط موثقة"]
                                                    subtitle:[self pp_localizedStringForKey:@"community_media_privacy" fallback:@"تخضع الصور ومقاطع الفيديو للفحص والمراجعة قبل العرض العام."]
                                                trailingView:countBadge];

    [NSLayoutConstraint activateConstraints:@[
        [countBadge.heightAnchor constraintEqualToConstant:24.0],
        [countBadge.widthAnchor constraintGreaterThanOrEqualToConstant:90.0]
    ]];

    // Horizontal media scroll view
    UIScrollView *mediaScroll = [[UIScrollView alloc] init];
    mediaScroll.translatesAutoresizingMaskIntoConstraints = NO;
    mediaScroll.showsHorizontalScrollIndicator = NO;
    mediaScroll.alwaysBounceHorizontal = YES;
    self.studioMediaScrollView = mediaScroll;

    UIStackView *mediaStack = [[UIStackView alloc] init];
    mediaStack.translatesAutoresizingMaskIntoConstraints = NO;
    mediaStack.axis = UILayoutConstraintAxisHorizontal;
    mediaStack.spacing = 12.0;
    mediaStack.alignment = UIStackViewAlignmentCenter;
    self.studioMediaThumbnailsStack = mediaStack;
    [mediaScroll addSubview:mediaStack];

    [NSLayoutConstraint activateConstraints:@[
        [mediaScroll.heightAnchor constraintEqualToConstant:124.0],
        [mediaStack.topAnchor constraintEqualToAnchor:mediaScroll.contentLayoutGuide.topAnchor constant:4.0],
        [mediaStack.bottomAnchor constraintEqualToAnchor:mediaScroll.contentLayoutGuide.bottomAnchor constant:-4.0],
        [mediaStack.leadingAnchor constraintEqualToAnchor:mediaScroll.contentLayoutGuide.leadingAnchor],
        [mediaStack.trailingAnchor constraintEqualToAnchor:mediaScroll.contentLayoutGuide.trailingAnchor],
        [mediaStack.heightAnchor constraintEqualToAnchor:mediaScroll.frameLayoutGuide.heightAnchor constant:-8.0]
    ]];

    // Footnote
    UIImageView *shieldIcon = [[UIImageView alloc] init];
    shieldIcon.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *shieldConfig = [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightSemibold];
    shieldIcon.image = [UIImage systemImageNamed:@"lock.shield.fill" withConfiguration:shieldConfig];
    shieldIcon.tintColor = [UIColor colorWithRed:0.06 green:0.73 blue:0.51 alpha:1.0];

    UILabel *footnoteLabel = [[UILabel alloc] init];
    footnoteLabel.translatesAutoresizingMaskIntoConstraints = NO;
    footnoteLabel.font = [GM fontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightRegular];
    footnoteLabel.textColor = UIColor.secondaryLabelColor;
    footnoteLabel.text = [self pp_localizedStringForKey:@"community_media_safe_inspection" fallback:@"تخضع الوسائط للفحص الأمني لضمان دقة الإعلانات وسلامة المجتمع"];
    footnoteLabel.numberOfLines = 2;

    UIStackView *footnoteStack = [[UIStackView alloc] initWithArrangedSubviews:@[shieldIcon, footnoteLabel]];
    footnoteStack.translatesAutoresizingMaskIntoConstraints = NO;
    footnoteStack.axis = UILayoutConstraintAxisHorizontal;
    footnoteStack.spacing = 6.0;
    footnoteStack.alignment = UIStackViewAlignmentCenter;

    UIStackView *cardStack = [[UIStackView alloc] initWithArrangedSubviews:@[header, mediaScroll, footnoteStack]];
    cardStack.translatesAutoresizingMaskIntoConstraints = NO;
    cardStack.axis = UILayoutConstraintAxisVertical;
    cardStack.spacing = 14.0;
    [card addSubview:cardStack];

    [NSLayoutConstraint activateConstraints:@[
        [cardStack.topAnchor constraintEqualToAnchor:card.topAnchor constant:16.0],
        [cardStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [cardStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [cardStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16.0]
    ]];

    [self pp_refreshStudioMediaThumbnails];
    return card;
}

- (void)pp_refreshStudioMediaThumbnails {
    if (!self.studioMediaThumbnailsStack) return;

    for (UIView *v in self.studioMediaThumbnailsStack.arrangedSubviews) {
        [v removeFromSuperview];
    }

    NSArray<UIImage *> *images = [self safeMediaOutputArray];
    NSInteger count = images.count;

    if (self.studioMediaCountBadgeLabel) {
        self.studioMediaCountBadgeLabel.text = [NSString stringWithFormat:[self pp_localizedStringForKey:@"community_media_count" fallback:@"%d من %d"], (int)count, 8];
        if (count > 0) {
            self.studioMediaCountBadgeLabel.textColor = [UIColor colorWithRed:0.06 green:0.73 blue:0.51 alpha:1.0];
            self.studioMediaCountBadgeLabel.backgroundColor = [UIColor colorWithRed:0.06 green:0.73 blue:0.51 alpha:0.12];
        } else {
            self.studioMediaCountBadgeLabel.textColor = UIColor.secondaryLabelColor;
            self.studioMediaCountBadgeLabel.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
                return tc.userInterfaceStyle == UIUserInterfaceStyleDark
                    ? [UIColor colorWithWhite:1.0 alpha:0.08]
                    : [UIColor colorWithRed:0.95 green:0.94 blue:0.92 alpha:1.0];
            }];
        }
    }

    // Dashed add button (if count < 8)
    if (count < 8) {
        PPDashedAddMediaButton *addBtn = [[PPDashedAddMediaButton alloc] initWithFrame:CGRectMake(0, 0, 104, 116)];
        addBtn.translatesAutoresizingMaskIntoConstraints = NO;
        addBtn.layer.cornerRadius = 16.0;
        addBtn.layer.cornerCurve = kCACornerCurveContinuous;
        addBtn.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            return tc.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithWhite:1.0 alpha:0.05]
                : [UIColor colorWithRed:0.96 green:0.96 blue:0.98 alpha:1.0];
        }];

        UIView *cameraCircle = [[UIView alloc] init];
        cameraCircle.translatesAutoresizingMaskIntoConstraints = NO;
        cameraCircle.userInteractionEnabled = NO;
        cameraCircle.backgroundColor = [UIColor colorWithRed:0.39 green:0.40 blue:0.95 alpha:0.12];
        cameraCircle.layer.cornerRadius = 22.0;

        UIImageView *cameraIcon = [[UIImageView alloc] init];
        cameraIcon.translatesAutoresizingMaskIntoConstraints = NO;
        UIImageSymbolConfiguration *camSym = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
        cameraIcon.image = [UIImage systemImageNamed:@"camera.fill" withConfiguration:camSym];
        cameraIcon.tintColor = [UIColor colorWithRed:0.39 green:0.40 blue:0.95 alpha:1.0];
        [cameraCircle addSubview:cameraIcon];

        UILabel *addLabel = [[UILabel alloc] init];
        addLabel.translatesAutoresizingMaskIntoConstraints = NO;
        addLabel.userInteractionEnabled = NO;
        addLabel.font = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold];
        addLabel.textColor = [UIColor colorWithRed:0.39 green:0.40 blue:0.95 alpha:1.0];
        addLabel.textAlignment = NSTextAlignmentCenter;
        addLabel.numberOfLines = 2;
        addLabel.text = [self pp_localizedStringForKey:@"community_add_media" fallback:@"إضافة صور أو فيديو"];

        UIStackView *btnContent = [[UIStackView alloc] initWithArrangedSubviews:@[cameraCircle, addLabel]];
        btnContent.translatesAutoresizingMaskIntoConstraints = NO;
        btnContent.userInteractionEnabled = NO;
        btnContent.axis = UILayoutConstraintAxisVertical;
        btnContent.spacing = 8.0;
        btnContent.alignment = UIStackViewAlignmentCenter;
        [addBtn addSubview:btnContent];

        [NSLayoutConstraint activateConstraints:@[
            [addBtn.widthAnchor constraintEqualToConstant:104.0],
            [addBtn.heightAnchor constraintEqualToConstant:116.0],

            [cameraCircle.widthAnchor constraintEqualToConstant:44.0],
            [cameraCircle.heightAnchor constraintEqualToConstant:44.0],
            [cameraIcon.centerXAnchor constraintEqualToAnchor:cameraCircle.centerXAnchor],
            [cameraIcon.centerYAnchor constraintEqualToAnchor:cameraCircle.centerYAnchor],

            [btnContent.centerXAnchor constraintEqualToAnchor:addBtn.centerXAnchor],
            [btnContent.centerYAnchor constraintEqualToAnchor:addBtn.centerYAnchor],
            [btnContent.leadingAnchor constraintGreaterThanOrEqualToAnchor:addBtn.leadingAnchor constant:6.0],
            [btnContent.trailingAnchor constraintLessThanOrEqualToAnchor:addBtn.trailingAnchor constant:-6.0]
        ]];

        [addBtn addTarget:self action:@selector(pp_handleAddMediaTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.studioMediaThumbnailsStack addArrangedSubview:addBtn];
    }

    // Thumbnails
    for (NSInteger i = 0; i < count; i++) {
        UIImage *img = images[i];
        UIView *thumbContainer = [[UIView alloc] init];
        thumbContainer.translatesAutoresizingMaskIntoConstraints = NO;
        thumbContainer.layer.cornerRadius = 16.0;
        thumbContainer.layer.cornerCurve = kCACornerCurveContinuous;
        thumbContainer.layer.masksToBounds = YES;
        thumbContainer.layer.borderWidth = 0.8;
        thumbContainer.layer.borderColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            return tc.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithWhite:1.0 alpha:0.1]
                : [UIColor colorWithWhite:0.0 alpha:0.08];
        }].CGColor;

        UIImageView *imgView = [[UIImageView alloc] initWithImage:img];
        imgView.translatesAutoresizingMaskIntoConstraints = NO;
        imgView.contentMode = UIViewContentModeScaleAspectFill;
        imgView.clipsToBounds = YES;
        [thumbContainer addSubview:imgView];

        [NSLayoutConstraint activateConstraints:@[
            [thumbContainer.widthAnchor constraintEqualToConstant:104.0],
            [thumbContainer.heightAnchor constraintEqualToConstant:116.0],
            [imgView.topAnchor constraintEqualToAnchor:thumbContainer.topAnchor],
            [imgView.leadingAnchor constraintEqualToAnchor:thumbContainer.leadingAnchor],
            [imgView.trailingAnchor constraintEqualToAnchor:thumbContainer.trailingAnchor],
            [imgView.bottomAnchor constraintEqualToAnchor:thumbContainer.bottomAnchor]
        ]];

        if (i == 0) {
            UIView *coverPill = [[UIView alloc] init];
            coverPill.translatesAutoresizingMaskIntoConstraints = NO;
            coverPill.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.65];
            coverPill.layer.cornerRadius = 8.0;

            UILabel *coverLabel = [[UILabel alloc] init];
            coverLabel.translatesAutoresizingMaskIntoConstraints = NO;
            coverLabel.font = [GM boldFontWithSize:9.0] ?: [UIFont systemFontOfSize:9.0 weight:UIFontWeightBold];
            coverLabel.textColor = UIColor.whiteColor;
            coverLabel.text = [self pp_localizedStringForKey:@"community_media_cover_badge" fallback:@"الصورة الرئيسية"];
            [coverPill addSubview:coverLabel];

            [thumbContainer addSubview:coverPill];

            [NSLayoutConstraint activateConstraints:@[
                [coverPill.leadingAnchor constraintEqualToAnchor:thumbContainer.leadingAnchor constant:6.0],
                [coverPill.bottomAnchor constraintEqualToAnchor:thumbContainer.bottomAnchor constant:-6.0],
                [coverPill.heightAnchor constraintEqualToConstant:18.0],
                [coverLabel.leadingAnchor constraintEqualToAnchor:coverPill.leadingAnchor constant:6.0],
                [coverLabel.trailingAnchor constraintEqualToAnchor:coverPill.trailingAnchor constant:-6.0],
                [coverLabel.centerYAnchor constraintEqualToAnchor:coverPill.centerYAnchor]
            ]];
        }

        UIButton *delBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        delBtn.translatesAutoresizingMaskIntoConstraints = NO;
        delBtn.tag = i;
        UIImageSymbolConfiguration *delSym = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightBold];
        UIImage *delImg = [UIImage systemImageNamed:@"xmark.circle.fill" withConfiguration:delSym];
        [delBtn setImage:delImg forState:UIControlStateNormal];
        delBtn.tintColor = [UIColor colorWithRed:0.94 green:0.27 blue:0.24 alpha:1.0];
        [delBtn addTarget:self action:@selector(pp_handleDeleteThumbnailTapped:) forControlEvents:UIControlEventTouchUpInside];
        [thumbContainer addSubview:delBtn];

        [NSLayoutConstraint activateConstraints:@[
            [delBtn.trailingAnchor constraintEqualToAnchor:thumbContainer.trailingAnchor constant:-4.0],
            [delBtn.topAnchor constraintEqualToAnchor:thumbContainer.topAnchor constant:4.0],
            [delBtn.widthAnchor constraintEqualToConstant:24.0],
            [delBtn.heightAnchor constraintEqualToConstant:24.0]
        ]];

        UITapGestureRecognizer *previewTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_handleThumbnailPreviewTapped:)];
        thumbContainer.tag = i;
        [thumbContainer addGestureRecognizer:previewTap];

        [self.studioMediaThumbnailsStack addArrangedSubview:thumbContainer];
    }
}

- (void)pp_handleAddMediaTapped {
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];
    [self.imageCollection presentPickerFromViewController:self];
}

- (void)pp_handleDeleteThumbnailTapped:(UIButton *)sender {
    NSInteger index = sender.tag;
    if (index >= 0 && index < [self.imageCollection imageCount]) {
        UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [haptic impactOccurred];
        [self.imageCollection removeImageAtIndex:index];
    }
}

- (void)pp_handleThumbnailPreviewTapped:(UITapGestureRecognizer *)tap {
    NSInteger index = tap.view.tag;
    if (index >= 0 && index < [self safeMediaOutputCount]) {
        [self openImagePreviewAtIndex:index];
    }
}

- (UIView *)pp_buildCategoryCardView {
    UIView *card = [self pp_createStudioCardContainer];
    self.studioCategoryCardView = card;

    UIView *header = [self pp_createStudioCardHeaderWithIcon:@"pawprint.fill"
                                                   iconColor:[UIColor colorWithRed:0.92 green:0.35 blue:0.05 alpha:1.0]
                                                 iconBgColor:[UIColor colorWithRed:1.0 green:0.93 blue:0.84 alpha:1.0]
                                                       title:[self pp_localizedStringForKey:@"ad_pet_type" fallback:@"تصنيف الحيوان"]
                                                    subtitle:[self pp_localizedStringForKey:@"ad_category_subtitle" fallback:@"حدد فئة وسلالة الحيوان لتسهيل الوصول إليه."]
                                                trailingView:nil];

    UIScrollView *chipsScroll = [[UIScrollView alloc] init];
    chipsScroll.translatesAutoresizingMaskIntoConstraints = NO;
    chipsScroll.showsHorizontalScrollIndicator = NO;
    chipsScroll.alwaysBounceHorizontal = YES;
    chipsScroll.semanticContentAttribute = PPAdCurrentSemanticAttribute();

    UIStackView *chipsStack = [[UIStackView alloc] init];
    chipsStack.translatesAutoresizingMaskIntoConstraints = NO;
    chipsStack.axis = UILayoutConstraintAxisHorizontal;
    chipsStack.spacing = 8.0;
    chipsStack.alignment = UIStackViewAlignmentCenter;
    chipsStack.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    self.studioSpeciesChipsStack = chipsStack;
    [chipsScroll addSubview:chipsStack];

    [NSLayoutConstraint activateConstraints:@[
        [chipsStack.topAnchor constraintEqualToAnchor:chipsScroll.contentLayoutGuide.topAnchor],
        [chipsStack.bottomAnchor constraintEqualToAnchor:chipsScroll.contentLayoutGuide.bottomAnchor],
        [chipsStack.leadingAnchor constraintEqualToAnchor:chipsScroll.contentLayoutGuide.leadingAnchor],
        [chipsStack.trailingAnchor constraintEqualToAnchor:chipsScroll.contentLayoutGuide.trailingAnchor],
        [chipsStack.heightAnchor constraintEqualToAnchor:chipsScroll.frameLayoutGuide.heightAnchor]
    ]];

    NSArray<NSDictionary *> *chipData = @[
        @{@"key": @"cat", @"title": [self pp_localizedStringForKey:@"community_species_cat" fallback:@"قطط"], @"symbol": @"cat.fill"},
        @{@"key": @"dog", @"title": [self pp_localizedStringForKey:@"community_species_dog" fallback:@"كلاب"], @"symbol": @"dog.fill"},
        @{@"key": @"bird", @"title": [self pp_localizedStringForKey:@"community_species_bird" fallback:@"طيور"], @"symbol": @"bird.fill"},
        @{@"key": @"rabbit", @"title": [self pp_localizedStringForKey:@"community_species_rabbit" fallback:@"أرانب"], @"symbol": @"hare.fill"},
        @{@"key": @"other", @"title": [self pp_localizedStringForKey:@"community_species_other" fallback:@"أخرى"], @"symbol": @"sparkles"}
    ];

    for (NSInteger i = 0; i < chipData.count; i++) {
        NSDictionary *dict = chipData[i];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        btn.layer.cornerRadius = 18.0;
        btn.layer.cornerCurve = kCACornerCurveContinuous;
        btn.layer.borderWidth = 0.8;
        btn.layer.borderColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            return tc.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithWhite:1.0 alpha:0.1]
                : [UIColor colorWithWhite:0.0 alpha:0.08];
        }].CGColor;
        btn.tag = i;

        [btn setTitle:dict[@"title"] forState:UIControlStateNormal];
        [btn setTitleColor:PPAdFormPrimaryTextColor() forState:UIControlStateNormal];
        btn.titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold];

        UIImageSymbolConfiguration *symConfig = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold];
        UIImage *symImg = [UIImage systemImageNamed:dict[@"symbol"] withConfiguration:symConfig] ?: [UIImage systemImageNamed:@"pawprint.fill" withConfiguration:symConfig];
        [btn setImage:[symImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        btn.tintColor = PPAdFormPrimaryTextColor();
        btn.contentEdgeInsets = UIEdgeInsetsMake(8, 14, 8, 14);
        btn.imageEdgeInsets = UIEdgeInsetsMake(0, Language.isRTL ? 6 : -6, 0, Language.isRTL ? -6 : 6);

        [btn addTarget:self action:@selector(pp_handleQuickSpeciesChipTapped:) forControlEvents:UIControlEventTouchUpInside];
        [chipsStack addArrangedSubview:btn];

        [NSLayoutConstraint activateConstraints:@[
            [btn.heightAnchor constraintEqualToConstant:36.0]
        ]];
    }

    UIStackView *cardStack = [[UIStackView alloc] initWithArrangedSubviews:@[header, chipsScroll, self.basicFormView]];
    cardStack.translatesAutoresizingMaskIntoConstraints = NO;
    cardStack.axis = UILayoutConstraintAxisVertical;
    cardStack.spacing = 14.0;
    [card addSubview:cardStack];

    [NSLayoutConstraint activateConstraints:@[
        [chipsScroll.heightAnchor constraintEqualToConstant:38.0],
        [cardStack.topAnchor constraintEqualToAnchor:card.topAnchor constant:16.0],
        [cardStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [cardStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [cardStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16.0]
    ]];

    [self pp_syncSpeciesChipsState];
    return card;
}

- (void)pp_syncSpeciesChipsState {
    if (!self.studioSpeciesChipsStack) return;

    NSArray<NSDictionary *> *chipData = @[
        @{@"key": @"cat", @"title": @"قطط"},
        @{@"key": @"dog", @"title": @"كلاب"},
        @{@"key": @"bird", @"title": @"طيور"},
        @{@"key": @"rabbit", @"title": @"أرانب"},
        @{@"key": @"other", @"title": @"أخرى"}
    ];

    NSString *currentName = self.selectedKind.KindName ?: @"";

    for (UIView *subview in self.studioSpeciesChipsStack.arrangedSubviews) {
        if (![subview isKindOfClass:UIButton.class]) continue;
        UIButton *btn = (UIButton *)subview;
        NSInteger idx = btn.tag;
        if (idx < 0 || idx >= chipData.count) continue;
        NSDictionary *dict = chipData[idx];

        BOOL isSelected = NO;
        if ([dict[@"key"] isEqualToString:@"other"]) {
            if (self.selectedKind) {
                BOOL matched = NO;
                for (NSInteger j = 0; j < 4; j++) {
                    if ([currentName containsString:chipData[j][@"title"]]) {
                        matched = YES;
                        break;
                    }
                }
                isSelected = !matched;
            }
        } else {
            isSelected = [currentName containsString:dict[@"title"]];
        }

        if (isSelected) {
            btn.backgroundColor = [UIColor colorWithRed:0.98 green:0.48 blue:0.18 alpha:1.0];
            [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
            btn.tintColor = UIColor.whiteColor;
            btn.layer.borderColor = UIColor.clearColor.CGColor;
        } else {
            btn.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
                return tc.userInterfaceStyle == UIUserInterfaceStyleDark
                    ? [UIColor colorWithWhite:1.0 alpha:0.06]
                    : [UIColor colorWithRed:0.96 green:0.95 blue:0.93 alpha:1.0];
            }];
            [btn setTitleColor:PPAdFormPrimaryTextColor() forState:UIControlStateNormal];
            btn.tintColor = PPAdFormPrimaryTextColor();
            btn.layer.borderColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
                return tc.userInterfaceStyle == UIUserInterfaceStyleDark
                    ? [UIColor colorWithWhite:1.0 alpha:0.1]
                    : [UIColor colorWithWhite:0.0 alpha:0.08];
            }].CGColor;
        }
    }
}

- (void)pp_handleQuickSpeciesChipTapped:(UIButton *)sender {
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];

    NSArray<NSDictionary *> *chipData = @[
        @{@"key": @"cat", @"keyword": @"قط"},
        @{@"key": @"dog", @"keyword": @"كلب"},
        @{@"key": @"bird", @"keyword": @"طير"},
        @{@"key": @"rabbit", @"keyword": @"أرنب"},
        @{@"key": @"other", @"keyword": @""}
    ];

    NSInteger idx = sender.tag;
    if (idx < 0 || idx >= chipData.count) return;
    NSDictionary *dict = chipData[idx];

    if ([dict[@"key"] isEqualToString:@"other"]) {
        PPFormFieldConfig *catConfig = [self.basicFormView configForIdentifier:kcategory];
        [self pp_presentMainCategoryPickerForConfig:catConfig];
        return;
    }
   
    NSString *keyword = dict[@"keyword"];
    MainKindsModel *matchedKind = nil;
    for (MainKindsModel *kind in MKM.MainKindsArray) {
        if ([kind.KindName containsString:keyword] || [kind.KindName containsString:dict[@"key"]]) {
            matchedKind = kind;
            break;
        }
    }

    if (matchedKind) {
        self.selectedKind = matchedKind;
        self.adModel.category = matchedKind.ID;
        self.adModel.subcategory = 0;
        [self.basicFormView setValue:matchedKind.KindName forIdentifier:kcategory];
        [self.basicFormView setValue:@"" forIdentifier:ksubcategory];

        [self.basicFormView setFieldEnabled:YES identifier:ksubcategory];

        self.hasUserModifiedForm = YES;
        [self pp_syncSpeciesChipsState];
        [self pp_updateStudioReadinessRadarAnimated:YES];
    } else {
        PPFormFieldConfig *catConfig = [self.basicFormView configForIdentifier:kcategory];
        [self pp_presentMainCategoryPickerForConfig:catConfig];
    }
}

- (UIView *)pp_buildAppearanceCardView {
    UIView *card = [self pp_createStudioCardContainer];
    self.studioAppearanceCardView = card;

    UIView *header = [self pp_createStudioCardHeaderWithIcon:@"sparkles"
                                                   iconColor:[UIColor colorWithRed:0.58 green:0.20 blue:0.92 alpha:1.0]
                                                 iconBgColor:[UIColor colorWithRed:0.95 green:0.91 blue:1.0 alpha:1.0]
                                                       title:[self pp_localizedStringForKey:@"community_appearance_title" fallback:@"الصفات الظاهرية"]
                                                    subtitle:[self pp_localizedStringForKey:@"community_appearance_message" fallback:@"أضف علامات تساعد على تمييز الحيوان."]
                                                trailingView:nil];

    UILabel *genderTitleLabel = [[UILabel alloc] init];
    genderTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    genderTitleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold];
    genderTitleLabel.textColor = PPAdFormPrimaryTextColor();
    genderTitleLabel.text = [self pp_localizedStringForKey:@"Gender" fallback:@"الجنس"];

    UIStackView *genderPillsStack = [[UIStackView alloc] init];
    genderPillsStack.translatesAutoresizingMaskIntoConstraints = NO;
    genderPillsStack.axis = UILayoutConstraintAxisHorizontal;
    genderPillsStack.distribution = UIStackViewDistributionFillEqually;
    genderPillsStack.spacing = 8.0;
    genderPillsStack.semanticContentAttribute = PPAdCurrentSemanticAttribute();

    self.studioGenderMaleButton = [self pp_createGenderButtonWithTitle:[self pp_localizedStringForKey:@"Male" fallback:@"ذكر"]
                                                                symbol:@"figure.stand"
                                                                   tag:1];
    self.studioGenderFemaleButton = [self pp_createGenderButtonWithTitle:[self pp_localizedStringForKey:@"Female" fallback:@"أنثى"]
                                                                  symbol:@"figure.stand.dress"
                                                                     tag:2];
    self.studioGenderUndefinedButton = [self pp_createGenderButtonWithTitle:[self pp_localizedStringForKey:@"no_value" fallback:@"غير محدد"]
                                                                     symbol:@"questionmark"
                                                                        tag:3];

    [genderPillsStack addArrangedSubview:self.studioGenderMaleButton];
    [genderPillsStack addArrangedSubview:self.studioGenderFemaleButton];
    [genderPillsStack addArrangedSubview:self.studioGenderUndefinedButton];

    UIStackView *cardStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        header,
        genderTitleLabel,
        genderPillsStack,
        self.petFormView
    ]];
    cardStack.translatesAutoresizingMaskIntoConstraints = NO;
    cardStack.axis = UILayoutConstraintAxisVertical;
    cardStack.spacing = 12.0;
    [card addSubview:cardStack];

    [NSLayoutConstraint activateConstraints:@[
        [genderPillsStack.heightAnchor constraintEqualToConstant:42.0],
        [cardStack.topAnchor constraintEqualToAnchor:card.topAnchor constant:16.0],
        [cardStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [cardStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [cardStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16.0]
    ]];

    [self pp_syncGenderButtonsState];
    return card;
}

- (UIButton *)pp_createGenderButtonWithTitle:(NSString *)title symbol:(NSString *)symbol tag:(NSInteger)tag {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.tag = tag;
    btn.layer.cornerRadius = 12.0;
    btn.layer.cornerCurve = kCACornerCurveContinuous;
    btn.layer.borderWidth = 0.8;

    [btn setTitle:title forState:UIControlStateNormal];
    btn.titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold];

    UIImageSymbolConfiguration *symConfig = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightBold];
    UIImage *img = [UIImage systemImageNamed:symbol withConfiguration:symConfig];
    [btn setImage:[img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    btn.imageEdgeInsets = UIEdgeInsetsMake(0, Language.isRTL ? 6 : -6, 0, Language.isRTL ? -6 : 6);

    [btn addTarget:self action:@selector(pp_handleGenderButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)pp_syncGenderButtonsState {
    NSString *gender = self.adModel.gender;
    BOOL isMale = [gender isEqualToString:PPAdGenderValueMale];
    BOOL isFemale = [gender isEqualToString:PPAdGenderValueFemale];
    BOOL isUndefined = [gender isEqualToString:PPAdGenderValueUndefined] || (!isMale && !isFemale);

    UIColor *neutralBg = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.06]
            : [UIColor colorWithRed:0.96 green:0.95 blue:0.93 alpha:1.0];
    }];
    UIColor *neutralBorder = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.1]
            : [UIColor colorWithWhite:0.0 alpha:0.08];
    }];

    // Male button (tag 1)
    if (isMale) {
        self.studioGenderMaleButton.backgroundColor = [UIColor colorWithRed:0.23 green:0.51 blue:0.96 alpha:1.0];
        [self.studioGenderMaleButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        self.studioGenderMaleButton.tintColor = UIColor.whiteColor;
        self.studioGenderMaleButton.layer.borderColor = UIColor.clearColor.CGColor;
    } else {
        self.studioGenderMaleButton.backgroundColor = neutralBg;
        [self.studioGenderMaleButton setTitleColor:PPAdFormPrimaryTextColor() forState:UIControlStateNormal];
        self.studioGenderMaleButton.tintColor = PPAdFormPrimaryTextColor();
        self.studioGenderMaleButton.layer.borderColor = neutralBorder.CGColor;
    }

    // Female button (tag 2)
    if (isFemale) {
        self.studioGenderFemaleButton.backgroundColor = [UIColor colorWithRed:0.93 green:0.28 blue:0.60 alpha:1.0];
        [self.studioGenderFemaleButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        self.studioGenderFemaleButton.tintColor = UIColor.whiteColor;
        self.studioGenderFemaleButton.layer.borderColor = UIColor.clearColor.CGColor;
    } else {
        self.studioGenderFemaleButton.backgroundColor = neutralBg;
        [self.studioGenderFemaleButton setTitleColor:PPAdFormPrimaryTextColor() forState:UIControlStateNormal];
        self.studioGenderFemaleButton.tintColor = PPAdFormPrimaryTextColor();
        self.studioGenderFemaleButton.layer.borderColor = neutralBorder.CGColor;
    }

    // Undefined button (tag 3)
    if (isUndefined) {
        self.studioGenderUndefinedButton.backgroundColor = [UIColor colorWithRed:0.42 green:0.45 blue:0.50 alpha:1.0];
        [self.studioGenderUndefinedButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        self.studioGenderUndefinedButton.tintColor = UIColor.whiteColor;
        self.studioGenderUndefinedButton.layer.borderColor = UIColor.clearColor.CGColor;
    } else {
        self.studioGenderUndefinedButton.backgroundColor = neutralBg;
        [self.studioGenderUndefinedButton setTitleColor:PPAdFormPrimaryTextColor() forState:UIControlStateNormal];
        self.studioGenderUndefinedButton.tintColor = PPAdFormPrimaryTextColor();
        self.studioGenderUndefinedButton.layer.borderColor = neutralBorder.CGColor;
    }
}

- (void)pp_handleGenderButtonTapped:(UIButton *)sender {
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];

    if (sender == self.studioGenderMaleButton) {
        [self pp_applyGenderSelectionToAdModel:PPAdGenderValueMale];
    } else if (sender == self.studioGenderFemaleButton) {
        [self pp_applyGenderSelectionToAdModel:PPAdGenderValueFemale];
    } else {
        [self pp_applyGenderSelectionToAdModel:PPAdGenderValueUndefined];
    }

    self.hasUserModifiedForm = YES;
    [self pp_syncGenderButtonsState];
    [self pp_updateStudioReadinessRadarAnimated:YES];
}

- (UIView *)pp_buildListingCardView {
    UIView *card = [self pp_createStudioCardContainer];
    self.studioListingCardView = card;

    UIView *header = [self pp_createStudioCardHeaderWithIcon:@"tag.fill"
                                                   iconColor:[UIColor colorWithRed:0.01 green:0.52 blue:0.78 alpha:1.0]
                                                 iconBgColor:[UIColor colorWithRed:0.88 green:0.95 blue:1.0 alpha:1.0]
                                                       title:[self pp_localizedStringForKey:@"ad_offer_details_title" fallback:@"تفاصيل العرض والموقع"]
                                                    subtitle:[self pp_localizedStringForKey:@"ad_offer_details_subtitle" fallback:@"حدد عنوان الإعلان والسعر وموقع المعاينة."]
                                                trailingView:nil];

    UIStackView *cardStack = [[UIStackView alloc] initWithArrangedSubviews:@[header, self.listingFormView]];
    cardStack.translatesAutoresizingMaskIntoConstraints = NO;
    cardStack.axis = UILayoutConstraintAxisVertical;
    cardStack.spacing = 14.0;
    [card addSubview:cardStack];

    [NSLayoutConstraint activateConstraints:@[
        [cardStack.topAnchor constraintEqualToAnchor:card.topAnchor constant:16.0],
        [cardStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [cardStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [cardStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16.0]
    ]];

    return card;
}

- (void)pp_setupFloatingActionDock {
    if (self.studioFloatingDockView) return;

    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:blurView];
    self.studioFloatingDockView = blurView;

    UIView *topLine = [[UIView alloc] init];
    topLine.translatesAutoresizingMaskIntoConstraints = NO;
    topLine.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:1.0 alpha:0.1] : [UIColor colorWithWhite:0.0 alpha:0.06];
    }];
    [blurView.contentView addSubview:topLine];

    UIView *guidancePill = [[UIView alloc] init];
    guidancePill.translatesAutoresizingMaskIntoConstraints = NO;
    guidancePill.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.2 alpha:0.85] : UIColor.whiteColor;
    }];
    guidancePill.layer.cornerRadius = 14.0;
    guidancePill.layer.shadowColor = UIColor.blackColor.CGColor;
    guidancePill.layer.shadowOpacity = 0.05;
    guidancePill.layer.shadowRadius = 4.0;
    guidancePill.layer.shadowOffset = CGSizeMake(0.0, 2.0);
    self.studioDockGuidancePill = guidancePill;

    UIImageView *guidanceIcon = [[UIImageView alloc] init];
    guidanceIcon.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *infoConfig = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightMedium];
    guidanceIcon.image = [UIImage systemImageNamed:@"exclamationmark.circle" withConfiguration:infoConfig];
    guidanceIcon.tintColor = UIColor.secondaryLabelColor;

    UILabel *guidanceLabel = [[UILabel alloc] init];
    guidanceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    guidanceLabel.font = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    guidanceLabel.textColor = UIColor.secondaryLabelColor;
    self.studioDockGuidanceLabel = guidanceLabel;

    UIStackView *guidanceStack = [[UIStackView alloc] initWithArrangedSubviews:@[guidanceIcon, guidanceLabel]];
    guidanceStack.translatesAutoresizingMaskIntoConstraints = NO;
    guidanceStack.axis = UILayoutConstraintAxisHorizontal;
    guidanceStack.spacing = 6.0;
    guidanceStack.alignment = UIStackViewAlignmentCenter;
    [guidancePill addSubview:guidanceStack];

    UIButton *heroBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    heroBtn.translatesAutoresizingMaskIntoConstraints = NO;
    heroBtn.layer.cornerRadius = 18.0;
    heroBtn.layer.masksToBounds = YES;
    heroBtn.layer.shadowColor = [UIColor colorWithRed:0.98 green:0.45 blue:0.25 alpha:0.35].CGColor;
    heroBtn.layer.shadowOpacity = 0.35;
    heroBtn.layer.shadowRadius = 12.0;
    heroBtn.layer.shadowOffset = CGSizeMake(0.0, 5.0);

    CAGradientLayer *btnGrad = [CAGradientLayer layer];
    btnGrad.colors = @[
        (id)[UIColor colorWithRed:1.0 green:0.48 blue:0.27 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.96 green:0.33 blue:0.22 alpha:1.0].CGColor
    ];
    btnGrad.startPoint = CGPointMake(0.0, 0.5);
    btnGrad.endPoint = CGPointMake(1.0, 0.5);
    [heroBtn.layer insertSublayer:btnGrad atIndex:0];
    self.studioDockHeroGradient = btnGrad;

    NSString *heroTitle = (self.mode == AdEditorModeEdit)
        ? ([self pp_localizedStringForKey:@"Save" fallback:@"حفظ التعديلات"])
        : [self pp_localizedStringForKey:@"ad_publish_instant_match" fallback:@"نشر الإعلان والمطابقة الفورية"];
    [heroBtn setTitle:heroTitle forState:UIControlStateNormal];
    [heroBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    heroBtn.titleLabel.font = [GM boldFontWithSize:17.0] ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightBold];

    UIImageSymbolConfiguration *planeConfig = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightBold];
    NSString *symbolName = (self.mode == AdEditorModeEdit) ? @"checkmark" : @"paperplane.fill";
    [heroBtn setImage:[UIImage systemImageNamed:symbolName withConfiguration:planeConfig] forState:UIControlStateNormal];
    heroBtn.tintColor = UIColor.whiteColor;
    heroBtn.imageEdgeInsets = UIEdgeInsetsMake(0, Language.isRTL ? 8 : -8, 0, Language.isRTL ? -8 : 8);

    [heroBtn addTarget:self action:@selector(saveFormData:) forControlEvents:UIControlEventTouchUpInside];
    self.studioDockHeroButton = heroBtn;

    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    spinner.color = UIColor.whiteColor;
    spinner.hidesWhenStopped = YES;
    [heroBtn addSubview:spinner];
    self.studioDockSpinner = spinner;

    UIStackView *dockStack = [[UIStackView alloc] initWithArrangedSubviews:@[guidancePill, heroBtn]];
    dockStack.translatesAutoresizingMaskIntoConstraints = NO;
    dockStack.axis = UILayoutConstraintAxisVertical;
    dockStack.alignment = UIStackViewAlignmentCenter;
    dockStack.spacing = 8.0;
    [blurView.contentView addSubview:dockStack];

    [NSLayoutConstraint activateConstraints:@[
        [blurView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [topLine.topAnchor constraintEqualToAnchor:blurView.contentView.topAnchor],
        [topLine.leadingAnchor constraintEqualToAnchor:blurView.contentView.leadingAnchor],
        [topLine.trailingAnchor constraintEqualToAnchor:blurView.contentView.trailingAnchor],
        [topLine.heightAnchor constraintEqualToConstant:0.8],

        [dockStack.topAnchor constraintEqualToAnchor:blurView.contentView.topAnchor constant:12.0],
        [dockStack.leadingAnchor constraintEqualToAnchor:blurView.contentView.leadingAnchor constant:20.0],
        [dockStack.trailingAnchor constraintEqualToAnchor:blurView.contentView.trailingAnchor constant:-20.0],
        [dockStack.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12.0],

        [guidancePill.heightAnchor constraintEqualToConstant:28.0],
        [guidanceStack.leadingAnchor constraintEqualToAnchor:guidancePill.leadingAnchor constant:12.0],
        [guidanceStack.trailingAnchor constraintEqualToAnchor:guidancePill.trailingAnchor constant:-12.0],
        [guidanceStack.centerYAnchor constraintEqualToAnchor:guidancePill.centerYAnchor],

        [heroBtn.widthAnchor constraintEqualToAnchor:dockStack.widthAnchor],
        [heroBtn.heightAnchor constraintEqualToConstant:54.0],

        [spinner.centerYAnchor constraintEqualToAnchor:heroBtn.centerYAnchor],
        [spinner.trailingAnchor constraintEqualToAnchor:heroBtn.trailingAnchor constant:-20.0]
    ]];
}

- (NSInteger)pp_calculateReadinessPercentage {
    NSInteger score = 0;

    // Photos: 30%
    if ([self safeMediaOutputCount] > 0) {
        score += 30;
    }

    // Title: 15%
    if (self.adModel.adTitle.length > 0) {
        score += 15;
    }

    // Category / Species: 15%
    if (self.selectedKind != nil || self.adModel.category > 0) {
        score += 15;
    }

    // Breed / Subcategory: 10%
    if (self.adModel.subcategory > 0) {
        score += 10;
    }

    // Gender: 10%
    if (self.adModel.gender.length > 0 && ![self.adModel.gender isEqualToString:PPAdGenderValueUndefined]) {
        score += 10;
    }

    // Age: 5%
    if (self.adModel.petAgeMonths != nil && self.adModel.petAgeMonths.integerValue > 0) {
        score += 5;
    }

    // Price: 5%
    if (self.adModel.price != nil) {
        score += 5;
    }

    // Location: 5%
    if (self.hasSelectedAdCoordinate || self.selectedAdLocationName.length > 0) {
        score += 5;
    }

    // Description: 5%
    if (self.adModel.adDescription.length > 0) {
        score += 5;
    }

    return MIN(100, MAX(0, score));
}

- (NSString *)pp_currentReadinessAdvice {
    if ([self safeMediaOutputCount] == 0) {
        return [self pp_localizedStringForKey:@"ad_advice_add_photo"
                                      fallback:@"أضف صورة للحيوان لرفع دقة وجودة الإعلان"];
    }
    if (self.adModel.adTitle.length == 0) {
        return [self pp_localizedStringForKey:@"ad_advice_enter_title"
                                      fallback:@"أدخل عنواناً واضحاً للإعلان لجذب المشترين"];
    }
    if (!self.selectedKind && self.adModel.category == 0) {
        return [self pp_localizedStringForKey:@"ad_advice_select_category"
                                      fallback:@"حدد فئة ونوع الحيوان"];
    }
    if (self.adModel.subcategory == 0) {
        return [self pp_localizedStringForKey:@"ad_advice_select_breed"
                                      fallback:@"اختر سلالة الحيوان لتسهيل البحث"];
    }
    if (self.adModel.gender.length == 0 || [self.adModel.gender isEqualToString:PPAdGenderValueUndefined]) {
        return [self pp_localizedStringForKey:@"ad_advice_select_gender"
                                      fallback:@"حدد جنس الحيوان (ذكر أو أنثى)"];
    }
    if (self.adModel.price == nil) {
        return [self pp_localizedStringForKey:@"ad_advice_enter_price"
                                      fallback:@"حدد سعر الحيوان أو ضعه 0 للتبني"];
    }
    if (!self.hasSelectedAdCoordinate && self.selectedAdLocationName.length == 0) {
        return [self pp_localizedStringForKey:@"ad_advice_select_location"
                                      fallback:@"حدد موقع الإعلان على الخريطة"];
    }
    if (self.adModel.petAgeMonths == nil) {
        return [self pp_localizedStringForKey:@"ad_advice_enter_age"
                                      fallback:@"أدخل عمر الحيوان بالأشهر"];
    }
    if (self.adModel.adDescription.length == 0) {
        return [self pp_localizedStringForKey:@"ad_advice_enter_description"
                                      fallback:@"أضف وصفاً مختصراً يوضح حالة ومميزات الحيوان"];
    }
    return [self pp_localizedStringForKey:@"ad_advice_complete"
                                 fallback:@"الإعلان مكتمل وجاهز للمطابقة الفورية بنسبة 100% ✨"];
}

- (void)pp_updateStudioReadinessRadarAnimated:(BOOL)animated {
    if (!self.studioRadarRingView) return;

    NSInteger pct = [self pp_calculateReadinessPercentage];
    [self.studioRadarRingView setProgress:((CGFloat)pct / 100.0) animated:animated];

    if (pct >= 100) {
        self.studioRadarCompleteBadge.hidden = NO;
        self.studioRadarAdviceLabel.text = [self pp_localizedStringForKey:@"ad_advice_complete" fallback:@"الإعلان مكتمل وجاهز للمطابقة الفورية بنسبة 100% ✨"];
        self.studioRadarAdviceLabel.textColor = [UIColor colorWithRed:0.06 green:0.73 blue:0.51 alpha:1.0];

        if (self.studioDockGuidanceLabel) {
            self.studioDockGuidanceLabel.text = [self pp_localizedStringForKey:@"ad_ready_for_publish" fallback:@"✨ الإعلان مكتمل وجاهز للمطابقة الفورية"];
            self.studioDockGuidanceLabel.textColor = [UIColor colorWithRed:0.06 green:0.73 blue:0.51 alpha:1.0];
        }
    } else {
        self.studioRadarCompleteBadge.hidden = YES;
        NSString *advice = [self pp_currentReadinessAdvice];
        self.studioRadarAdviceLabel.text = advice;
        self.studioRadarAdviceLabel.textColor = UIColor.secondaryLabelColor;

        if (self.studioDockGuidanceLabel) {
            self.studioDockGuidanceLabel.text = advice;
            self.studioDockGuidanceLabel.textColor = UIColor.secondaryLabelColor;
        }
    }
}

- (void)pp_rebuildFormFields {
    if (!self.contentStack) return;

    for (UIView *v in self.contentStack.arrangedSubviews) {
        [v removeFromSuperview];
    }

    __weak typeof(self) weakSelf = self;
    PPFormStyle *style = [self pp_adFormStyle];

    // Build Form Views
    self.basicFormView = [[PPFormEngineView alloc] initWithStyle:style];
    self.petFormView = [[PPFormEngineView alloc] initWithStyle:style];
    self.listingFormView = [[PPFormEngineView alloc] initWithStyle:style];

    // 1. Basic fields (category & subcategory)
    PPFormFieldConfig *catField = [PPFormFieldConfig fieldWithIdentifier:kcategory
                                                                  title:[self pp_localizedStringForKey:@"Species" fallback:@"الفئة"]
                                                            placeholder:[self pp_localizedStringForKey:@"ad_select_category" fallback:@"اختر الفئة"]
                                                              inputType:PPFormInputTypePicker];
    catField.required = YES;
    catField.pickerTapBlock = ^(PPFormFieldConfig *config, PPFormFieldRowView *row) {
        [weakSelf pp_presentMainCategoryPickerForConfig:config];
    };

    PPFormFieldConfig *subField = [PPFormFieldConfig fieldWithIdentifier:ksubcategory
                                                                  title:[self pp_localizedStringForKey:@"Breed" fallback:@"السلالة"]
                                                            placeholder:[self pp_localizedStringForKey:@"ad_select_breed" fallback:@"اختر السلالة"]
                                                              inputType:PPFormInputTypePicker];
    subField.required = YES;
    subField.pickerTapBlock = ^(PPFormFieldConfig *config, PPFormFieldRowView *row) {
        [weakSelf pp_presentSubCategoryPickerForConfig:config];
    };

    if (self.selectedMainKind) {
        weakSelf.selectedKind = self.selectedMainKind;
        weakSelf.adModel.category = self.selectedMainKind.ID;
        catField.value = self.selectedMainKind.KindName;
        catField.enabled = NO;
        subField.enabled = YES;
    } else if (self.selectedKind) {
        catField.value = self.selectedKind.KindName;
        subField.enabled = YES;
    } else {
        subField.enabled = NO;
    }

    if (self.adModel.subcategory > 0 && self.selectedKind) {
        SubKindModel *sub = [self.selectedKind subKindForID:self.adModel.subcategory];
        if (!sub) {
            for (SubKindModel *s in self.selectedKind.SubKindsArray) {
                if (s.ID == self.adModel.subcategory) { sub = s; break; }
            }
        }
        if (sub) {
            subField.value = sub.SubKindName;
        }
    }

    [self.basicFormView setFields:@[catField, subField]];

    // 2. Pet detail fields (age)
    PPFormFieldConfig *ageField = [PPFormFieldConfig fieldWithIdentifier:kpetAge
                                                                   title:[self pp_localizedStringForKey:@"age_months" fallback:@"العمر (بالأشهر)"]
                                                             placeholder:[self pp_localizedStringForKey:@"enter_pet_age_in_months" fallback:@"أدخل عمر الحيوان بالأشهر"]
                                                               inputType:PPFormInputTypeNumber];
    ageField.required = YES;
    ageField.textChangeBlock = ^(PPFormFieldConfig *config, NSString *value) {
        weakSelf.adModel.petAgeMonths = value.length > 0 ? @(value.integerValue) : nil;
        if (!weakSelf.isHydratingFormData) weakSelf.hasUserModifiedForm = YES;
        [weakSelf pp_updateStudioReadinessRadarAnimated:YES];
    };
    if (self.adModel.petAgeMonths) {
        ageField.value = [NSString stringWithFormat:@"%@", self.adModel.petAgeMonths];
    }
    [self.petFormView setFields:@[ageField]];

    // 3. Listing detail fields (title, price, location, desc)
    PPFormFieldConfig *titleField = [PPFormFieldConfig fieldWithIdentifier:@"adTitle"
                                                                    title:[self pp_localizedStringForKey:@"adTitle" fallback:@"عنوان او اسم الإعلان"]
                                                              placeholder:[self pp_localizedStringForKey:@"enter_title" fallback:@"أدخل عنواناً جذاباً ومختصراً"]
                                                                inputType:PPFormInputTypeText];
    titleField.required = YES;
    titleField.textChangeBlock = ^(PPFormFieldConfig *config, NSString *value) {
        weakSelf.adModel.adTitle = value;
        if (!weakSelf.isHydratingFormData) weakSelf.hasUserModifiedForm = YES;
        [weakSelf pp_updateStudioReadinessRadarAnimated:YES];
    };
    if (self.adModel.adTitle.length > 0) {
        titleField.value = self.adModel.adTitle;
    }

    PPFormFieldConfig *priceField = [PPFormFieldConfig fieldWithIdentifier:kprice
                                                                    title:[self pp_localizedStringForKey:@"price" fallback:@"السعر (ر.ق)"]
                                                              placeholder:[self pp_localizedStringForKey:@"enter_price" fallback:@"0"]
                                                                inputType:PPFormInputTypeNumber];
    priceField.keyboardType = UIKeyboardTypeDecimalPad;
    priceField.required = YES;
    priceField.textChangeBlock = ^(PPFormFieldConfig *config, NSString *value) {
        weakSelf.adModel.price = [GM moneyNumberFromInput:value];
        if (!weakSelf.isHydratingFormData) weakSelf.hasUserModifiedForm = YES;
        [weakSelf pp_updateStudioReadinessRadarAnimated:YES];
    };
    if (self.adModel.price) {
        priceField.value = [NSString stringWithFormat:@"%@", self.adModel.price];
    }

    PPFormFieldConfig *locationField = [PPFormFieldConfig fieldWithIdentifier:kadLocation
                                                                        title:[self pp_localizedStringForKey:@"adLocation" fallback:@"موقع الإعلان"]
                                                                  placeholder:[self pp_localizedStringForKey:@"select_location" fallback:@"حدد الموقع على الخريطة"]
                                                                    inputType:PPFormInputTypePicker];
    locationField.required = YES;
    locationField.pickerTapBlock = ^(PPFormFieldConfig *config, PPFormFieldRowView *row) {
        [weakSelf pp_presentAdLocationPicker];
    };
    if (self.selectedAdLocationName.length > 0) {
        locationField.value = self.selectedAdLocationName;
    }

    PPFormFieldConfig *descField = [PPFormFieldConfig fieldWithIdentifier:kdesc
                                                                   title:[self pp_localizedStringForKey:@"ad_description_title" fallback:@"تفاصيل ووصف الإعلان"]
                                                             placeholder:[self pp_localizedStringForKey:@"ad_description_placeholder" fallback:@"اكتب تفاصيل واضحة عن الحيوان، حالته الصحية، والتطعيمات..."]
                                                               inputType:PPFormInputTypeTextView];
    descField.required = YES;
    descField.textChangeBlock = ^(PPFormFieldConfig *config, NSString *value) {
        weakSelf.adModel.adDescription = value;
        if (!weakSelf.isHydratingFormData) weakSelf.hasUserModifiedForm = YES;
        [weakSelf pp_updateStudioReadinessRadarAnimated:YES];
    };
    if (self.adModel.adDescription.length > 0) {
        descField.value = self.adModel.adDescription;
    }

    [self.listingFormView setFields:@[titleField, priceField, locationField, descField]];

    // Assemble Studio Cards into Content Stack
    [self.contentStack addArrangedSubview:[self pp_buildApexHeaderView]];
    [self.contentStack addArrangedSubview:[self pp_buildRadarCardView]];
    [self.contentStack addArrangedSubview:[self pp_buildMediaStudioCardView]];
    [self.contentStack addArrangedSubview:[self pp_buildCategoryCardView]];
    [self.contentStack addArrangedSubview:[self pp_buildAppearanceCardView]];
    [self.contentStack addArrangedSubview:[self pp_buildListingCardView]];

    UIView *bottomSpacer = [[UIView alloc] init];
    bottomSpacer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentStack addArrangedSubview:bottomSpacer];
    [NSLayoutConstraint activateConstraints:@[
        [bottomSpacer.heightAnchor constraintEqualToConstant:10.0]
    ]];

    [self pp_updateStudioReadinessRadarAnimated:NO];
}

#pragma mark - Prefill when Editing

- (void)configureForEditingIfNeeded {
    if (self.mode != AdEditorModeEdit || !self.editingAd) return;

    self.adModel =
    [[PetAd alloc] initWithDictionary:[self.editingAd toFirestoreDictionary]
                            documentID:self.editingAd.adID];
    self.adModel.adID = self.editingAd.adID;
    self.adModel.ownerID = self.editingAd.ownerID;
    self.adModel.postedDate = self.editingAd.postedDate;

    if (self.adModel.status == 0) {
        self.adModel.status = self.editingAd.status;
    }

    MainKindsModel *kind = [MKM mainKindForID:self.adModel.category];
    if (kind) {
        self.selectedKind = kind;
    }

    NSString *prefillLocation = self.adModel.locationName;
    if (prefillLocation.length == 0 && self.adModel.adLocation > 0) {
        prefillLocation = [CitiesManager.shared cityNameForID:self.adModel.adLocation];
    }
    self.selectedAdLocationName = prefillLocation;
    self.selectedAdCoordinate = CLLocationCoordinate2DMake(self.adModel.latitude, self.adModel.longitude);
    self.hasSelectedAdCoordinate = PPIsValidAdCoordinate(self.selectedAdCoordinate);

    [self pp_rebuildFormFields];
    [self pp_syncSpeciesChipsState];
    [self pp_syncGenderButtonsState];
    [self pp_refreshStudioMediaThumbnails];
    [self pp_updateStudioReadinessRadarAnimated:NO];

    self.didMutateMediaAfterPrefill = NO;
    [self pp_setSubmitEnabled:NO];
    [self prefillPhotosForEdit];
}

- (void)showPopupPreview:(UIImage *)image {
}

#pragma mark - Search Metadata

- (void)prepareSearchMetadataForAd:(PetAd *)ad {
    ad.name_lowercase = ad.adTitle.lowercaseString ?: @"";
    NSMutableSet *keys = [NSMutableSet set];

    if (ad.adTitle.length) {
        [[ad.adTitle.lowercaseString componentsSeparatedByCharactersInSet:
          NSCharacterSet.whitespaceAndNewlineCharacterSet]
         enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
            if (obj.length > 1) [keys addObject:obj];
        }];
    }

    SubKindModel *subKind = [self.selectedKind subKindForID:self.adModel.subcategory];
    if (subKind.SubKindName.length) {
        NSString *sub = [subKind.SubKindName lowercaseString];
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
    self.scrollView.backgroundColor = UIColor.clearColor;
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

    self.scrollView.alpha = 1;

    if (self.backgroundGlowViewTop.layer.sublayers.firstObject) {
        self.backgroundGlowViewTop.layer.sublayers.firstObject.frame = self.backgroundGlowViewTop.bounds;
    }
    if (self.studioDockHeroGradient && self.studioDockHeroButton) {
        self.studioDockHeroGradient.frame = self.studioDockHeroButton.bounds;
    }
    if (self.studioFloatingDockView) {
        [self.view bringSubviewToFront:self.studioFloatingDockView];
    }
    if (self.uploadProgressOverlay) {
        [self.view bringSubviewToFront:self.uploadProgressOverlay];
    }
}

- (void)pp_updateFormHeroHeaderLayoutIfNeeded
{
    if (!self.formHeroContainerView) {
        return;
    }

    CGFloat fullWidth = CGRectGetWidth(self.scrollView.bounds);
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
        // Hero is now managed by contentStack in pp_rebuildFormFields
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

    BOOL basicValid = [self.basicFormView validate];
    BOOL petValid = [self.petFormView validate];
    BOOL listingValid = [self.listingFormView validate];
    if (!(basicValid && petValid && listingValid)) {
        [self highlightErrors:@[]];
        return;
    }

    // 1b – Custom field-level validation
    NSString *priceVal = [self.listingFormView valueForIdentifier:kprice];
    NSString *ageVal = [self.petFormView valueForIdentifier:kpetAge];

    NSNumber *validatedPrice = [GM moneyNumberFromInput:priceVal];
    if (priceVal.length > 0 && (!validatedPrice || validatedPrice.doubleValue <= 0.0)) {
        NSString *title = [self pp_localizedStringForKey:@"error" fallback:@"Error"];
        NSString *subtitle = [self pp_localizedStringForKey:@"validation_price_invalid"
                                                    fallback:@"Please enter a valid price greater than zero."];
        PPFormFieldRowView *priceRow = [self.listingFormView rowForIdentifier:kprice];
        [self pp_animateInvalidFormRow:priceRow];
        [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
        return;
    }

    if (ageVal.length > 0 && ageVal.integerValue <= 0) {
        NSString *title = [self pp_localizedStringForKey:@"error" fallback:@"Error"];
        NSString *subtitle = [self pp_localizedStringForKey:@"validation_age_invalid"
                                                    fallback:@"Please enter a valid age in months."];
        PPFormFieldRowView *ageRow = [self.petFormView rowForIdentifier:kpetAge];
        [self pp_animateInvalidFormRow:ageRow];
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

    [self pp_applyGenderSelectionToAdModel:[self fieldForTag:@"isFemale"].value];
    
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
    // Use PPFormEngineView validation highlighting
    [self.basicFormView validate];
    [self.petFormView validate];
    [self.listingFormView validate];
    NSString *title = [self pp_localizedStringForKey:@"error" fallback:@"Error"];
    NSString *subtitle = [self pp_localizedStringForKey:@"validation_fill_required"
                                                fallback:@"Please fill in all required fields."];
    [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
}

- (void)pp_animateInvalidFormRow:(PPFormFieldRowView *)row
{
    if (!row) return;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        row.alpha = 0.72;
        [UIView animateWithDuration:0.18 animations:^{
            row.alpha = 1.0;
        }];
        return;
    }

    CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    shake.values = @[@0, @-8, @7, @-5, @4, @0];
    shake.duration = 0.32;
    shake.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [row.layer addAnimation:shake forKey:@"pp.invalidFieldShake"];
}

- (BOOL)pp_validateAdLocationBeforeSubmit
{
    if (!self.hasSelectedAdCoordinate || !PPIsValidAdCoordinate(self.selectedAdCoordinate)) {
        NSString *title = [self pp_localizedStringForKey:@"Location" fallback:@"الموقع"];
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
        self.scrollView.userInteractionEnabled = NO;
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

        if ([self.imageCollection hasSelectedVideos]) {
            [self pp_uploadReusableMediaForAd:self.adModel
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
    
    NSArray *originalMediaMetadata = [self.editingAd.imageItemsRaw isKindOfClass:NSArray.class] ? self.editingAd.imageItemsRaw : @[];
    if (originalMediaMetadata.count == 0 && self.editingAd.imageItems.count > 0) {
        NSMutableArray<NSDictionary *> *legacyItems = [NSMutableArray arrayWithCapacity:self.editingAd.imageItems.count];
        for (PetImageItem *item in self.editingAd.imageItems) {
            NSDictionary *dict = [item toDictionary];
            if (dict) {
                [legacyItems addObject:dict];
            }
        }
        originalMediaMetadata = legacyItems.copy;
    }
    
    
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
        self.adModel.imageItemsRaw = originalMediaMetadata;
        performUpdate();
        return;
    }
    
    
    if ([self.imageCollection hasSelectedVideos]) {
        [self pp_uploadReusableMediaForAd:self.adModel
                               completion:^(PetAd *updatedAd, NSError *error)
        {
            if (error) {
                NSLog(@"❌ [UpdateAd] Media upload failed: %@", error);
                [self pp_handleSubmitFailure:error];
                return;
            }

            self.adModel = updatedAd;
            self.didMutateMediaAfterPrefill = NO;
            performUpdate();
        }];
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

- (void)pp_uploadReusableMediaForAd:(PetAd *)ad
                         completion:(void (^)(PetAd *updatedAd, NSError * _Nullable error))completion
{
    if (!ad || ad.adID.length == 0) {
        if (completion) {
            completion(ad, [self pp_uploadErrorWithCode:406 description:@"Missing adID before media upload."]);
        }
        return;
    }

    NSString *ownerID = [self pp_submitOwnerID];
    __weak typeof(self) weakSelf = self;
    [self.imageCollection uploadSelectedMediaWithStorageFolder:@"ads"
                                                       ownerID:ownerID
                                                     contextID:ad.adID
                                                    completion:^(PPMediaUploadResult * _Nullable result, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        if (error || !result) {
            if (completion) {
                completion(ad, error ?: [self pp_uploadErrorWithCode:407
                                                          description:[self pp_localizedStringForKey:@"media_upload_failed_message"
                                                                                            fallback:@"Media upload failed. Please try again."]]);
            }
            return;
        }

        ad.imageItemsRaw = result.mixedMetadata ?: @[];
        if (completion) {
            completion(ad, nil);
        }
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
        self.scrollView.userInteractionEnabled = YES;
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
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    [self pp_setPremiumTabDockHidden:YES animated:animated];
    self.view.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    self.scrollView.semanticContentAttribute = PPAdCurrentSemanticAttribute();
    [self pp_refreshMediaLocalizedText];
    
    if(!self.presented)
    {
         self.presented=YES;
    }

    [self pp_refreshStudioMediaThumbnails];
    [self pp_syncSpeciesChipsState];
    [self pp_syncGenderButtonsState];
    [self pp_updateStudioReadinessRadarAnimated:NO];
    [self pp_setSubmitEnabled:!self.isSubmittingAd && !self.isPrefillInProgress];
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
    NSString *buttonTitle = (self.mode == AdEditorModeEdit)
        ? [self pp_localizedStringForKey:@"saveChanges" fallback:@"حفظ التعديلات"]
        : [self pp_localizedStringForKey:@"postAd" fallback:@"نشر الإعلان"];

    // Executive Pill Publish Button
    UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
    config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    config.baseBackgroundColor = PPAdFormAccentColor();
    config.baseForegroundColor = UIColor.whiteColor;
    config.contentInsets = NSDirectionalEdgeInsetsMake(7.0, 16.0, 7.0, 16.0);

    NSDictionary *attributes = @{
        NSFontAttributeName: [GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightBold]
    };
    config.attributedTitle = [[NSAttributedString alloc] initWithString:buttonTitle attributes:attributes];

    UIButton *savBtn = [UIButton buttonWithConfiguration:config primaryAction:nil];
    savBtn.translatesAutoresizingMaskIntoConstraints = NO;
    savBtn.layer.shadowColor = PPAdFormAccentColor().CGColor;
    savBtn.layer.shadowOpacity = 0.28;
    savBtn.layer.shadowRadius = 8.0;
    savBtn.layer.shadowOffset = CGSizeMake(0.0, 3.0);
    [savBtn addTarget:self action:@selector(saveFormData:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:savBtn];

    // Refined Frosted Circular Back Button
    UIButtonConfiguration *backConfig = [UIButtonConfiguration plainButtonConfiguration];
    backConfig.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    UIImageSymbolConfiguration *chevronSym = [UIImageSymbolConfiguration configurationWithPointSize:13.5 weight:UIImageSymbolWeightSemibold];
    backConfig.image = [UIImage systemImageNamed:PPChevronName withConfiguration:chevronSym];
    backConfig.baseForegroundColor = PPAdFormPrimaryTextColor();
    backConfig.contentInsets = NSDirectionalEdgeInsetsZero;

    UIButton *backButton = [UIButton buttonWithConfiguration:backConfig primaryAction:nil];
    backButton.translatesAutoresizingMaskIntoConstraints = NO;
    backButton.layer.cornerRadius = 18.0;
    if (@available(iOS 13.0, *)) backButton.layer.cornerCurve = kCACornerCurveContinuous;
    backButton.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.12]
            : [UIColor colorWithWhite:1.0 alpha:0.90];
    }];
    backButton.layer.borderWidth = 0.75;
    backButton.layer.borderColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.08]
            : [UIColor colorWithWhite:0.0 alpha:0.06];
    }].CGColor;
    backButton.layer.shadowColor = UIColor.blackColor.CGColor;
    backButton.layer.shadowOpacity = 0.04;
    backButton.layer.shadowRadius = 5.0;
    backButton.layer.shadowOffset = CGSizeMake(0.0, 1.5);
    [backButton addTarget:self action:@selector(onBack:) forControlEvents:UIControlEventTouchUpInside];

    [NSLayoutConstraint activateConstraints:@[
        [backButton.widthAnchor constraintEqualToConstant:36.0],
        [backButton.heightAnchor constraintEqualToConstant:36.0]
    ]];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
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

    [self pp_refreshStudioMediaThumbnails];
    [self pp_updateStudioReadinessRadarAnimated:YES];
    [self pp_refreshFormHeroContent];
}


@end
