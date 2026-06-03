//
//  PPVerificationPromptViewController 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 18/11/2025.
//

#import "PPVerificationCodeViewController.h"
#import "Language.h"
#import "PPAuthScaffoldView.h"

static NSString *PPVerificationSafeUIDForLog(FIRUser * _Nullable user) {
    NSString *uid = user.uid ?: @"";
    if (uid.length == 0) {
        return @"<none>";
    }
    if (uid.length <= 6) {
        return [NSString stringWithFormat:@"<len=%lu>", (unsigned long)uid.length];
    }
    return [NSString stringWithFormat:@"...%@ (len=%lu)",
            [uid substringFromIndex:uid.length - 6],
            (unsigned long)uid.length];
}

@interface PPVerificationCodeViewController () <UITextFieldDelegate, UIGestureRecognizerDelegate, UIAdaptivePresentationControllerDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) PPAuthScaffoldView *authScaffoldView;
@property (nonatomic, strong) UIView *backgroundTopGlowView;
@property (nonatomic, strong) UIView *backgroundBottomGlowView;

@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIView *heroIconWrapView;
@property (nonatomic, strong) UIImageView *heroIconView;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UIButton *changeNumberButton;

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *instructionLabel;

@property (nonatomic, strong) UITextField *codeField;
@property (nonatomic, strong) UIStackView *digitStackView;
@property (nonatomic, strong) NSMutableArray<UIView *> *digitViews;
@property (nonatomic, strong) NSMutableArray<UILabel *> *digitLabels;

@property (nonatomic, strong) UIButton *continueButton;
@property (nonatomic, strong) UIButton *resendButton;
@property (nonatomic, strong) PPAuthStepIndicatorView *stepIndicatorView;

@property (nonatomic, assign) NSInteger remainingSeconds;
@property (nonatomic, strong) NSTimer *timer;

@property (nonatomic, copy) NSString *phone;
@property (nonatomic, assign) BOOL isVerifyingCode;
@property (nonatomic, assign) BOOL isRequestingResend;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@property (nonatomic, copy, nullable) NSString *pendingAutomaticSubmissionCode;

@end

@implementation PPVerificationCodeViewController

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(UITouch *)touch {

    // Don't block touches on buttons or text fields
    if ([touch.view isKindOfClass:[UIControl class]]) {
        return NO;
    }
    if ([touch.view isKindOfClass:[UITextField class]]) {
        return NO;
    }

    return YES;
}


- (instancetype)initWithPhone:(NSString *)phone {
    self = [super init];
    if (self) {
        _phone = phone;
        _remainingSeconds = 30;
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.modalInPresentation = (self.navigationController == nil);
    self.presentationController.delegate = self;
    self.navigationItem.hidesBackButton = YES;
    [self pp_configureNavigationChrome];

    [self setupBackgroundDecorations];
    [self setupScroll];
    [self setupCard];
    [self setupTexts];
    [self setupOTPField];
    [self setupButtons];
    [self setupConstraints];
    [self registerKeyboardNotifications];
    [self pp_applyModernChrome];

    [self startTimer];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(300 * NSEC_PER_MSEC)),
                   dispatch_get_main_queue(), ^{
        [self.codeField becomeFirstResponder];
    });

    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.modalInPresentation = (self.navigationController == nil);
    self.presentationController.delegate = self;
    [self.codeField becomeFirstResponder];
    [self animateVerificationEntranceIfNeeded];
}

- (void)dealloc {
    [self.timer invalidate];
    self.timer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)presentationControllerShouldDismiss:(UIPresentationController *)presentationController {
    return NO;
}

#pragma mark - Setup UI

- (void)setupBackgroundDecorations {
    self.authScaffoldView = [[PPAuthScaffoldView alloc] initWithFrame:self.view.bounds];
    self.authScaffoldView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.authScaffoldView];

    self.backgroundTopGlowView = [[UIView alloc] initWithFrame:CGRectZero];
    self.backgroundTopGlowView.userInteractionEnabled = NO;
    [self.view addSubview:self.backgroundTopGlowView];

    self.backgroundBottomGlowView = [[UIView alloc] initWithFrame:CGRectZero];
    self.backgroundBottomGlowView.userInteractionEnabled = NO;
    [self.view addSubview:self.backgroundBottomGlowView];
    self.backgroundTopGlowView.hidden = YES;
    self.backgroundBottomGlowView.hidden = YES;
}

- (void)pp_applyModernChrome {
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    [PPAuthScaffoldView applyPremiumCardStyleToView:self.cardView];

    self.heroIconWrapView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:PPIOS26() ? 0.16 : 0.10];
    self.titleLabel.font = [GM boldFontWithSize:27];
    self.instructionLabel.font = [GM MidFontWithSize:14];
    self.codeField.keyboardType = UIKeyboardTypeNumberPad;
    self.codeField.textContentType = UITextContentTypeOneTimeCode;
    self.codeField.tintColor = UIColor.clearColor;

    [PPAuthScaffoldView applyPrimaryButtonStyleToButton:self.continueButton enabled:self.continueButton.enabled loading:self.isVerifyingCode];

    self.resendButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:PPIOS26() ? 0.10 : 0.90];
    self.resendButton.layer.cornerRadius = 18.0;
}

