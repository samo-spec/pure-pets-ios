//
//  PPVerificationPromptViewController 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 18/11/2025.
//

#import "PPVerificationCodeViewController.h"

@interface PPVerificationCodeViewController () <UITextFieldDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;

@property (nonatomic, strong) UIView *cardView;

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;

@property (nonatomic, strong) UITextField *codeField;

@property (nonatomic, strong) UIButton *continueButton;
@property (nonatomic, strong) UIButton *resendButton;

@property (nonatomic, assign) NSInteger remainingSeconds;
@property (nonatomic, strong) NSTimer *timer;

@property (nonatomic, copy) NSString *phone;
@property (nonatomic, assign) BOOL isVerifyingCode;
@property (nonatomic, assign) BOOL isRequestingResend;

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

- (void)dealloc {
    [self.timer invalidate];
    self.timer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Setup UI

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
    self.cardView.layer.cornerRadius = 30;
    self.cardView.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.1];
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardView.userInteractionEnabled = YES;
    [self.contentView addSubview:self.cardView];
}

- (void)setupTexts {
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = kLang(@"verification_title");
    self.titleLabel.font =  [GM boldFontWithSize:22];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.text =
        [NSString stringWithFormat:kLang(@"verification_sent_to"), self.phone];
    self.subtitleLabel.font = [GM MidFontWithSize:15];
    self.subtitleLabel.textColor = UIColor.secondaryLabelColor;
    self.subtitleLabel.numberOfLines = 0;
    self.subtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    [self.scrollView addSubview:self.titleLabel];
    [self.scrollView addSubview:self.subtitleLabel];
}

- (void)setupOTPField {
    self.codeField = [[UITextField alloc] init];
     
    self.codeField.textContentType = UITextContentTypeOneTimeCode;
    self.codeField.keyboardType = UIKeyboardTypeASCIICapableNumberPad;
   
    self.codeField.textAlignment = NSTextAlignmentCenter;
    self.codeField.font =  [GM boldFontWithSize:32];
    self.codeField.placeholder = kLang(@"otp_placeholder");
    self.codeField.delegate = self;

    self.codeField.layer.cornerRadius = 12;
 
    self.codeField.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.05];
    [self.codeField addTarget:self action:@selector(codeChanged:) forControlEvents:UIControlEventEditingChanged];
    self.codeField.translatesAutoresizingMaskIntoConstraints = NO;

    [self.scrollView addSubview:self.codeField];
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
        [[NSAttributedString alloc] initWithString:kLang(@"continue_button")
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

    [self.continueButton addTarget:self
                            action:@selector(didTapContinue)
                  forControlEvents:UIControlEventTouchUpInside];

    [self.scrollView addSubview:self.continueButton];

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
    [self.scrollView addSubview:self.resendButton];
}

#pragma mark - Constraints

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:36],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:26],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-26],

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:25],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:16],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-16],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:10],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:16],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-16],

        [self.codeField.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:30],
        [self.codeField.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:40],
        [self.codeField.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-40],
        [self.codeField.heightAnchor constraintEqualToConstant:55],

        [self.continueButton.topAnchor constraintEqualToAnchor:self.codeField.bottomAnchor constant:30],
        [self.continueButton.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:16],
        [self.continueButton.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-16],
        [self.continueButton.heightAnchor constraintEqualToConstant:50],

        [self.resendButton.topAnchor constraintEqualToAnchor:self.continueButton.bottomAnchor constant:20],
        [self.resendButton.centerXAnchor constraintEqualToAnchor:self.cardView.centerXAnchor],
        [self.resendButton.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-20]
    ]];
}

#pragma mark - OTP Logic

- (void)codeChanged:(UITextField *)field {
    if (field.text.length > 6)
        field.text = [field.text substringToIndex:6];

    UIImpactFeedbackGenerator *h = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [h impactOccurred];

    self.continueButton.enabled = (field.text.length == 6 && !self.isVerifyingCode && !self.isRequestingResend);

    if (field.text.length == 6) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(200 * NSEC_PER_MSEC)),
                       dispatch_get_main_queue(), ^{
            [self verifyPhoneCode:field.text on:self];
        });
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

#pragma mark - Focus

- (void)focusField {
    [self.codeField becomeFirstResponder];
}


-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self.view bringSubviewToFront:self.scrollView];
    [self.scrollView sendSubviewToBack:self.cardView];
    [self.scrollView bringSubviewToFront:self.codeField];
    [self.scrollView bringSubviewToFront:self.continueButton];
    
     
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.scrollView.canCancelContentTouches = NO;
    
    [Styling addLiquidGlassBorderToView:self.cardView cornerRadius:30];

}

-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    [self.scrollView sendSubviewToBack:self.cardView];
    [self.scrollView bringSubviewToFront:self.codeField];
    [self.scrollView bringSubviewToFront:self.continueButton];
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
    [self.codeField.layer addAnimation:shake forKey:@"shake"];
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

        NSLog(@"🔥 Phone verification success → user logged in");
        [self handleSuccessfulAuth:authResult];
    }];
}

#pragma mark - Success Handling

- (void)handleSuccessfulAuth:(FIRAuthDataResult *)authResult {

    // Haptic
    UINotificationFeedbackGenerator *gen = [[UINotificationFeedbackGenerator alloc] init];
    [gen notificationOccurred:UINotificationFeedbackTypeSuccess];

    // Callback to parent VC
    if (self.onAuthResultSuccess) {
        self.onAuthResultSuccess(authResult);
    }

    // Fade out UI
    [UIView animateWithDuration:0.25 animations:^{
        self.cardView.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
}


- (void)setLoadingState:(BOOL)loading {
    self.continueButton.enabled = !loading && !self.isRequestingResend && (self.codeField.text.length == 6);
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

@end
