//
//  PPPaymentFormViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/11/2025.
//  Refactored: Removed XLForm, pure UIKit + modern design.
//

#import "PPPaymentFormViewController.h"

static CGFloat const kPPFieldHeight      = 70.0;
static CGFloat const kPPOptionHeight     = 64.0;
static CGFloat const kPPCornerRadius     = 16.0;
static CGFloat const kPPPad              = 20.0;
static CGFloat const kPPSectionGap       = 24.0;
static CGFloat const kPPFieldGap         = 12.0;
static NSInteger const kPPCheckmarkTag   = 8899;

#pragma mark - Static Helpers

static NSString *PPPaymentFormTrimmedString(id value) {
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *PPPaymentFormNormalizedMethodID(NSString *methodID) {
    NSString *normalized = [PPPaymentFormTrimmedString(methodID).lowercaseString copy];
    if ([normalized isEqualToString:@"card"]) return @"qib";
    return normalized;
}

static BOOL PPPaymentFormUsesCardFields(NSString *methodID) {
    return [PPPaymentFormNormalizedMethodID(methodID) isEqualToString:@"qib"];
}

static NSString *PPPaymentFormDigitsOnly(NSString *value) {
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    return [[PPPaymentFormTrimmedString(value)
             componentsSeparatedByCharactersInSet:nonDigits]
            componentsJoinedByString:@""];
}

static NSDictionary<NSString *, NSString *> *PPPaymentFormExpiryComponents(NSString *rawExpiry) {
    NSString *trimmed = PPPaymentFormTrimmedString(rawExpiry);
    if (trimmed.length == 0) return @{};

    NSString *month = @"";
    NSString *year  = @"";
    NSArray<NSString *> *slashParts = [trimmed componentsSeparatedByString:@"/"];
    if (slashParts.count >= 2) {
        month = PPPaymentFormDigitsOnly(slashParts.firstObject);
        year  = PPPaymentFormDigitsOnly(slashParts[1]);
    } else {
        NSString *digits = PPPaymentFormDigitsOnly(trimmed);
        if (digits.length == 4) {
            month = [digits substringToIndex:2];
            year  = [digits substringFromIndex:2];
        } else if (digits.length == 6) {
            month = [digits substringToIndex:2];
            year  = [digits substringFromIndex:2];
        }
    }

    NSInteger monthValue = [month integerValue];
    if (monthValue < 1 || monthValue > 12) return @{};
    if (year.length == 2) year = [@"20" stringByAppendingString:year];
    if (year.length < 4) return @{};

    return @{
        @"month": [NSString stringWithFormat:@"%02ld", (long)monthValue],
        @"year" : year
    };
}

#pragma mark - Private Interface

@interface PPPaymentFormViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView  *contentStack;
@property (nonatomic, strong) UIStackView  *optionsStack;
@property (nonatomic, strong) UIView       *fieldsContainer;
@property (nonatomic, strong) UIStackView  *fieldsStack;
@property (nonatomic, strong) UIView       *saveContainer;
@property (nonatomic, strong) UIButton     *saveActionButton;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UITextField *> *fieldsByTag;
@property (nonatomic, strong) UIView       *selectedOptionCard;
@property (nonatomic, assign) BOOL expanded;
@property (nonatomic, weak) id<PaymentHeightDelegate> delegate;
@property (nonatomic, strong) UserPaymentInstrumentManager *instrumentManager;
@property (nonatomic, strong) NSArray<PaymentMethod *>     *availableMethods;
@property (nonatomic, strong) PaymentMethod                *selectedMethod;
@end

@implementation PPPaymentFormViewController

#pragma mark - Init

- (instancetype)init {
    self = [super init];
    if (self) {
        _fieldsByTag = [NSMutableDictionary dictionary];
    }
    return self;
}

- (instancetype)initForAddingMethod:(PaymentMethod *)method {
    self = [self init];
    if (self) {
        _mode = PPPaymentFormModeAdd;
        _isEditingExisting = NO;
    }
    return self;
}

- (instancetype)initForEditingInstrument:(UserPaymentInstrument *)instrument {
    self = [self init];
    if (self) {
        _mode = PPPaymentFormModeEdit;
        _isEditingExisting = YES;
        _editingInstrument = instrument;
        _selectedMethod = instrument.method;
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.expanded = NO;
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.instrumentManager = [UserPaymentInstrumentManager sharedManager];
    self.availableMethods  = [PaymentMethod defaultMethods];

    [self pp_buildScrollView];
    [self pp_buildPaymentOptions];
    [self pp_buildFieldsContainer];
    [self pp_buildSaveButton];

    if (self.isEditingExisting && self.editingInstrument) {
        [self pp_prefillForInstrument:self.editingInstrument];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    NSString *saveTitle = (self.mode == PPPaymentFormModeEdit)
        ? kLang(@"Update") : kLang(@"Save");

    UIButton *saveBTN = [PPButtonHelper pp_buttonWithTitleForBar:saveTitle
                                                      imageName:@"checkmark.circle"
                                                         target:self
                                                         action:@selector(saveButtonPressed)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:saveBTN];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:PPSYSImage(PPChevronName)
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(onBack)];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Keyboard

- (void)pp_keyboardWillShow:(NSNotification *)note {
    CGRect kbFrame = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIEdgeInsets insets = self.scrollView.contentInset;
    insets.bottom = kbFrame.size.height;
    [UIView animateWithDuration:duration animations:^{
        self.scrollView.contentInset = insets;
        self.scrollView.scrollIndicatorInsets = insets;
    }];
}

- (void)pp_keyboardWillHide:(NSNotification *)note {
    CGFloat duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView animateWithDuration:duration animations:^{
        self.scrollView.contentInset = UIEdgeInsetsZero;
        self.scrollView.scrollIndicatorInsets = UIEdgeInsetsZero;
    }];
}

#pragma mark - Scroll & Stack

- (void)pp_buildScrollView {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];

    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis      = UILayoutConstraintAxisVertical;
    self.contentStack.spacing   = kPPSectionGap;
    self.contentStack.alignment = UIStackViewAlignmentFill;
    [self.scrollView addSubview:self.contentStack];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor      constraintEqualToAnchor:safe.topAnchor],
        [self.scrollView.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],

        [self.contentStack.topAnchor      constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor      constant:kPPPad],
        [self.contentStack.leadingAnchor  constraintEqualToAnchor:self.scrollView.frameLayoutGuide.leadingAnchor    constant:kPPPad],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.trailingAnchor   constant:-kPPPad],
        [self.contentStack.bottomAnchor   constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor   constant:-kPPPad],
    ]];
}