- (void)setupScroll {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:self.scrollView];
    [self.scrollView addSubview:self.contentView];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor],
        [self.contentView.heightAnchor constraintGreaterThanOrEqualToAnchor:self.scrollView.frameLayoutGuide.heightAnchor]
    ]];
}

- (void)setupCard {
    self.cardView = [[UIView alloc] init];
    [PPAuthScaffoldView applyPremiumCardStyleToView:self.cardView];
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardView.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusField)];
    tap.delegate = self;
    [self.cardView addGestureRecognizer:tap];
    [self.contentView addSubview:self.cardView];
}

- (void)setupTexts {
    self.stepIndicatorView = [[PPAuthStepIndicatorView alloc] initWithStepTitles:[PPAuthScaffoldView defaultStepTitles]];
    [self.stepIndicatorView updateCurrentStepIndex:1 completedStepIndex:0 animated:NO];
    [self.contentView addSubview:self.stepIndicatorView];

    self.heroIconWrapView = [[UIView alloc] init];
    self.heroIconWrapView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroIconWrapView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:PPIOS26() ? 0.18 : 0.12];
    self.heroIconWrapView.layer.cornerRadius = 21.0;
    self.heroIconWrapView.layer.masksToBounds = YES;
    [self.cardView addSubview:self.heroIconWrapView];

    self.heroIconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"lock.shield.fill"]];
    self.heroIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.heroIconView.tintColor = AppPrimaryClr;
    [self.heroIconWrapView addSubview:self.heroIconView];

    self.backButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.backButton.translatesAutoresizingMaskIntoConstraints = NO;
    NSString *backIcon = [Language isRTL] ? @"arrow.right" : @"arrow.left";
    [self.backButton setImage:[UIImage systemImageNamed:backIcon withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    [self.backButton setTintColor:UIColor.secondaryLabelColor];
    [self.backButton addTarget:self action:@selector(didTapBack) forControlEvents:UIControlEventTouchUpInside];
    [self.cardView addSubview:self.backButton];
    self.backButton.hidden = YES;

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = kLang(@"verification_title");
    self.titleLabel.font =  [GM boldFontWithSize:27];
    self.titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.textColor = UIColor.labelColor;

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.text =
        [NSString stringWithFormat:kLang(@"verification_sent_to"), self.phone];
    self.subtitleLabel.font = [GM MidFontWithSize:15];
    self.subtitleLabel.textColor = UIColor.secondaryLabelColor;
    self.subtitleLabel.numberOfLines = 0;
    self.subtitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.alpha = 0.92;

    self.changeNumberButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.changeNumberButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.changeNumberButton setTitle:kLang(@"auth_change_number") ?: (Language.isRTL ? @"تغيير الرقم" : @"Change Number") forState:UIControlStateNormal];
    [self.changeNumberButton setTitleColor:AppPrimaryClr forState:UIControlStateNormal];
    self.changeNumberButton.titleLabel.font = [GM MidFontWithSize:14];
    [self.changeNumberButton addTarget:self action:@selector(didTapBack) forControlEvents:UIControlEventTouchUpInside];
    [self.cardView addSubview:self.changeNumberButton];

    self.instructionLabel = [[UILabel alloc] init];
    self.instructionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.instructionLabel.text = kLang(@"otp_enter_code_instruction");
    self.instructionLabel.font = [GM MidFontWithSize:14];
    self.instructionLabel.textAlignment = NSTextAlignmentCenter;
    self.instructionLabel.textColor = UIColor.tertiaryLabelColor;

    [self.cardView addSubview:self.titleLabel];
    [self.cardView addSubview:self.subtitleLabel];
    [self.cardView addSubview:self.instructionLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroIconWrapView.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:22],
        [self.heroIconWrapView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:20],
        [self.heroIconWrapView.widthAnchor constraintEqualToConstant:42],
        [self.heroIconWrapView.heightAnchor constraintEqualToConstant:42],
        [self.heroIconView.centerXAnchor constraintEqualToAnchor:self.heroIconWrapView.centerXAnchor],
        [self.heroIconView.centerYAnchor constraintEqualToAnchor:self.heroIconWrapView.centerYAnchor],
        [self.heroIconView.widthAnchor constraintEqualToConstant:20],
        [self.heroIconView.heightAnchor constraintEqualToConstant:20]
    ]];
}

- (void)pp_configureNavigationChrome {
    self.navigationController.navigationBarHidden = NO;
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithTransparentBackground];
    appearance.backgroundColor = UIColor.clearColor;
    appearance.shadowColor = UIColor.clearColor;
    self.navigationController.navigationBar.standardAppearance = appearance;
    self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    self.navigationController.navigationBar.compactAppearance = appearance;
    self.navigationController.navigationBar.tintColor = AppPrimaryClr ?: UIColor.labelColor;

    self.navigationItem.title = kLang(@"verification_title");
    UIImage *backImage = [UIImage systemImageNamed:[Language isRTL] ? @"arrow.right" : @"arrow.left"];
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithImage:backImage
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(didTapBack)];
    backItem.tintColor = AppPrimaryClr ?: UIColor.labelColor;
    self.navigationItem.leftBarButtonItem = backItem;
}

