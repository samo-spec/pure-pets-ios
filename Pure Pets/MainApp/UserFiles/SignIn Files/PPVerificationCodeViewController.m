//
//  PPVerificationPromptViewController 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 18/11/2025.
//

#import "PPVerificationCodeViewController.h"
#import "Language.h"

@interface PPVerificationCodeViewController () <UITextFieldDelegate, UIGestureRecognizerDelegate, UIAdaptivePresentationControllerDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
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

@property (nonatomic, assign) NSInteger remainingSeconds;
@property (nonatomic, strong) NSTimer *timer;

@property (nonatomic, copy) NSString *phone;
@property (nonatomic, assign) BOOL isVerifyingCode;
@property (nonatomic, assign) BOOL isRequestingResend;
@property (nonatomic, assign) BOOL didAnimateEntrance;

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
    self.view.backgroundColor = PPBackgroundColorForIOS26([AppBackgroundClr colorWithAlphaComponent:0.95]);
    self.modalInPresentation = YES;
    self.presentationController.delegate = self;

    [self setupBackgroundDecorations];
    [self setupScroll];
    [self setupCard];
    [self setupTexts];
    [self setupOTPField];
    [self setupButtons];
    [self setupConstraints];
    [self registerKeyboardNotifications];

    [self startTimer];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(300 * NSEC_PER_MSEC)),
                   dispatch_get_main_queue(), ^{
        [self.codeField becomeFirstResponder];
    });

    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.modalInPresentation = YES;
    self.presentationController.delegate = self;
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
    self.backgroundTopGlowView = [[UIView alloc] initWithFrame:CGRectZero];
    self.backgroundTopGlowView.userInteractionEnabled = NO;
    [self.view addSubview:self.backgroundTopGlowView];

    self.backgroundBottomGlowView = [[UIView alloc] initWithFrame:CGRectZero];
    self.backgroundBottomGlowView.userInteractionEnabled = NO;
    [self.view addSubview:self.backgroundBottomGlowView];
}

- (void)setupScroll {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:self.scrollView];
    [self.scrollView addSubview:self.contentView];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor]
    ]];
}

- (void)setupCard {
    self.cardView = [[UIView alloc] init];
    self.cardView.layer.cornerRadius = 32;
    self.cardView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.56 : 0.96];
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardView.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusField)];
    tap.delegate = self;
    [self.cardView addGestureRecognizer:tap];
    [self.contentView addSubview:self.cardView];
}

- (void)setupTexts {
    self.heroIconWrapView = [[UIView alloc] init];
    self.heroIconWrapView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroIconWrapView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:PPIOS26() ? 0.18 : 0.12];
    self.heroIconWrapView.layer.cornerRadius = 28.0;
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

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = kLang(@"verification_title");
    self.titleLabel.font =  [GM boldFontWithSize:26];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.textColor = UIColor.labelColor;

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.text =
        [NSString stringWithFormat:kLang(@"verification_sent_to"), self.phone];
    self.subtitleLabel.font = [GM MidFontWithSize:15];
    self.subtitleLabel.textColor = UIColor.secondaryLabelColor;
    self.subtitleLabel.numberOfLines = 0;
    self.subtitleLabel.textAlignment = NSTextAlignmentCenter;
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
    self.instructionLabel.font = [GM MidFontWithSize:13];
    self.instructionLabel.textAlignment = NSTextAlignmentCenter;
    self.instructionLabel.textColor = UIColor.tertiaryLabelColor;

    [self.cardView addSubview:self.titleLabel];
    [self.cardView addSubview:self.subtitleLabel];
    [self.cardView addSubview:self.instructionLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroIconWrapView.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:22],
        [self.heroIconWrapView.centerXAnchor constraintEqualToAnchor:self.cardView.centerXAnchor],
        [self.heroIconWrapView.widthAnchor constraintEqualToConstant:56],
        [self.heroIconWrapView.heightAnchor constraintEqualToConstant:56],
        [self.heroIconView.centerXAnchor constraintEqualToAnchor:self.heroIconWrapView.centerXAnchor],
        [self.heroIconView.centerYAnchor constraintEqualToAnchor:self.heroIconWrapView.centerYAnchor],
        [self.heroIconView.widthAnchor constraintEqualToConstant:24],
        [self.heroIconView.heightAnchor constraintEqualToConstant:24]
    ]];
}

- (void)setupOTPField {
    self.codeField = [[UITextField alloc] init];
     
    self.codeField.textContentType = UITextContentTypeOneTimeCode;
    self.codeField.keyboardType = UIKeyboardTypeASCIICapableNumberPad;
    self.codeField.tintColor = UIColor.clearColor;
    self.codeField.textAlignment = NSTextAlignmentCenter;
    self.codeField.font =  [GM boldFontWithSize:1];
    self.codeField.placeholder = kLang(@"otp_placeholder");
    self.codeField.delegate = self;
    self.codeField.textColor = UIColor.clearColor;
    self.codeField.layer.cornerRadius = 8;
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
        digitView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:PPIOS26() ? 0.08 : 0.82];
        digitView.layer.cornerRadius = 16.0;
        digitView.layer.masksToBounds = YES;
        [digitView.heightAnchor constraintEqualToConstant:58].active = YES;

        UILabel *digitLabel = [[UILabel alloc] init];
        digitLabel.translatesAutoresizingMaskIntoConstraints = NO;
        digitLabel.font = [GM boldFontWithSize:26];
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
    config.cornerStyle = UIButtonConfigurationCornerStyleLarge;

    config.attributedTitle =
        [[NSAttributedString alloc] initWithString:kLang(@"otp_verify_button")
                                        attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:17]
                                        }];

    config.contentInsets = NSDirectionalEdgeInsetsMake(12, 12, 12, 12);
    config.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;
 
    config.cornerStyle = UIButtonConfigurationCornerStyleFixed;
    config.background.cornerRadius = 22;
    config.background.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:1.1];
    config.baseForegroundColor = AppForgroundColr;

    self.continueButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.continueButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.continueButton.configuration = config;
    self.continueButton.clipsToBounds = YES;
    self.continueButton.enabled = NO;
    self.continueButton.alpha = 0.6;

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
    self.resendButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:PPIOS26() ? 0.08 : 0.78];
    self.resendButton.layer.cornerRadius = 18.0;
    self.resendButton.layer.masksToBounds = YES;
    self.resendButton.contentEdgeInsets = UIEdgeInsetsMake(10, 16, 10, 16);
    [self.cardView addSubview:self.resendButton];
}