#pragma mark - Payment Options

- (void)pp_buildPaymentOptions {
    if (self.isEditingExisting) return;

    UILabel *sectionTitle = [self pp_makeSectionTitle:kLang(@"PaymentMethodTitle")];
    [self.contentStack addArrangedSubview:sectionTitle];

    self.optionsStack = [[UIStackView alloc] init];
    self.optionsStack.axis      = UILayoutConstraintAxisVertical;
    self.optionsStack.spacing   = 10.0;
    self.optionsStack.alignment = UIStackViewAlignmentFill;
    [self.contentStack addArrangedSubview:self.optionsStack];

    [self.optionsStack addArrangedSubview:
     [self pp_makeOptionCardWithTitle:kLang(@"PaymentOptionCard")
                             subtitle:kLang(@"PaymentOptionCardSubtitle")
                             iconName:@"card1"
                                  tag:@"qib"]];

    [self.optionsStack addArrangedSubview:
     [self pp_makeOptionCardWithTitle:kLang(@"Cash on Delivery")
                             subtitle:kLang(@"PaymentOptionCashSubtitle")
                             iconName:@"cash2"
                                  tag:@"cash"]];
}

- (UIView *)pp_makeOptionCardWithTitle:(NSString *)title
                              subtitle:(NSString *)subtitle
                              iconName:(NSString *)iconName
                                   tag:(NSString *)tag
{
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = AppForgroundColr;
    card.layer.cornerRadius  = kPPCornerRadius;
    card.layer.cornerCurve   = kCACornerCurveContinuous;
    card.accessibilityIdentifier = tag;

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:iconName]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.tintColor   = AppPrimaryClr;
    [card addSubview:iconView];

    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    titleLbl.text          = title;
    titleLbl.font          = [GM boldFontWithSize:15.0];
    titleLbl.textColor     = UIColor.labelColor;
    titleLbl.textAlignment = NSTextAlignmentNatural;
    [card addSubview:titleLbl];

    UILabel *subLbl = [[UILabel alloc] init];
    subLbl.translatesAutoresizingMaskIntoConstraints = NO;
    subLbl.text          = subtitle;
    subLbl.font          = [GM MidFontWithSize:12.0];
    subLbl.textColor     = UIColor.secondaryLabelColor;
    subLbl.textAlignment = NSTextAlignmentNatural;
    [card addSubview:subLbl];

    UIImageView *check = [[UIImageView alloc] initWithImage:
                          [UIImage systemImageNamed:@"checkmark.circle.fill"]];
    check.translatesAutoresizingMaskIntoConstraints = NO;
    check.tintColor = AppPrimaryClr;
    check.alpha     = 0.0;
    check.tag       = kPPCheckmarkTag;
    [card addSubview:check];

    [NSLayoutConstraint activateConstraints:@[
        [card.heightAnchor constraintEqualToConstant:kPPOptionHeight],

        [iconView.leadingAnchor  constraintEqualToAnchor:card.leadingAnchor constant:16],
        [iconView.centerYAnchor  constraintEqualToAnchor:card.centerYAnchor],
        [iconView.widthAnchor    constraintEqualToConstant:32],
        [iconView.heightAnchor   constraintEqualToConstant:32],

        [titleLbl.topAnchor      constraintEqualToAnchor:card.topAnchor constant:12],
        [titleLbl.leadingAnchor  constraintEqualToAnchor:iconView.trailingAnchor constant:14],
        [titleLbl.trailingAnchor constraintEqualToAnchor:check.leadingAnchor constant:-10],

        [subLbl.topAnchor        constraintEqualToAnchor:titleLbl.bottomAnchor constant:2],
        [subLbl.leadingAnchor    constraintEqualToAnchor:titleLbl.leadingAnchor],
        [subLbl.trailingAnchor   constraintEqualToAnchor:titleLbl.trailingAnchor],

        [check.trailingAnchor    constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [check.centerYAnchor     constraintEqualToAnchor:card.centerYAnchor],
        [check.widthAnchor       constraintEqualToConstant:22],
        [check.heightAnchor      constraintEqualToConstant:22],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self
                                   action:@selector(pp_optionTapped:)];
    [card addGestureRecognizer:tap];
    return card;
}

#pragma mark - Fields Container

- (void)pp_buildFieldsContainer {
    self.fieldsContainer = [[UIView alloc] init];
    self.fieldsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.fieldsContainer.alpha  = 0.0;
    self.fieldsContainer.hidden = YES;

    self.fieldsStack = [[UIStackView alloc] init];
    self.fieldsStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.fieldsStack.axis      = UILayoutConstraintAxisVertical;
    self.fieldsStack.spacing   = kPPFieldGap;
    self.fieldsStack.alignment = UIStackViewAlignmentFill;
    [self.fieldsContainer addSubview:self.fieldsStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.fieldsStack.topAnchor      constraintEqualToAnchor:self.fieldsContainer.topAnchor],
        [self.fieldsStack.leadingAnchor  constraintEqualToAnchor:self.fieldsContainer.leadingAnchor],
        [self.fieldsStack.trailingAnchor constraintEqualToAnchor:self.fieldsContainer.trailingAnchor],
        [self.fieldsStack.bottomAnchor   constraintEqualToAnchor:self.fieldsContainer.bottomAnchor],
    ]];

    [self.contentStack addArrangedSubview:self.fieldsContainer];
}