- (void)setupOTPField {
    self.codeField = [[UITextField alloc] init];
     
    self.codeField.textContentType = UITextContentTypeOneTimeCode;
    self.codeField.keyboardType = UIKeyboardTypeNumberPad;
    self.codeField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.codeField.spellCheckingType = UITextSpellCheckingTypeNo;
    self.codeField.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
    self.codeField.tintColor = UIColor.clearColor;
    self.codeField.textAlignment = NSTextAlignmentCenter;
    self.codeField.font =  [GM boldFontWithSize:1];
    self.codeField.placeholder = kLang(@"otp_placeholder");
    self.codeField.delegate = self;
    self.codeField.textColor = UIColor.clearColor;
    self.codeField.layer.cornerRadius = 12;
    self.codeField.backgroundColor = UIColor.clearColor;
    [self.codeField addTarget:self action:@selector(codeChanged:) forControlEvents:UIControlEventEditingChanged];
    self.codeField.translatesAutoresizingMaskIntoConstraints = NO;

    self.digitViews = [NSMutableArray array];
    self.digitLabels = [NSMutableArray array];
    self.digitStackView = [[UIStackView alloc] init];
    self.digitStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.digitStackView.axis = UILayoutConstraintAxisHorizontal;
    self.digitStackView.spacing = 10.0;
    self.digitStackView.distribution = UIStackViewDistributionFillEqually;
    self.digitStackView.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;

    for (NSInteger index = 0; index < 6; index++) {
        UIView *digitView = [[UIView alloc] init];
        digitView.translatesAutoresizingMaskIntoConstraints = NO;
        [PPAuthScaffoldView applyInputStyleToView:digitView];
        digitView.layer.cornerRadius = 17.0;
        [digitView.heightAnchor constraintEqualToConstant:54].active = YES;
        [digitView.widthAnchor constraintLessThanOrEqualToConstant:52.0].active = YES;

        UILabel *digitLabel = [[UILabel alloc] init];
        digitLabel.translatesAutoresizingMaskIntoConstraints = NO;
        digitLabel.font = [GM boldFontWithSize:28];
        digitLabel.textAlignment = NSTextAlignmentCenter;
        digitLabel.textColor = UIColor.labelColor;
        [digitView addSubview:digitLabel];

        [NSLayoutConstraint activateConstraints:@[
            [digitLabel.centerXAnchor constraintEqualToAnchor:digitView.centerXAnchor],
            [digitLabel.centerYAnchor constraintEqualToAnchor:digitView.centerYAnchor]
        ]];

        [self.digitViews addObject:digitView];
        [self.digitLabels addObject:digitLabel];
        [self.digitStackView addArrangedSubview:digitView];
    }

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusField)];
    [self.digitStackView addGestureRecognizer:tap];

    [self.cardView addSubview:self.digitStackView];
    [self.cardView addSubview:self.codeField];
    [self refreshDigitBoxesAnimated:NO];
}

- (void)setupButtons {
    UIButtonConfiguration *config;
    if (@available(iOS 26.0, *)) {
        config = [UIButtonConfiguration glassButtonConfiguration];
    } else {
        config = [UIButtonConfiguration filledButtonConfiguration];
    }
    config.baseBackgroundColor = AppPrimaryClr;
    config.cornerStyle = UIButtonConfigurationCornerStyleFixed;

    config.attributedTitle =
        [[NSAttributedString alloc] initWithString:kLang(@"otp_verify_button")
                                        attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:17]
                                        }];

    config.contentInsets = NSDirectionalEdgeInsetsMake(14, 18, 14, 18);
    config.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;
 
    config.background.cornerRadius = 22;
    config.background.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:1.1];
    config.baseForegroundColor = AppForgroundColr;

    self.continueButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.continueButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.continueButton.configuration = config;
    self.continueButton.clipsToBounds = NO;
    self.continueButton.enabled = NO;
    self.continueButton.alpha = 0.6;
    [PPAuthScaffoldView applyPrimaryButtonStyleToButton:self.continueButton enabled:NO loading:NO];
    [PPAuthScaffoldView addPressMotionToControl:self.continueButton];

    [self.continueButton addTarget:self
                            action:@selector(didTapContinue)
                  forControlEvents:UIControlEventTouchUpInside];

    [self.cardView addSubview:self.continueButton];

    // resend button
    self.resendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.resendButton.enabled = NO;
    [self.resendButton setTitle:kLang(@"resend_timer_45") forState:UIControlStateNormal];
    [self.resendButton addTarget:self
                          action:@selector(didTapResend)
                forControlEvents:UIControlEventTouchUpInside];
    self.resendButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.resendButton.titleLabel.font = [GM boldFontWithSize:13];
    [ self.resendButton setTitleColor:AppButtonMixColorClr forState:UIControlStateNormal];
    self.resendButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:PPIOS26() ? 0.10 : 0.88];
    self.resendButton.layer.cornerRadius = 18.0;
    self.resendButton.layer.masksToBounds = YES;
    self.resendButton.contentEdgeInsets = UIEdgeInsetsMake(10, 16, 10, 16);
    [PPAuthScaffoldView applySecondaryButtonStyleToButton:self.resendButton];
    [self.cardView addSubview:self.resendButton];
}