#pragma mark - Constraints

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:40],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-24],

        [self.backButton.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:12],
        [self.backButton.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:12],
        [self.backButton.widthAnchor constraintEqualToConstant:44],
        [self.backButton.heightAnchor constraintEqualToConstant:44],

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.heroIconWrapView.bottomAnchor constant:18],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:16],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-16],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:10],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:16],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-16],

        [self.changeNumberButton.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:2],
        [self.changeNumberButton.centerXAnchor constraintEqualToAnchor:self.cardView.centerXAnchor],

        [self.instructionLabel.topAnchor constraintEqualToAnchor:self.changeNumberButton.bottomAnchor constant:14],
        [self.instructionLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:24],
        [self.instructionLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-24],

        [self.digitStackView.topAnchor constraintEqualToAnchor:self.instructionLabel.bottomAnchor constant:24],
        [self.digitStackView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:18],
        [self.digitStackView.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-18],

        [self.codeField.topAnchor constraintEqualToAnchor:self.digitStackView.bottomAnchor constant:2],
        [self.codeField.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:30],
        [self.codeField.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-30],
        [self.codeField.heightAnchor constraintEqualToConstant:1],

        [self.continueButton.topAnchor constraintEqualToAnchor:self.digitStackView.bottomAnchor constant:28],
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
    field.text = [self normalizedOTPDigitsFromInput:field.text];

    UIImpactFeedbackGenerator *h = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [h impactOccurred];

    self.continueButton.enabled = (field.text.length == 6 && !self.isVerifyingCode && !self.isRequestingResend);
    self.continueButton.alpha = self.continueButton.enabled ? 1.0 : 0.6;
    [self refreshDigitBoxesAnimated:YES];

    if (field.text.length == 6) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(200 * NSEC_PER_MSEC)),
                       dispatch_get_main_queue(), ^{
            [self verifyPhoneCode:field.text on:self];
        });
    }

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
            [UIView animateWithDuration:0.18
                                  delay:0.0
                 usingSpringWithDamping:0.82
                  initialSpringVelocity:0.18
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                digitView.transform = CGAffineTransformIdentity;
            } completion:nil];
        }
    }
}

- (void)didTapContinue {
    if (self.codeField.text.length == 6) {
        [self verifyPhoneCode:self.codeField.text on:self];
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
                weakSelf.continueButton.enabled = NO;
                weakSelf.continueButton.alpha = 0.6;
                [weakSelf refreshDigitBoxesAnimated:NO];
                [weakSelf.codeField becomeFirstResponder];
                [weakSelf startTimer];
                return;
            }
            
            weakSelf.resendButton.enabled = YES;
            [weakSelf.resendButton setTitle:kLang(@"resend_code") forState:UIControlStateNormal];
            NSString *message = error.localizedDescription.length ? error.localizedDescription : kLang(@"Unable to resend code. Please try again.");
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
    self.continueButton.enabled = NO;
    self.continueButton.alpha = 0.6;
    [self refreshDigitBoxesAnimated:NO];

    // 💥 Keep keyboard open
    [self.codeField becomeFirstResponder];

    
}


#pragma mark - Firebase Verification

- (void)verifyPhoneCode:(NSString *)code on:(PPVerificationCodeViewController *)vc {
    if (self.isVerifyingCode || self.isRequestingResend) {
        return;
    }

    if (code.length != 6) {
        return;
    }
    
    self.isVerifyingCode = YES;

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
                        NSString *message = error.localizedDescription.length
                        ? error.localizedDescription
                        : kLang(@"StatusSaveFailed");
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

    NSString *verificationID = [[NSUserDefaults standardUserDefaults] stringForKey:@"authVerificationID"];

    if (!verificationID || verificationID.length == 0) {
        NSLog(@"❌ No verificationID stored");
        self.isVerifyingCode = NO;
        [self showInvalidCodeError];
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

        // stop loading button
        [self setLoadingState:NO];
        self.isVerifyingCode = NO;

        if (error) {
            NSLog(@"❌ Wrong code: %@", error.localizedDescription);
            [self showInvalidCodeError];
            return;
        }

        NSLog(@"Phone verification success → user logged in");
        [self handleSuccessfulAuth:authResult];
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

    // Fade out UI, then dismiss — fire the parent callback in the dismiss
    // completion so the presentation chain is clean before the parent acts.
    [UIView animateWithDuration:0.25 animations:^{
        self.cardView.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self dismissViewControllerAnimated:YES completion:^{
            if (successCallback) {
                successCallback(authResult);
            }
        }];
    }];
}


- (void)setLoadingState:(BOOL)loading {
    self.continueButton.enabled = !loading && !self.isRequestingResend && (self.codeField.text.length == 6);
    self.continueButton.alpha = self.continueButton.enabled ? 1.0 : 0.6;
    self.codeField.enabled = !loading;

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