#pragma mark - Save Button

- (void)pp_buildSaveButton {
    self.saveContainer = [[UIView alloc] init];
    self.saveContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.saveContainer.alpha  = 0.0;
    self.saveContainer.hidden = YES;

    NSString *title = (self.mode == PPPaymentFormModeEdit) ? kLang(@"Update") : kLang(@"Save");

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration filledButtonConfiguration];
        cfg.cornerStyle          = UIButtonConfigurationCornerStyleLarge;
        cfg.baseBackgroundColor  = AppPrimaryClr;
        cfg.baseForegroundColor  = UIColor.whiteColor;
        cfg.image                = [UIImage systemImageNamed:@"checkmark.circle.fill"];
        cfg.imagePadding         = 8.0;
        cfg.contentInsets        = NSDirectionalEdgeInsetsMake(16, 24, 16, 24);

        NSMutableAttributedString *attrTitle =
            [[NSMutableAttributedString alloc] initWithString:title
                attributes:@{NSFontAttributeName: [GM boldFontWithSize:17.0]}];
        cfg.attributedTitle = attrTitle;
        self.saveActionButton = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    } else {
        self.saveActionButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.saveActionButton setTitle:title forState:UIControlStateNormal];
        [self.saveActionButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        self.saveActionButton.backgroundColor    = AppPrimaryClr;
        self.saveActionButton.titleLabel.font    = [GM boldFontWithSize:17.0];
        self.saveActionButton.layer.cornerRadius = 14.0;
    }

    self.saveActionButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.saveActionButton addTarget:self
                              action:@selector(saveButtonPressed)
                    forControlEvents:UIControlEventTouchUpInside];
    [self.saveContainer addSubview:self.saveActionButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.saveActionButton.topAnchor      constraintEqualToAnchor:self.saveContainer.topAnchor],
        [self.saveActionButton.leadingAnchor  constraintEqualToAnchor:self.saveContainer.leadingAnchor],
        [self.saveActionButton.trailingAnchor constraintEqualToAnchor:self.saveContainer.trailingAnchor],
        [self.saveActionButton.bottomAnchor   constraintEqualToAnchor:self.saveContainer.bottomAnchor],
        [self.saveActionButton.heightAnchor   constraintEqualToConstant:56.0],
    ]];

    [self.contentStack addArrangedSubview:self.saveContainer];
}