#pragma mark - Constraints

- (void)setupConstraints {
    NSLayoutConstraint *cardLeading = [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20];
    NSLayoutConstraint *cardTrailing = [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20];
    cardLeading.priority = UILayoutPriorityDefaultHigh;
    cardTrailing.priority = UILayoutPriorityDefaultHigh;
    NSLayoutConstraint *digitLeading = [self.digitStackView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:18];
    NSLayoutConstraint *digitTrailing = [self.digitStackView.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-18];
    digitLeading.priority = UILayoutPriorityDefaultHigh;
    digitTrailing.priority = UILayoutPriorityDefaultHigh;

    [NSLayoutConstraint activateConstraints:@[
        [self.stepIndicatorView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
        [self.stepIndicatorView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:24],
        [self.stepIndicatorView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-24],
        [self.stepIndicatorView.heightAnchor constraintEqualToConstant:78.0],

        [self.cardView.topAnchor constraintEqualToAnchor:self.stepIndicatorView.bottomAnchor constant:18],
        cardLeading,
        cardTrailing,
        [self.cardView.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [self.cardView.widthAnchor constraintLessThanOrEqualToConstant:560.0],
        [self.cardView.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-24],

        [self.backButton.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:12],
        [self.backButton.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:12],
        [self.backButton.widthAnchor constraintEqualToConstant:44],
        [self.backButton.heightAnchor constraintEqualToConstant:44],

        [self.titleLabel.centerYAnchor constraintEqualToAnchor:self.heroIconWrapView.centerYAnchor],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.heroIconWrapView.trailingAnchor constant:12],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-16],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.heroIconWrapView.bottomAnchor constant:12],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:16],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-16],

        [self.changeNumberButton.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:2],
        [self.changeNumberButton.centerXAnchor constraintEqualToAnchor:self.cardView.centerXAnchor],

        [self.instructionLabel.topAnchor constraintEqualToAnchor:self.changeNumberButton.bottomAnchor constant:14],
        [self.instructionLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:24],
        [self.instructionLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-24],

        [self.digitStackView.topAnchor constraintEqualToAnchor:self.instructionLabel.bottomAnchor constant:20],
        [self.digitStackView.centerXAnchor constraintEqualToAnchor:self.cardView.centerXAnchor],
        digitLeading,
        digitTrailing,
        [self.digitStackView.widthAnchor constraintLessThanOrEqualToConstant:354.0],

        [self.codeField.topAnchor constraintEqualToAnchor:self.digitStackView.bottomAnchor constant:2],
        [self.codeField.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:30],
        [self.codeField.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-30],
        [self.codeField.heightAnchor constraintEqualToConstant:1],

        [self.continueButton.topAnchor constraintEqualToAnchor:self.digitStackView.bottomAnchor constant:24],
        [self.continueButton.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:16],
        [self.continueButton.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-16],
        [self.continueButton.heightAnchor constraintEqualToConstant:54],

        [self.resendButton.topAnchor constraintEqualToAnchor:self.continueButton.bottomAnchor constant:18],
        [self.resendButton.centerXAnchor constraintEqualToAnchor:self.cardView.centerXAnchor],
        [self.resendButton.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-22]
    ]];
}

#pragma mark - OTP Logic

- (NSString *)normalizedOTPDigitsFromInput:(NSString *)rawInput {
    NSString *trimmed = [rawInput ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSCharacterSet *digitSet = [NSCharacterSet decimalDigitCharacterSet];
    NSCharacterSet *asciiDigits = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
    NSMutableString *digits = [NSMutableString string];

    for (NSUInteger index = 0; index < trimmed.length; index++) {
        unichar ch = [trimmed characterAtIndex:index];
        if (![digitSet characterIsMember:ch]) {
            continue;
        }

        NSString *rawDigit = [NSString stringWithFormat:@"%C", ch];
        NSString *latinDigit = [rawDigit stringByApplyingTransform:NSStringTransformToLatin reverse:NO] ?: rawDigit;
        unichar normalized = latinDigit.length > 0 ? [latinDigit characterAtIndex:0] : 0;
        if ([asciiDigits characterIsMember:normalized]) {
            [digits appendFormat:@"%C", normalized];
        }
    }

    if (digits.length > 6) {
        return [digits substringToIndex:6];
    }

    return digits;
}

- (void)codeChanged:(UITextField *)field {
    NSString *digits = [self normalizedOTPDigitsFromInput:field.text];
    field.text = digits;

    if (digits.length > 0) {
        UIImpactFeedbackGenerator *h = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [h impactOccurred];
    }

    self.continueButton.enabled = (digits.length == 6 && !self.isVerifyingCode && !self.isRequestingResend);
    [PPAuthScaffoldView applyPrimaryButtonStyleToButton:self.continueButton enabled:self.continueButton.enabled loading:NO];
    [self refreshDigitBoxesAnimated:YES];

    if (digits.length != 6) {
        self.pendingAutomaticSubmissionCode = nil;
        return;
    }

    if (self.isVerifyingCode ||
        self.isRequestingResend ||
        [self.pendingAutomaticSubmissionCode isEqualToString:digits]) {
        return;
    }

    // A one-time-code suggestion inserts all six digits in one edit event.
    // Let the visual boxes update, then submit only the current inserted code.
    self.pendingAutomaticSubmissionCode = digits;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(200 * NSEC_PER_MSEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self ||
            self.isVerifyingCode ||
            self.isRequestingResend ||
            ![self.pendingAutomaticSubmissionCode isEqualToString:self.codeField.text]) {
            return;
        }
        NSString *submittedCode = self.pendingAutomaticSubmissionCode;
        self.pendingAutomaticSubmissionCode = nil;
        NSLog(@"[Auth][OTP] Auto-submitting one-time code suggestion. length=%lu",
              (unsigned long)submittedCode.length);
        [self verifyPhoneCode:submittedCode on:self];
    });
}