#pragma mark - Option Selection

- (void)pp_optionTapped:(UITapGestureRecognizer *)gesture {
    UIView *card = gesture.view;
    NSString *tag = card.accessibilityIdentifier;
    if (!tag) return;

    NSString *normalizedID = PPPaymentFormNormalizedMethodID(tag);
    PaymentMethod *method  = [PaymentMethod methodForID:normalizedID];
    if (!method) {
        [PPHUD showError:kLang(@"PleaseSelectPaymentMethod")];
        return;
    }

    if (self.selectedOptionCard) {
        [self pp_deselectCard:self.selectedOptionCard];
    }

    self.selectedMethod     = method;
    self.selectedOptionCard = card;
    [self pp_selectCard:card];

    [self pp_showFieldsForMethodID:normalizedID values:nil];

    self.expanded = YES;
    [self.delegate expandToLargeDetent:YES];
}

- (void)pp_selectCard:(UIView *)card {
    UIImageView *check = [card viewWithTag:kPPCheckmarkTag];
    card.transform = CGAffineTransformMakeScale(0.96, 0.96);
    card.alpha = 0.8;

    [UIView animateWithDuration:0.35
                          delay:0
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.20
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        card.transform          = CGAffineTransformIdentity;
        card.alpha              = 1.0;
        card.layer.borderWidth  = 2.0;
        [card pp_setBorderColor:AppPrimaryClr];
        check.alpha             = 1.0;
    } completion:nil];
}

- (void)pp_deselectCard:(UIView *)card {
    UIImageView *check = [card viewWithTag:kPPCheckmarkTag];
    [UIView animateWithDuration:0.2 animations:^{
        card.layer.borderWidth = 0.0;
        [card pp_setBorderColor:UIColor.clearColor];
        check.alpha = 0.0;
    }];
}

#pragma mark - Dynamic Field Building