- (void)refreshDigitBoxesAnimated:(BOOL)animated {
    NSUInteger length = self.codeField.text.length;
    for (NSInteger index = 0; index < self.digitViews.count; index++) {
        UIView *digitView = self.digitViews[index];
        UILabel *digitLabel = self.digitLabels[index];
        BOOL filled = (index < (NSInteger)length);
        BOOL current = (index == (NSInteger)length && length < 6);

        NSString *character = filled ? [self.codeField.text substringWithRange:NSMakeRange(index, 1)] : @"";
        digitLabel.text = character;
        digitLabel.textColor = filled ? UIColor.labelColor : UIColor.tertiaryLabelColor;
        digitView.backgroundColor = filled
        ? [AppPrimaryClr colorWithAlphaComponent:PPIOS26() ? 0.16 : 0.10]
        : [UIColor colorWithWhite:1.0 alpha:PPIOS26() ? 0.08 : 0.82];
        digitView.layer.borderWidth = current ? 1.4 : 1.0;
        [digitView pp_setBorderColor:(current ? [AppPrimaryClr colorWithAlphaComponent:0.70] : [UIColor colorWithWhite:1.0 alpha:0.14])];

        if (animated && filled) {
            digitView.transform = CGAffineTransformMakeScale(0.94, 0.94);
            [UIView animateWithDuration:0.20
                                  delay:0.0
                 usingSpringWithDamping:0.84
                  initialSpringVelocity:0.16
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                digitView.transform = CGAffineTransformIdentity;
            } completion:nil];
        }
    }
}

- (void)didTapContinue {
    if (self.codeField.text.length == 6) {
        NSLog(@"[Auth][OTP] Manual submit tapped. length=%lu",
              (unsigned long)self.codeField.text.length);
        [self verifyPhoneCode:self.codeField.text on:self];
    }
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    [self pp_applyFocusStateAnimated:YES];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    [self pp_applyFocusStateAnimated:NO];
}

- (void)pp_applyFocusStateAnimated:(BOOL)animated {
    void (^layoutBlock)(void) = ^{
        [self.scrollView layoutIfNeeded];
        [self.contentView layoutIfNeeded];
        [self.cardView layoutIfNeeded];
        [self.view layoutIfNeeded];
    };

    if (animated) {
        [UIView animateWithDuration:0.22
                              delay:0.0
             usingSpringWithDamping:0.92
              initialSpringVelocity:0.1
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:layoutBlock
                         completion:nil];
    } else {
        layoutBlock();
    }
}


- (void)submitCode {
    if (self.onCodeSubmitted && self.codeField.text.length == 6) {
        self.onCodeSubmitted(self.codeField.text);
    }
}

#pragma mark - Resend Timer

- (void)startTimer {
    [self.timer invalidate];
    self.timer = nil;
    self.remainingSeconds = 60;
    self.resendButton.enabled = NO;

    [self updateTimerLabel];

    self.timer = [NSTimer scheduledTimerWithTimeInterval:1
                                                  target:self
                                                selector:@selector(updateTimer)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)updateTimer {
    self.remainingSeconds--;

    [self updateTimerLabel];

    if (self.remainingSeconds <= 0) {
        [self.timer invalidate];
        self.timer = nil;
        self.resendButton.enabled = YES;
        [self.resendButton setTitle:kLang(@"resend_code") forState:UIControlStateNormal];
    }
}

- (void)updateTimerLabel {
    NSString *formatted =
        [NSString stringWithFormat:kLang(@"resend_timer_format"), (long)self.remainingSeconds];
    [self.resendButton setTitle:formatted forState:UIControlStateNormal];
}

- (NSString *)pp_joinedVerificationErrorText:(NSError *)error {
    if (!error) {
        return @"";
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (error.domain.length > 0) {
        [parts addObject:error.domain];
    }
    if (error.localizedDescription.length > 0) {
        [parts addObject:error.localizedDescription];
    }
    for (id value in (error.userInfo ?: @{}).allValues) {
        if ([value isKindOfClass:NSString.class]) {
            [parts addObject:(NSString *)value];
        } else if ([value isKindOfClass:NSError.class]) {
            NSString *nested = [self pp_joinedVerificationErrorText:(NSError *)value];
            if (nested.length > 0) {
                [parts addObject:nested];
            }
        }
    }
    return [[parts componentsJoinedByString:@" "] lowercaseString];
}

- (NSString *)pp_localizedVerificationMessageForError:(NSError *)error fallbackKey:(NSString *)fallbackKey {
    NSString *joined = [self pp_joinedVerificationErrorText:error];
    if ([joined containsString:@"too_long"] || [joined containsString:@"too long"]) {
        return kLang(@"auth_phone_error_too_long");
    }
    if ([joined containsString:@"too_short"] || [joined containsString:@"too short"]) {
        return kLang(@"auth_phone_error_too_short");
    }
    if ([joined containsString:@"invalid_phone"] || [joined containsString:@"invalid phone"]) {
        return kLang(@"auth_phone_error_invalid");
    }
    if ([joined containsString:@"quota"] ||
        [joined containsString:@"too_many"] ||
        [joined containsString:@"too many"] ||
        [joined containsString:@"rate limit"]) {
        return kLang(@"auth_phone_error_rate_limited");
    }
    if ([joined containsString:@"network"] ||
        [joined containsString:@"offline"] ||
        [joined containsString:@"connection"]) {
        return kLang(@"auth_network_error_message");
    }
    if ([joined containsString:@"app check"] ||
        [joined containsString:@"appcheck"] ||
        [joined containsString:@"app_not_verified"] ||
        [joined containsString:@"app not verified"]) {
        return kLang(@"auth_app_verification_failed_message");
    }

    NSString *fallback = fallbackKey.length > 0 ? kLang(fallbackKey) : nil;
    return fallback.length > 0 ? fallback : kLang(@"auth_error_message");
}

- (void)didTapResend {
    if (self.isRequestingResend) {
        return;
    }
    
    if (!self.onResendRequested) {
        [self startTimer];
        return;
    }
    
    self.isRequestingResend = YES;
    [self.timer invalidate];
    self.timer = nil;
    self.resendButton.enabled = NO;
    [self.resendButton setTitle:kLang(@"auth_sending_code_title") forState:UIControlStateNormal];
    
    __weak typeof(self) weakSelf = self;
    self.onResendRequested(^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!weakSelf) {
                return;
            }
            weakSelf.isRequestingResend = NO;
            if (success) {
                weakSelf.codeField.text = @"";
                weakSelf.pendingAutomaticSubmissionCode = nil;
                weakSelf.continueButton.enabled = NO;
                [PPAuthScaffoldView applyPrimaryButtonStyleToButton:weakSelf.continueButton enabled:NO loading:NO];
                [weakSelf refreshDigitBoxesAnimated:NO];
                [weakSelf.codeField becomeFirstResponder];
                [weakSelf startTimer];
                return;
            }
            
            weakSelf.resendButton.enabled = YES;
            [weakSelf.resendButton setTitle:kLang(@"resend_code") forState:UIControlStateNormal];
            NSString *message = [weakSelf pp_localizedVerificationMessageForError:error
                                                                      fallbackKey:@"auth_resend_code_failed_message"];
            [weakSelf showResendFailureAlertWithMessage:message];
        });
    });
}

#pragma mark - Keyboard Handling

- (void)registerKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)keyboardWillShow:(NSNotification *)note {
    CGRect kb = [[note.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    UIEdgeInsets inset = self.scrollView.contentInset;
    inset.bottom = kb.size.height + 20;
    self.scrollView.contentInset = inset;
    self.scrollView.scrollIndicatorInsets = inset;
    
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.scrollView.canCancelContentTouches = NO;

}

- (void)keyboardWillHide:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIEdgeInsets inset = UIEdgeInsetsZero;
        self.scrollView.contentInset = inset;
        self.scrollView.scrollIndicatorInsets = inset;
        
        self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
        self.scrollView.canCancelContentTouches = NO;

    });
}

#pragma mark - Actions