- (void)pp_showFieldsForMethodID:(NSString *)methodID values:(NSDictionary *)values {
    for (UIView *v in self.fieldsStack.arrangedSubviews.copy) {
        [self.fieldsStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    [self.fieldsByTag removeAllObjects];

    NSString *norm = PPPaymentFormNormalizedMethodID(methodID);

    if (PPPaymentFormUsesCardFields(norm))               [self pp_buildCardFields];
    else if ([norm isEqualToString:@"ooredoo"])           [self pp_buildOoredooFields];
    else if ([norm isEqualToString:@"qnb"])               [self pp_buildQNBFields];
    else if ([norm isEqualToString:@"fawry"])              [self pp_buildFawryFields];
    else if ([norm isEqualToString:@"cash"])               [self pp_buildCashFields];

    if (values.count > 0) {
        for (NSString *key in values) {
            UITextField *f = self.fieldsByTag[key];
            if (f) f.text = PPPaymentFormTrimmedString(values[key]);
        }
    }

    self.fieldsContainer.hidden = NO;
    self.saveContainer.hidden   = NO;

    [UIView animateWithDuration:0.4
                          delay:0.05
         usingSpringWithDamping:0.85
          initialSpringVelocity:0.15
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.fieldsContainer.alpha = 1.0;
        self.saveContainer.alpha   = 1.0;
    } completion:nil];
}

#pragma mark - Card Fields

- (void)pp_buildCardFields {
    [self.fieldsStack addArrangedSubview:[self pp_makeSectionTitle:kLang(@"PaymentMethodCardTitle")]];

    [self pp_addFieldWithTitle:kLang(@"CardNumberTitle")
                   placeholder:kLang(@"CardNumberPlaceholder")
                           tag:@"cardNumber"
                  keyboardType:UIKeyboardTypeNumberPad
                      isSecure:NO];

    [self pp_addFieldWithTitle:kLang(@"ExpiryDateTitle")
                   placeholder:kLang(@"ExpiryDatePlaceholder")
                           tag:@"expiry"
                  keyboardType:UIKeyboardTypeNumbersAndPunctuation
                      isSecure:NO];

    [self pp_addFieldWithTitle:kLang(@"CVVTitle")
                   placeholder:kLang(@"CVVPlaceholder")
                           tag:@"cvv"
                  keyboardType:UIKeyboardTypeNumberPad
                      isSecure:YES];

    [self.fieldsStack addArrangedSubview:[self pp_makeSectionFooter:kLang(@"PaymentMethodCardFooter")]];
}

#pragma mark - Ooredoo Fields

- (void)pp_buildOoredooFields {
    [self.fieldsStack addArrangedSubview:[self pp_makeSectionTitle:kLang(@"PaymentMethodOoredooTitle")]];

    [self pp_addFieldWithTitle:kLang(@"OoredooWalletNumberTitle")
                   placeholder:kLang(@"OoredooWalletNumberPlaceholder")
                           tag:@"ooredooNumber"
                  keyboardType:UIKeyboardTypePhonePad
                      isSecure:NO];

    [self.fieldsStack addArrangedSubview:[self pp_makeSectionFooter:kLang(@"PaymentMethodOoredooFooter")]];
}

#pragma mark - QNB Fields

- (void)pp_buildQNBFields {
    [self.fieldsStack addArrangedSubview:[self pp_makeSectionTitle:kLang(@"PaymentMethodQNBTitle")]];

    [self pp_addFieldWithTitle:kLang(@"QNBAccountTitle")
                   placeholder:kLang(@"QNBAccountPlaceholder")
                           tag:@"qnbAccount"
                  keyboardType:UIKeyboardTypeDefault
                      isSecure:NO];

    [self pp_addFieldWithTitle:kLang(@"QNBOTPTitle")
                   placeholder:kLang(@"QNBOTPPlaceholder")
                           tag:@"qnbOtp"
                  keyboardType:UIKeyboardTypeNumberPad
                      isSecure:YES];

    [self.fieldsStack addArrangedSubview:[self pp_makeSectionFooter:kLang(@"PaymentMethodQNBFooter")]];
}

#pragma mark - Fawry Fields

- (void)pp_buildFawryFields {
    [self.fieldsStack addArrangedSubview:[self pp_makeSectionTitle:kLang(@"PaymentMethodFawryTitle")]];

    [self pp_addFieldWithTitle:kLang(@"FawryCustomerNameTitle")
                   placeholder:kLang(@"FawryCustomerNamePlaceholder")
                           tag:@"customerName"
                  keyboardType:UIKeyboardTypeDefault
                      isSecure:NO];

    [self pp_addFieldWithTitle:kLang(@"FawryMobileTitle")
                   placeholder:kLang(@"FawryMobilePlaceholder")
                           tag:@"mobileNumber"
                  keyboardType:UIKeyboardTypePhonePad
                      isSecure:NO];

    [self pp_addFieldWithTitle:kLang(@"FawryEmailTitle")
                   placeholder:kLang(@"FawryEmailPlaceholder")
                           tag:@"email"
                  keyboardType:UIKeyboardTypeEmailAddress
                      isSecure:NO];

    [self pp_addFieldWithTitle:kLang(@"FawryReferenceTitle")
                   placeholder:kLang(@"FawryReferencePlaceholder")
                           tag:@"referenceCode"
                  keyboardType:UIKeyboardTypeDefault
                      isSecure:NO];
    UITextField *refField = self.fieldsByTag[@"referenceCode"];
    refField.enabled = NO;
    refField.alpha   = 0.6;

    UIButton *genBtn = [self pp_makeSecondaryButtonWithTitle:kLang(@"GenerateFawryReferenceButton")
                                                     action:@selector(pp_generateFawryReference)];
    [self.fieldsStack addArrangedSubview:genBtn];

    [self.fieldsStack addArrangedSubview:[self pp_makeSectionFooter:kLang(@"PaymentMethodFawryFooter")]];
}

#pragma mark - Cash Fields

- (void)pp_buildCashFields {
    [self.fieldsStack addArrangedSubview:[self pp_makeSectionTitle:kLang(@"PaymentMethodCashTitle")]];

    [self pp_addFieldWithTitle:kLang(@"DeliveryNoteTitle")
                   placeholder:kLang(@"DeliveryNotePlaceholder")
                           tag:@"cashNote"
                  keyboardType:UIKeyboardTypeDefault
                      isSecure:NO];

    [self.fieldsStack addArrangedSubview:[self pp_makeSectionFooter:kLang(@"PaymentMethodCashFooter")]];
}

#pragma mark - Form Field Factory

- (void)pp_addFieldWithTitle:(NSString *)title
                 placeholder:(NSString *)placeholder
                         tag:(NSString *)tag
                keyboardType:(UIKeyboardType)kbType
                    isSecure:(BOOL)isSecure
{
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor    = AppForgroundColr;
    container.layer.cornerRadius = 14.0;
    container.layer.cornerCurve  = kCACornerCurveContinuous;

    UILabel *lbl = [[UILabel alloc] init];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.text          = title;
    lbl.font          = [GM MidFontWithSize:12.0];
    lbl.textColor     = UIColor.secondaryLabelColor;
    lbl.textAlignment = NSTextAlignmentNatural;
    [container addSubview:lbl];

    UITextField *tf = [[UITextField alloc] init];
    tf.translatesAutoresizingMaskIntoConstraints = NO;
    tf.placeholder        = placeholder;
    tf.font               = [GM MidFontWithSize:15.0];
    tf.textColor          = UIColor.labelColor;
    tf.keyboardType       = kbType;
    tf.secureTextEntry    = isSecure;
    tf.textAlignment      = NSTextAlignmentNatural;
    tf.autocorrectionType = UITextAutocorrectionTypeNo;
    tf.delegate           = self;
    tf.accessibilityIdentifier = tag;
    [container addSubview:tf];

    [NSLayoutConstraint activateConstraints:@[
        [container.heightAnchor constraintEqualToConstant:kPPFieldHeight],

        [lbl.topAnchor      constraintEqualToAnchor:container.topAnchor      constant:12],
        [lbl.leadingAnchor  constraintEqualToAnchor:container.leadingAnchor  constant:16],
        [lbl.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-16],

        [tf.topAnchor       constraintEqualToAnchor:lbl.bottomAnchor         constant:4],
        [tf.leadingAnchor   constraintEqualToAnchor:container.leadingAnchor  constant:16],
        [tf.trailingAnchor  constraintEqualToAnchor:container.trailingAnchor constant:-16],
        [tf.bottomAnchor    constraintEqualToAnchor:container.bottomAnchor   constant:-12],
    ]];

    self.fieldsByTag[tag] = tf;
    [self.fieldsStack addArrangedSubview:container];
}

- (UIButton *)pp_makeSecondaryButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *btn;
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration tintedButtonConfiguration];
        cfg.title               = title;
        cfg.cornerStyle         = UIButtonConfigurationCornerStyleLarge;
        cfg.baseBackgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.12];
        cfg.baseForegroundColor = AppPrimaryClr;
        cfg.contentInsets       = NSDirectionalEdgeInsetsMake(14, 20, 14, 20);
        btn = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    } else {
        btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:title forState:UIControlStateNormal];
        btn.backgroundColor    = [AppPrimaryClr colorWithAlphaComponent:0.12];
        [btn setTitleColor:AppPrimaryClr forState:UIControlStateNormal];
        btn.titleLabel.font    = [GM boldFontWithSize:15.0];
        btn.layer.cornerRadius = 14.0;
    }
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [btn.heightAnchor constraintEqualToConstant:50.0].active = YES;
    return btn;
}

- (UILabel *)pp_makeSectionTitle:(NSString *)text {
    UILabel *lbl = [[UILabel alloc] init];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.text          = text;
    lbl.font          = [GM boldFontWithSize:16.0];
    lbl.textColor     = UIColor.labelColor;
    lbl.textAlignment = NSTextAlignmentNatural;
    return lbl;
}

- (UILabel *)pp_makeSectionFooter:(NSString *)text {
    UILabel *lbl = [[UILabel alloc] init];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.text          = text;
    lbl.font          = [GM MidFontWithSize:12.0];
    lbl.textColor     = UIColor.tertiaryLabelColor;
    lbl.numberOfLines = 0;
    lbl.textAlignment = NSTextAlignmentNatural;
    return lbl;
}

#pragma mark - Value Collection

- (NSDictionary<NSString *, NSString *> *)pp_collectFormValues {
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    for (NSString *tag in self.fieldsByTag) {
        values[tag] = PPPaymentFormTrimmedString(self.fieldsByTag[tag].text);
    }
    return [values copy];
}

#pragma mark - Prefill (Edit Mode)

- (void)pp_prefillForInstrument:(UserPaymentInstrument *)instrument {
    NSDictionary *original = instrument.originalData ?: @{};
    NSString *methodID = instrument.methodID.length > 0
        ? instrument.methodID
        : instrument.method.methodID;

    self.selectedMethod = instrument.method
        ?: [PaymentMethod methodForID:PPPaymentFormNormalizedMethodID(methodID)];

    [self pp_showFieldsForMethodID:methodID values:original];
}