- (void)didTapBack {
    [self.codeField resignFirstResponder];
    if (self.onBackRequested) {
        self.onBackRequested();
    }
    if (self.navigationController.viewControllers.firstObject != self) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Focus

- (void)focusField {
    [self.codeField becomeFirstResponder];
}


-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];

    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.scrollView.canCancelContentTouches = NO;

    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat height = CGRectGetHeight(self.view.bounds);
    CGFloat topGlowSize = MIN(220.0, width * 0.50);
    CGFloat bottomGlowSize = MIN(200.0, width * 0.46);
    self.backgroundTopGlowView.frame = CGRectMake(-34.0, self.view.safeAreaInsets.top - 18.0, topGlowSize, topGlowSize);
    self.backgroundBottomGlowView.frame = CGRectMake(width - bottomGlowSize + 34.0, MAX(height * 0.48, 300.0), bottomGlowSize, bottomGlowSize);
    self.backgroundTopGlowView.layer.cornerRadius = topGlowSize * 0.5;
    self.backgroundBottomGlowView.layer.cornerRadius = bottomGlowSize * 0.5;
    self.backgroundTopGlowView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:PPIOS26() ? 0.16 : 0.10];
    self.backgroundBottomGlowView.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:PPIOS26() ? 0.10 : 0.07];

    [Styling addLiquidGlassBorderToView:self.cardView cornerRadius:32];
    [Styling addLiquidGlassBorderToView:self.heroIconWrapView cornerRadius:28 color:[[UIColor whiteColor] colorWithAlphaComponent:0.18]];
    [Styling addLiquidGlassBorderToView:self.continueButton cornerRadius:22 color:[[UIColor whiteColor] colorWithAlphaComponent:0.10]];
    [Styling addLiquidGlassBorderToView:self.resendButton cornerRadius:18 color:[[UIColor whiteColor] colorWithAlphaComponent:0.14]];
    for (UIView *digitView in self.digitViews) {
        [Styling addLiquidGlassBorderToView:digitView cornerRadius:16 color:[[UIColor whiteColor] colorWithAlphaComponent:0.14]];
    }

}

-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self pp_applyModernChrome];
}


- (void)showInvalidCodeAlert {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:kLang(@"invalid_code_title")
                                            message:kLang(@"invalid_code_message")
                                     preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *ok =
        [UIAlertAction actionWithTitle:kLang(@"ok_button")
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction * _Nonnull action) {
        [self focusField];
    }];

    [alert addAction:ok];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showResendFailureAlertWithMessage:(NSString *)message {
    UIAlertController *alert =
    [UIAlertController alertControllerWithTitle:kLang(@"auth_sending_code_failed_title")
                                        message:message
                                 preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"ok_button")
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)shakeCodeField {
    CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    shake.values = @[ @(-10), @(10), @(-8), @(8), @(-5), @(5), @(0) ];
    shake.duration = 0.35;
    CALayer *targetLayer = self.digitStackView ? self.digitStackView.layer : self.cardView.layer;
    [targetLayer addAnimation:shake forKey:@"shake"];
}

- (void)hapticError {
    UINotificationFeedbackGenerator *gen = [[UINotificationFeedbackGenerator alloc] init];
    [gen notificationOccurred:UINotificationFeedbackTypeError];
}


- (void)showInvalidCodeError {

    // haptic + shake
    [self shakeCodeField];
    UINotificationFeedbackGenerator *gen = [[UINotificationFeedbackGenerator alloc] init];
    [gen notificationOccurred:UINotificationFeedbackTypeError];

    // clear code
    self.codeField.text = @"";
    self.pendingAutomaticSubmissionCode = nil;
    self.continueButton.enabled = NO;
    [PPAuthScaffoldView applyPrimaryButtonStyleToButton:self.continueButton enabled:NO loading:NO];
    [self refreshDigitBoxesAnimated:NO];

    // 💥 Keep keyboard open
    [self.codeField becomeFirstResponder];

    
}

- (void)showInvalidCodeErrorWithMessage:(NSString *)message {
    [self showInvalidCodeError];
    NSString *displayMessage = message.length > 0 ? message : kLang(@"invalid_code_message");
    [PPAlertHelper showWarningIn:self
                           title:kLang(@"invalid_code_title")
                        subtitle:displayMessage];
}


#pragma mark - Firebase Verification