#pragma mark - Fawry Reference

- (void)pp_generateFawryReference {
    UITextField *ref = self.fieldsByTag[@"referenceCode"];
    ref.text    = nil;
    ref.enabled = NO;
    ref.alpha   = 0.6;
    [PPHUD showError:kLang(@"FawryReferenceError")];
}

#pragma mark - Card Issuer Detection

- (NSString *)detectCardIssuerFromNumber:(NSString *)cardNumber {
    if ([cardNumber hasPrefix:@"4"])                             return @"Visa";
    if ([cardNumber hasPrefix:@"5"])                             return @"MasterCard";
    if ([cardNumber hasPrefix:@"34"] || [cardNumber hasPrefix:@"37"]) return @"American Express";
    if ([cardNumber hasPrefix:@"6"])                             return @"Discover";
    return kLang(@"Unknown");
}

#pragma mark - Save

- (void)saveButtonPressed {
    NSDictionary *values = [self pp_collectFormValues];

    if (!self.selectedMethod && self.editingInstrument.methodID.length > 0) {
        self.selectedMethod = [PaymentMethod methodForID:
                               PPPaymentFormNormalizedMethodID(self.editingInstrument.methodID)];
    }

    if (!self.selectedMethod) {
        [PPHUD showError:kLang(@"PleaseSelectPaymentMethod")];
        return;
    }
    if (values.count == 0) {
        [PPHUD showError:kLang(@"PleaseCompleteFields")];
        return;
    }

    UserPaymentInstrument *instrument =
        (self.mode == PPPaymentFormModeEdit && self.editingInstrument)
            ? self.editingInstrument
            : [[UserPaymentInstrument alloc] init];

    instrument.userID   = PPCurrentUser.ID;
    instrument.methodID = PPPaymentFormNormalizedMethodID(self.selectedMethod.methodID);
    instrument.method   = self.selectedMethod;
    if (!instrument.createdAt) instrument.createdAt = [NSDate date];
    instrument.updatedAt = [NSDate date];

    NSMutableDictionary *original = [NSMutableDictionary dictionary];
    NSMutableDictionary *meta     = [NSMutableDictionary dictionary];
    NSString *masked = @"";

    switch (self.selectedMethod.type) {
        case PaymentMethodTypeQIB:
        case PaymentMethodTypeCard: {
            NSString *cardNumber = PPPaymentFormDigitsOnly(values[@"cardNumber"]);
            NSString *expiry     = PPPaymentFormTrimmedString(values[@"expiry"]);
            if (cardNumber.length < 12 || expiry.length == 0) {
                [PPHUD showError:kLang(@"PleaseFillCardDetails")];
                return;
            }
            NSDictionary *expiryParts = PPPaymentFormExpiryComponents(expiry);
            if (expiryParts.count == 0) {
                [PPHUD showError:kLang(@"ExpiryDatePlaceholder")];
                return;
            }
            NSString *last4 = [cardNumber substringFromIndex:MAX(0, cardNumber.length - 4)];
            masked = [NSString stringWithFormat:@"\u2022\u2022\u2022\u2022 %@", last4];
            meta[@"issuer"]      = [instrument detectCardIssuerFromNumber:cardNumber];
            meta[@"maskedCard"]  = masked;
            meta[@"last4"]       = last4;
            meta[@"expiryMonth"] = expiryParts[@"month"] ?: @"";
            meta[@"expiryYear"]  = expiryParts[@"year"]  ?: @"";
            break;
        }

        case PaymentMethodTypeQNB: {
            NSString *account = values[@"qnbAccount"];
            if (account.length == 0) {
                [PPHUD showError:kLang(@"PleaseEnterQNBAccount")];
                return;
            }
            original[@"qnbAccount"]   = account;
            masked = [instrument maskString:account];
            meta[@"bank"]           = @"QNB";
            meta[@"maskedAccount"]  = masked;
            break;
        }

        case PaymentMethodTypeOoredoo: {
            NSString *number = values[@"ooredooNumber"];
            if (number.length == 0) {
                [PPHUD showError:kLang(@"PleaseEnterOoredooNumber")];
                return;
            }
            original[@"ooredooNumber"] = number;
            masked = [instrument maskString:number];
            meta[@"provider"]      = @"Ooredoo Money";
            meta[@"maskedWallet"]  = masked;
            break;
        }

        case PaymentMethodTypeFawryQatar: {
            NSString *customer  = values[@"customerName"];
            NSString *mobile    = values[@"mobileNumber"];
            NSString *email     = values[@"email"]         ?: @"";
            NSString *reference = values[@"referenceCode"] ?: @"";
            if (mobile.length == 0 || customer.length == 0) {
                [PPHUD showError:kLang(@"PleaseCompleteFawryDetails")];
                return;
            }
            original[@"customerName"]  = customer;
            original[@"mobileNumber"]  = mobile;
            original[@"email"]         = email;
            original[@"referenceCode"] = reference;
            masked = [instrument maskString:mobile];
            meta[@"provider"]      = @"Fawry Qatar";
            meta[@"maskedMobile"]  = masked;
            break;
        }

        case PaymentMethodTypeCash:
            masked = kLang(@"CashPayment");
            meta[@"type"] = @"Cash";
            break;

        default:
            masked = @"\u2022\u2022\u2022\u2022\u2022\u2022";
            break;
    }

    instrument.originalData  = original;
    instrument.metaData      = meta;
    instrument.maskedDetails = masked;

    __weak typeof(self) weakSelf = self;

    if (self.mode == PPPaymentFormModeEdit) {
        [self.instrumentManager updateInstrument:instrument
                                         forUser:PPCurrentUser.ID
                                      completion:^(BOOL success, NSError * _Nullable error) {
            if (success) {
                [PPHUD showSuccess:kLang(@"PaymentMethodUpdated")
                          subtitle:kLang(@"PaymentUpdatedSubtitle")];
                [weakSelf.navigationController popViewControllerAnimated:YES];
            } else {
                [PPHUD showError:kLang(@"FailedToUpdatePaymentMethod")];
            }
        }];
    } else {
        [self.instrumentManager addInstrument:instrument
                                      forUser:PPCurrentUser.ID
                                   completion:^(BOOL success, NSError * _Nullable error) {
            if (success) {
                [PPHUD showSuccess:kLang(@"PaymentMethodSaved")
                          subtitle:kLang(@"PaymentSavedSubtitle")];
                [weakSelf.navigationController popViewControllerAnimated:YES];
            } else {
                [PPHUD showError:kLang(@"FailedToSavePaymentMethod")];
            }
        }];
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end


#pragma mark - PPGlassHeaderView

@interface PPGlassHeaderView ()
@property (nonatomic, copy) void (^cancelHandler)(void);
@end

@implementation PPGlassHeaderView

- (instancetype)initWithTitle:(NSString *)title
                cancelHandler:(void (^)(void))handler {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.cancelHandler = handler;
        [self setupUIWithTitle:title];
    }
    return self;
}

- (void)setupUIWithTitle:(NSString *)title {
    self.backgroundColor = UIColor.clearColor;

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.text = title;
    _titleLabel.font = [GM boldFontWithSize:18];
    _titleLabel.textColor = UIColor.labelColor;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    UIButtonConfiguration *config;
    if (@available(iOS 16.0, *)) {
        if (@available(iOS 26.0, *))
            config = [UIButtonConfiguration glassButtonConfiguration];
        else
            config = [UIButtonConfiguration filledButtonConfiguration];

        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.buttonSize  = UIButtonConfigurationSizeMedium;
        config.baseForegroundColor = UIColor.labelColor;

        _cancelButton = [UIButton buttonWithConfiguration:config primaryAction:nil];
        [_cancelButton setImage:PPSYSImage(@"multiply") forState:UIControlStateNormal];
    } else {
        _cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_cancelButton setImage:PPSYSImage(@"multiply") forState:UIControlStateNormal];
        _cancelButton.backgroundColor = [UIColor colorWithWhite:0.9 alpha:0.4];
        _cancelButton.layer.cornerRadius = 8;
    }

    [_cancelButton addTarget:self
                      action:@selector(cancelTapped)
            forControlEvents:UIControlEventTouchUpInside];
    _cancelButton.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _cancelButton]];
    stack.axis         = UILayoutConstraintAxisHorizontal;
    stack.alignment    = UIStackViewAlignmentCenter;
    stack.distribution = UIStackViewDistributionFill;
    stack.spacing      = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor      constraintEqualToAnchor:self.topAnchor      constant:8],
        [stack.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor  constant:26],
        [stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [stack.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor   constant:-8],

        [_cancelButton.widthAnchor  constraintEqualToConstant:40],
        [_cancelButton.heightAnchor constraintEqualToConstant:40]
    ]];
}

- (void)cancelTapped {
    if (self.cancelHandler) {
        self.cancelHandler();
    }
}

@end