- (void)verifyPhoneCode:(NSString *)code on:(PPVerificationCodeViewController *)vc {
    if (self.isVerifyingCode || self.isRequestingResend) {
        return;
    }

    if (code.length != 6) {
        return;
    }
    
    self.pendingAutomaticSubmissionCode = nil;
    self.isVerifyingCode = YES;
    NSString *verificationID = [[NSUserDefaults standardUserDefaults] stringForKey:@"authVerificationID"];
    NSLog(@"[Auth][OTP] Verification started. codeLength=%lu hasVerificationID=%@ currentUID=%@",
          (unsigned long)code.length,
          verificationID.length > 0 ? @"YES" : @"NO",
          PPVerificationSafeUIDForLog([FIRAuth auth].currentUser));

    if (self.onCodeVerificationRequested) {
        [self setLoadingState:YES];
        __weak typeof(self) weakSelf = self;
        self.onCodeVerificationRequested(code, ^(BOOL success, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) {
                    return;
                }

                [self setLoadingState:NO];
                self.isVerifyingCode = NO;

                if (!success) {
                    NSString *domain = [error.domain lowercaseString];
                    BOOL invalidCode =
                    (error.code == FIRAuthErrorCodeInvalidVerificationCode) ||
                    (error.code == FIRAuthErrorCodeSessionExpired) ||
                    [domain containsString:@"verification"];

                    if (invalidCode) {
                        [self showInvalidCodeError];
                    } else {
                        NSString *message = [self pp_localizedVerificationMessageForError:error
                                                                              fallbackKey:@"auth_error_message"];
                        [self showResendFailureAlertWithMessage:message];
                    }
                    return;
                }

                UINotificationFeedbackGenerator *gen = [[UINotificationFeedbackGenerator alloc] init];
                [gen notificationOccurred:UINotificationFeedbackTypeSuccess];
                [UIView animateWithDuration:0.25 animations:^{
                    self.cardView.alpha = 0.0;
                } completion:^(__unused BOOL finished) {
                    [self dismissViewControllerAnimated:YES completion:nil];
                }];
            });
        });
        return;
    }

    if (!verificationID || verificationID.length == 0) {
        NSLog(@"[Auth][OTP] Missing verificationID before Firebase credential creation.");
        self.isVerifyingCode = NO;
        [self showInvalidCodeErrorWithMessage:kLang(@"auth_session_expired_message") ?: kLang(@"auth_verification_start_failed")];
        return;
    }

    FIRAuthCredential *credential =
        [[FIRPhoneAuthProvider provider] credentialWithVerificationID:verificationID
                                                    verificationCode:code];

    // Loading indicator in button
    [self setLoadingState:YES];

    [[FIRAuth auth] signInWithCredential:credential
                              completion:^(FIRAuthDataResult * _Nullable authResult,
                                           NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{

            // stop loading button
            [self setLoadingState:NO];
            self.isVerifyingCode = NO;

            if (error) {
                NSLog(@"[Auth][OTP] Firebase sign-in failed. domain=%@ code=%ld message=%@ currentUID=%@",
                      error.domain,
                      (long)error.code,
                      error.localizedDescription,
                      PPVerificationSafeUIDForLog([FIRAuth auth].currentUser));
                NSString *message = [self pp_localizedVerificationMessageForError:error
                                                                      fallbackKey:@"invalid_code_message"];
                [self showInvalidCodeErrorWithMessage:message];
                return;
            }

            NSLog(@"[Auth][OTP] Firebase sign-in succeeded. resultUID=%@ currentUID=%@",
                  PPVerificationSafeUIDForLog(authResult.user),
                  PPVerificationSafeUIDForLog([FIRAuth auth].currentUser));
            [self handleSuccessfulAuth:authResult];
        });
    }];
}

#pragma mark - Success Handling

- (void)handleSuccessfulAuth:(FIRAuthDataResult *)authResult {

    // Haptic
    UINotificationFeedbackGenerator *gen = [[UINotificationFeedbackGenerator alloc] init];
    [gen notificationOccurred:UINotificationFeedbackTypeSuccess];

    // Capture callback before dismissal so the signing controller's dismiss
    // happens only after this sheet is fully gone (avoids the race where
    // the parent's [self dismiss] is dropped while we're mid-transition).
    void (^successCallback)(FIRAuthDataResult *) = self.onAuthResultSuccess;
    NSLog(@"[Auth][OTP] Dismissing verification sheet after success. currentUID=%@ presenting=%@ presented=%@",
          PPVerificationSafeUIDForLog([FIRAuth auth].currentUser),
          NSStringFromClass(self.presentingViewController.class),
          NSStringFromClass(self.presentedViewController.class));

    // Fade out UI, then dismiss — fire the parent callback in the dismiss
    // completion so the presentation chain is clean before the parent acts.
    [UIView animateWithDuration:0.25 animations:^{
        self.cardView.alpha = 0.0;
    } completion:^(BOOL finished) {
        NSLog(@"[Auth][OTP] Verification step completed. forwarding success=%@ currentUID=%@ navigationDepth=%lu",
              successCallback ? @"YES" : @"NO",
              PPVerificationSafeUIDForLog([FIRAuth auth].currentUser),
              (unsigned long)self.navigationController.viewControllers.count);
        if (successCallback) {
            successCallback(authResult);
        }
    }];
}


- (void)setLoadingState:(BOOL)loading {
    self.continueButton.enabled = !loading && !self.isRequestingResend && (self.codeField.text.length == 6);
    self.codeField.enabled = !loading;
    [PPAuthScaffoldView applyPrimaryButtonStyleToButton:self.continueButton enabled:self.continueButton.enabled loading:loading];

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = self.continueButton.configuration;
        if (loading) {
            UIActivityIndicatorView *indicator =
                [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
            [indicator startAnimating];

            config.showsActivityIndicator = YES;
        } else {
            config.showsActivityIndicator = NO;
        }
        self.continueButton.configuration = config;
    }
}

- (void)animateVerificationEntranceIfNeeded {
    if (self.didAnimateEntrance) {
        return;
    }
    self.didAnimateEntrance = YES;

    NSArray<UIView *> *views = @[
        self.stepIndicatorView ?: UIView.new,
        self.cardView ?: UIView.new,
        self.backButton ?: UIView.new,
        self.titleLabel ?: UIView.new,
        self.subtitleLabel ?: UIView.new,
        self.changeNumberButton ?: UIView.new,
        self.digitStackView ?: UIView.new,
        self.continueButton ?: UIView.new,
        self.resendButton ?: UIView.new
    ];

    [views enumerateObjectsUsingBlock:^(UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 16.0);
        [UIView animateWithDuration:0.50
                              delay:0.04 * idx
             usingSpringWithDamping:0.88
              initialSpringVelocity:0.16
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
        (void)stop;
    }];
}

@end
