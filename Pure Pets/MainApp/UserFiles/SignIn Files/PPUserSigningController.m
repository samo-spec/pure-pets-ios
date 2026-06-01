//
//  PPUserSigningController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 17/11/2025.
//


#import "PPUserSigningController.h"
#import "CitiesManager.h"
#import "CountryModel.h"

static NSString * const kPPUsersCollection = @"UsersCol";
static NSString * const kPPDefaultsAuthVerificationIDKey = @"authVerificationID";
static NSString * const kPPDefaultsUserTokenKey = @"PPUserTokenID";
static NSString * const kPPFirestoreUserNameField = @"UserName";
static NSString * const kPPSheetCustomMediumDetentIdentifier = @"pp_auth_custom_medium";
static NSUInteger const kPPMinimumPhoneDigits = 6;
static NSTimeInterval const kPPSMSCooldownSeconds = 30.0;
static NSInteger const kPPAppleSignInMaxRetryCount = 1;
static NSInteger const kPPGoogleSignInConfigMissingCode = 1010;
static NSString * const kPPGoogleSignInClientIDKey = @"GIDClientID";
static NSString * const kPPGoogleSignInServerClientIDKey = @"GIDServerClientID";
static NSString * const kPPGoogleClientIDSuffix = @".apps.googleusercontent.com";
static NSString * const kPPGoogleReversedClientIDPrefix = @"com.googleusercontent.apps.";
static NSString * const kPPHomeNearbySelectedAreaNameDefaultsKey = @"pp.home.nearby.areaName";

#if DEBUG
#define PPAuthDebugLog(...) NSLog(__VA_ARGS__)
#else
#define PPAuthDebugLog(...)
#endif

static inline void PPDispatchMain(void (^block)(void)) {
    if (!block) {
        return;
    }
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

@interface PPUserSigningController () <ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding, UITextFieldDelegate>

#pragma mark - UI Components
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *containerStack;
@property (nonatomic, strong) UIView *backgroundView;
@property (nonatomic, strong) UIView *backgroundTopGlowView;
@property (nonatomic, strong) UIView *backgroundBottomGlowView;
@property (nonatomic, strong) UIView *phoneSectionCard;
@property (nonatomic, strong) UIView *socialSectionCard;
@property (nonatomic, strong) UILabel *phoneLiveLabel;
@property (nonatomic, strong) UIView *heroBadgeView;
@property (nonatomic, strong) UIImageView *heroBadgeIconView;
@property (nonatomic, strong) UILabel *heroBadgeLabel;

// Header
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;

// Phone Auth
@property (nonatomic, strong) UIStackView *phoneStack;
@property (nonatomic, strong) UIButton *countryCodePickerBtn;
@property (nonatomic, strong) UITextField *phoneNumberField;
@property (nonatomic, strong) UIButton *continuePhoneButton;

// Social Auth
@property (nonatomic, strong) UIView *separatorView;
@property (nonatomic, strong) UIButton *appleSignInButton;
@property (nonatomic, strong) UIButton *googleSignInButton;
@property (nonatomic, strong) UIButton *closeButton;

#pragma mark - State
@property (nonatomic, strong) NSString *verificationID;
@property (nonatomic, strong) NSString *currentNonce;
@property (nonatomic, strong) NSString *currentPhoneCode;
@property (nonatomic, strong, nullable) CountryCodeModel *autoDetectedCountry;
@property (nonatomic, strong) NSString *normalizedPhoneDigits;
@property (nonatomic, assign) BOOL isKeyboardVisible;
@property (nonatomic, assign) BOOL keyboardObserversRegistered;
@property (nonatomic, assign) BOOL shouldFocusPhoneFieldOnAppear;
@property (nonatomic, assign) BOOL isAuthenticating;
@property (nonatomic, assign) NSInteger appleSignInRetryCount;
@property (nonatomic, assign) NSInteger phoneCooldownRemaining;
@property (nonatomic, strong, nullable) NSTimer *phoneCooldownTimer;
@property (nonatomic, strong, nullable) NSArray *savedSheetDetents;
@property (nonatomic, strong) CAGradientLayer *layer;
@property (nonatomic, assign) BOOL didRunEntranceAnimation;
@property (nonatomic, assign) BOOL didStartAmbientGlowAnimation;
@end

@implementation PPUserSigningController

#pragma mark - Initialization

- (instancetype)initWithPresentationStyle:(PPUserSigningPresentationStyle)style {
    self = [super init];
    if (self) {
        _presentationStyle = style;
        _defaultCountryCode = @"+974";
        _shouldAutoDismissOnSuccess = YES;
        _shouldCreateUserDocument = YES;
    }
    return self;
}

- (instancetype)init {
    return [self initWithPresentationStyle:PPUserSigningPresentationStyleSheet];
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupView];
    [self setupConstraints];
    self.shouldFocusPhoneFieldOnAppear = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.view layoutSubviews];
    [self startAmbientGlowAnimationsIfNeeded];
    [self animateAuthEntranceIfNeeded];
    if (self.shouldFocusPhoneFieldOnAppear) {
        self.shouldFocusPhoneFieldOnAppear = NO;
        //[self.phoneNumberField becomeFirstResponder];
    }
}

- (void)dealloc {
    [self.phoneCooldownTimer invalidate];
    self.phoneCooldownTimer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Setup

- (void)setupView {
    // Configure main view

    
    // Setup background with blur effect
    [self setupBackground];
    [self setupAmbientBackground];
    
    // Configure modal presentation
    [self configureModalPresentation];
    
    // Create UI hierarchy
    [self createUI];
}

- (void)setupBackground {
    if (@available(iOS 26.0, *))
    {
        self.view.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.5];
    }
    else if (@available(iOS 15.0, *)) {
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.frame = self.view.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blurView.alpha = 0.92;
        [self.view addSubview:blurView];
        self.backgroundView = blurView;
    } else {
        self.view.backgroundColor = PPBackgroundColorForIOS26([UIColor systemBackgroundColor]);
    }
}

- (void)setupAmbientBackground {
    self.backgroundTopGlowView = [[UIView alloc] initWithFrame:CGRectZero];
    self.backgroundTopGlowView.userInteractionEnabled = NO;
    self.backgroundTopGlowView.alpha = 0.94;
    [self.view addSubview:self.backgroundTopGlowView];

    self.backgroundBottomGlowView = [[UIView alloc] initWithFrame:CGRectZero];
    self.backgroundBottomGlowView.userInteractionEnabled = NO;
    self.backgroundBottomGlowView.alpha = 0.82;
    [self.view addSubview:self.backgroundBottomGlowView];
}

- (void)configureModalPresentation {
    CGFloat height = UIScreen.mainScreen.bounds.size.height;
    
    UISheetPresentationControllerDetent *customMedium = [UISheetPresentationControllerDetent mediumDetent];
    if (@available(iOS 16.0, *)) {
        customMedium = [UISheetPresentationControllerDetent customDetentWithIdentifier:kPPSheetCustomMediumDetentIdentifier
                                                                              resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
            return height * 0.80; // your custom medium height
        }];
    } else {
        // Fallback on earlier versions
    }
    switch (self.presentationStyle) {
        case PPUserSigningPresentationStyleSheet:
            if (@available(iOS 15.0, *)) {
                self.modalPresentationStyle = UIModalPresentationPageSheet;
                UISheetPresentationController *sheet = self.sheetPresentationController;
                sheet.detents = @[customMedium];
                sheet.prefersGrabberVisible = YES;
                sheet.preferredCornerRadius = 42.0;
                sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
                if (@available(iOS 16.0, *)) {
                    sheet.selectedDetentIdentifier = kPPSheetCustomMediumDetentIdentifier;
                }
                
            } else {
                self.modalPresentationStyle = UIModalPresentationFormSheet;
                self.modalInPresentation  = NO;
            }
            break;
            
        case PPUserSigningPresentationStyleFullScreen:
            self.modalPresentationStyle = UIModalPresentationFullScreen;
            break;
    }
    self.modalInPresentation  = NO;
}

- (void)createUI {
    // Scroll View
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.scrollEnabled = YES;
    self.scrollView.alwaysBounceVertical = NO;
    self.scrollView.backgroundColor = UIColor.clearColor;
    [self.view addSubview:self.scrollView];
    
    // Container Stack
    self.containerStack = [[UIStackView alloc] init];
    self.containerStack.axis = UILayoutConstraintAxisVertical;
    self.containerStack.spacing = 20;
    self.containerStack.alignment = UIStackViewAlignmentFill;
    self.containerStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.containerStack];
    
    // Header
    [self setupHeader];
    
    // Phone Auth Section
    [self setupPhoneAuthSection];
    
    // Separator
    [self setupSeparator];
    
    // Social Auth Section
    [self setupSocialAuthSection];
    
    // Close Button
    [self setupCloseButton];
}



- (void)setupHeader {
    UIStackView *headerStack = [[UIStackView alloc] init];
    headerStack.axis = UILayoutConstraintAxisVertical;
    headerStack.spacing = 12;
    headerStack.alignment = UIStackViewAlignmentCenter;

    self.heroBadgeView = [[UIView alloc] initWithFrame:CGRectZero];
    self.heroBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroBadgeView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:PPIOS26() ? 0.16 : 0.74];
    self.heroBadgeView.layer.cornerRadius = 20.0;
    self.heroBadgeView.layer.masksToBounds = YES;

    self.heroBadgeIconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"sparkles"]];
    self.heroBadgeIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroBadgeIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.heroBadgeIconView.tintColor = AppPrimaryClr;
    [self.heroBadgeView addSubview:self.heroBadgeIconView];

    self.heroBadgeLabel = [[UILabel alloc] init];
    self.heroBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroBadgeLabel.text = kLang(@"auth_phone_live_hint");
    self.heroBadgeLabel.font = [GM boldFontWithSize:13];
    self.heroBadgeLabel.textColor = UIColor.labelColor;
    [self.heroBadgeView addSubview:self.heroBadgeLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroBadgeIconView.leadingAnchor constraintEqualToAnchor:self.heroBadgeView.leadingAnchor constant:12],
        [self.heroBadgeIconView.centerYAnchor constraintEqualToAnchor:self.heroBadgeView.centerYAnchor],
        [self.heroBadgeIconView.widthAnchor constraintEqualToConstant:14],
        [self.heroBadgeIconView.heightAnchor constraintEqualToConstant:14],
        [self.heroBadgeLabel.leadingAnchor constraintEqualToAnchor:self.heroBadgeIconView.trailingAnchor constant:8],
        [self.heroBadgeLabel.trailingAnchor constraintEqualToAnchor:self.heroBadgeView.trailingAnchor constant:-14],
        [self.heroBadgeLabel.topAnchor constraintEqualToAnchor:self.heroBadgeView.topAnchor constant:10],
        [self.heroBadgeLabel.bottomAnchor constraintEqualToAnchor:self.heroBadgeView.bottomAnchor constant:-10]
    ]];
    
    // Title Label
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = kLang(@"auth_title_welcome");
    self.titleLabel.font = [GM boldFontWithSize:32];
    self.titleLabel.textColor = [UIColor labelColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.numberOfLines = 0;
    
    // Subtitle Label
    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.text = kLang(@"auth_subtitle_continue");
    self.subtitleLabel.font = [GM MidFontWithSize:16];
    self.subtitleLabel.textColor = [UIColor secondaryLabelColor];
    self.subtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.subtitleLabel.numberOfLines = 0;
    self.subtitleLabel.alpha = 0.92;
    
    [headerStack addArrangedSubview:self.heroBadgeView];
    [headerStack addArrangedSubview:self.titleLabel];
    [headerStack addArrangedSubview:self.subtitleLabel];
    [self.containerStack addArrangedSubview:headerStack];
}


- (void)pp_applyBelowIOS26PhoneFallbackChrome {
    if (@available(iOS 26.0, *)) {
        return;
    }

    CGFloat controlCornerRadius = 22.0;
    UIColor *fieldBackground = [AppForgroundColr colorWithAlphaComponent:0.98];
    UIColor *subtleBorder = [AppPrimaryClr colorWithAlphaComponent:0.16];

    if (self.phoneSectionCard) {
        self.phoneSectionCard.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.98];
        self.phoneSectionCard.layer.cornerRadius = 28.0;
        self.phoneSectionCard.layer.borderWidth = 1.0;
        self.phoneSectionCard.layer.borderColor = [AppPrimaryClr colorWithAlphaComponent:0.08].CGColor;
        self.phoneSectionCard.layer.masksToBounds = YES;
    }

    if (self.socialSectionCard) {
        self.socialSectionCard.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.98];
        self.socialSectionCard.layer.cornerRadius = 26.0;
        self.socialSectionCard.layer.borderWidth = 1.0;
        self.socialSectionCard.layer.borderColor = [AppPrimaryClr colorWithAlphaComponent:0.07].CGColor;
        self.socialSectionCard.layer.masksToBounds = YES;
    }

    if (self.heroBadgeView) {
        self.heroBadgeView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.92];
        self.heroBadgeView.layer.cornerRadius = 20.0;
        self.heroBadgeView.layer.borderWidth = 1.0;
        self.heroBadgeView.layer.borderColor = [AppPrimaryClr colorWithAlphaComponent:0.08].CGColor;
        self.heroBadgeView.layer.masksToBounds = YES;
    }

    if (self.countryCodePickerBtn) {
        UIButtonConfiguration *config = self.countryCodePickerBtn.configuration;
        config.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        config.background.backgroundColor = fieldBackground;
        config.background.cornerRadius = controlCornerRadius;
        config.baseForegroundColor = AppPrimaryClr;
        config.contentInsets = NSDirectionalEdgeInsetsMake(0, 12, 0, 12);
        config.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;
        self.countryCodePickerBtn.configuration = config;
        self.countryCodePickerBtn.backgroundColor = fieldBackground;
        self.countryCodePickerBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        self.countryCodePickerBtn.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
        self.countryCodePickerBtn.layer.cornerRadius = controlCornerRadius;
        self.countryCodePickerBtn.layer.borderWidth = 1.0;
        self.countryCodePickerBtn.layer.borderColor = subtleBorder.CGColor;
        self.countryCodePickerBtn.layer.masksToBounds = YES;
        self.countryCodePickerBtn.titleLabel.adjustsFontSizeToFitWidth = YES;
        self.countryCodePickerBtn.titleLabel.minimumScaleFactor = 0.82;
    }

    if (self.phoneNumberField) {
        self.phoneNumberField.backgroundColor = fieldBackground;
        self.phoneNumberField.layer.cornerRadius = controlCornerRadius;
        self.phoneNumberField.layer.borderWidth = 1.0;
        self.phoneNumberField.layer.borderColor = subtleBorder.CGColor;
        self.phoneNumberField.layer.masksToBounds = YES;
    }

    if (self.continuePhoneButton) {
        BOOL enabled = self.continuePhoneButton.enabled;
        UIColor *buttonBackground = enabled ? AppPrimaryClr : [AppPrimaryClr colorWithAlphaComponent:0.10];
        UIColor *buttonTextColor = enabled ? UIColor.whiteColor : [AppPrimaryClr colorWithAlphaComponent:0.64];
        UIButtonConfiguration *config = self.continuePhoneButton.configuration;
        config.background.backgroundColor = buttonBackground;
        config.background.cornerRadius = controlCornerRadius;
        config.baseForegroundColor = buttonTextColor;
        config.contentInsets = NSDirectionalEdgeInsetsMake(0, 18, 0, 18);
        config.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;
        self.continuePhoneButton.configuration = config;
        self.continuePhoneButton.backgroundColor = buttonBackground;
        self.continuePhoneButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        self.continuePhoneButton.layer.cornerRadius = controlCornerRadius;
        self.continuePhoneButton.layer.borderWidth = enabled ? 0.0 : 1.0;
        self.continuePhoneButton.layer.borderColor = [AppPrimaryClr colorWithAlphaComponent:0.28].CGColor;
        self.continuePhoneButton.layer.masksToBounds = YES;
        self.continuePhoneButton.alpha = 1.0;
    }

    if (self.closeButton) {
        self.closeButton.layer.cornerRadius = 22.0;
        self.closeButton.layer.borderWidth = 1.0;
        self.closeButton.layer.borderColor = [AppPrimaryClr colorWithAlphaComponent:0.08].CGColor;
        self.closeButton.layer.masksToBounds = YES;
    }
}



-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    
    UIButtonConfiguration *config = self.countryCodePickerBtn.configuration;
    UIButtonConfiguration *continuePhoneButtonConfig = self.continuePhoneButton.configuration;
    if (@available(iOS 26.0, *)) {
        config.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        config.background.cornerRadius = 18;
        config.background.backgroundColor =  AppBackgroundClrLigter;
        
        self.countryCodePickerBtn.layer.cornerRadius = 18;
        self.countryCodePickerBtn.clipsToBounds = YES;
        
        
        [self.countryCodePickerBtn setConfiguration:config];
        [self.countryCodePickerBtn updateConfiguration];
        
        continuePhoneButtonConfig.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        continuePhoneButtonConfig.background.cornerRadius = 18;
        
        
        continuePhoneButtonConfig.background
            .backgroundColor =  [AppPrimaryClr colorWithAlphaComponent:1.0];
        
        [self.continuePhoneButton setConfiguration:continuePhoneButtonConfig];
        [self.continuePhoneButton updateConfiguration];
        [self setContinuePhoneButtonTitle:self.phoneCooldownRemaining > 0 ? [NSString stringWithFormat:@"%@ (%lds)", kLang(@"Continue with Mobile"), (long)self.phoneCooldownRemaining] : kLang(@"Continue with Mobile")];
        
    } else {
        [self pp_applyBelowIOS26PhoneFallbackChrome];
    }
    
    //[Styling addLiquidGlassBorderToView:self.continuePhoneButton cornerRadius:20];
    
    [self.countryCodePickerBtn setNeedsLayout];
    [self.countryCodePickerBtn layoutIfNeeded];
    [self pp_applyCountryCodeToButton:self.currentPhoneCode];
    if (!self.keyboardObserversRegistered) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillShow:)
                                                     name:UIKeyboardWillShowNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillHide:)
                                                     name:UIKeyboardWillHideNotification
                                                   object:nil];
        self.keyboardObserversRegistered = YES;
    }
    [self updateContinuePhoneButtonState];
    
}



-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [PPHUD dismiss];
    if (self.keyboardObserversRegistered) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
        self.keyboardObserversRegistered = NO;
    }
    [self unlockSheetDetentAfterKeyboard];
}

-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat height = CGRectGetHeight(self.view.bounds);
    CGFloat topGlowSize = MIN(240.0, width * 0.56);
    CGFloat bottomGlowSize = MIN(220.0, width * 0.52);

    self.backgroundTopGlowView.frame = CGRectMake(-48.0,
                                                  self.view.safeAreaInsets.top - 30.0,
                                                  topGlowSize,
                                                  topGlowSize);
    self.backgroundBottomGlowView.frame = CGRectMake(width - bottomGlowSize + 44.0,
                                                     MAX(self.view.safeAreaInsets.top + 220.0, height * 0.42),
                                                     bottomGlowSize,
                                                     bottomGlowSize);
    self.backgroundTopGlowView.layer.cornerRadius = topGlowSize * 0.5;
    self.backgroundBottomGlowView.layer.cornerRadius = bottomGlowSize * 0.5;
    self.backgroundTopGlowView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:PPIOS26() ? 0.18 : 0.12];
    self.backgroundBottomGlowView.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:PPIOS26() ? 0.12 : 0.08];

    if (@available(iOS 26.0, *)) {
        if (self.heroBadgeView) {
            [Styling addLiquidGlassBorderToView:self.heroBadgeView cornerRadius:20 color:[AppBackgroundClr colorWithAlphaComponent:0.20]];
        }
        if (self.phoneSectionCard) {
            [Styling addLiquidGlassBorderToView:self.phoneSectionCard cornerRadius:28 color:[AppBackgroundClr colorWithAlphaComponent:0.18]];
        }
        if (self.socialSectionCard) {
            [Styling addLiquidGlassBorderToView:self.socialSectionCard cornerRadius:26 color:[AppBackgroundClr colorWithAlphaComponent:0.16]];
        }
    } else {
        [self pp_applyBelowIOS26PhoneFallbackChrome];
    }
    if (self.appleSignInButton) {
         self.appleSignInButton.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.appleSignInButton.bounds cornerRadius:20.0].CGPath;
    }
    if (self.googleSignInButton) {
         self.googleSignInButton.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.googleSignInButton.bounds cornerRadius:20.0].CGPath;
    }
    if (@available(iOS 26.0, *)) {
        if (self.countryCodePickerBtn) {
            [Styling addLiquidGlassBorderToView:self.countryCodePickerBtn cornerRadius:18 color:[[UIColor whiteColor] colorWithAlphaComponent:0.18]];
        }
        if (self.phoneNumberField) {
            [Styling addLiquidGlassBorderToView:self.phoneNumberField cornerRadius:18 color:[[UIColor whiteColor] colorWithAlphaComponent:0.86]];
        }
        if (self.continuePhoneButton) {
            [Styling addLiquidGlassBorderToView:self.continuePhoneButton cornerRadius:18 color:[[UIColor whiteColor] colorWithAlphaComponent:0.10]];
        }
        if (self.closeButton) {
            [Styling addLiquidGlassBorderToView:self.closeButton cornerRadius:18 color:[[UIColor whiteColor] colorWithAlphaComponent:0.12]];
        }
    }
}

- (void)showPickerSheetWithData:(NSMutableArray *)data {
    
    __weak typeof(self) w = self;
    PPSelectOptionViewController *vc = [[PPSelectOptionViewController alloc] initWithOptions:data title:@"" row:nil presentationStyle:PPSelectOptionPresentationSheet completion:^(id  _Nullable selectedObject) {
        PPDispatchMain(^{
            if (![selectedObject isKindOfClass:[CountryCodeModel class]]) {
                return;
            }
            CountryCodeModel *selectedCountry = (CountryCodeModel *)selectedObject;
            NSString *safePhoneCode = selectedCountry.phoneCode.length
            ? selectedCountry.phoneCode
            : (w.currentPhoneCode.length ? w.currentPhoneCode : w.defaultCountryCode);
            if (safePhoneCode.length == 0) {
                return;
            }
            w.autoDetectedCountry = selectedCountry;
            self.currentPhoneCode = safePhoneCode;
            [w pp_applyCountryCodeToButton:safePhoneCode];
            [w.countryCodePickerBtn setNeedsLayout];
            [w.countryCodePickerBtn layoutIfNeeded];
            [w refreshPhoneLiveState];
        });
        
    }];
    vc.optionCellBackgroundColor = UIColor.secondarySystemBackgroundColor;
    [self presentViewController:vc animated:YES completion:nil];
    
}



- (void)showCountries
{
    NSMutableArray<CountryCodeModel *> *countries =
        [GM getMiddleEastCountriesForLanguage:[Language currentLanguageCode]];
    if (countries.count == 0) {
        return;
    }
    [self showPickerSheetWithData:countries];
}

- (void)setupPhoneAuthSection {
    // Country Code Field
    
    UIButtonConfiguration *glassConfig;
    if (@available(iOS 26.0, *)) {
        glassConfig = [UIButtonConfiguration clearGlassButtonConfiguration];
    } else {
        glassConfig = [UIButtonConfiguration filledButtonConfiguration];
    }
    NSArray<CountryCodeModel *> *countries = [GM getMiddleEastCountriesForLanguage:[Language currentLanguageCode]];
    self.autoDetectedCountry = [self pp_resolveAutomaticCountryFromCountries:countries];
    NSString *resolvedPhoneCode = self.autoDetectedCountry.phoneCode.length
    ? self.autoDetectedCountry.phoneCode
    : [self normalizedCountryCode:self.defaultCountryCode];
    self.currentPhoneCode = [self normalizedCountryCode:resolvedPhoneCode];

    self.countryCodePickerBtn = [PPButtonHelper pp_buttonWithTitle:self.currentPhoneCode font:[GM boldFontWithSize:18] textColor:AppPrimaryClr corners:18 imageName:@"" target:self config:glassConfig btnSize:56 action:@selector(showCountries)];
    self.countryCodePickerBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:PPIOS26() ? 0.12 : 0.78];
    self.countryCodePickerBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    [self.countryCodePickerBtn.widthAnchor constraintEqualToConstant:118].active = YES;
    
    
    // Phone Number Field
    self.phoneNumberField = [self createGlassTextField];
    self.phoneNumberField.placeholder = kLang(@"mobileNoField");
    self.phoneNumberField.keyboardType = UIKeyboardTypeASCIICapableNumberPad;
    self.phoneNumberField.backgroundColor = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.10 : 0.94];
    self.phoneNumberField.delegate = self;
    [self.phoneNumberField addTarget:self action:@selector(handlePhoneFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    // Keep international number entry physical order stable across languages.
    self.phoneStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.countryCodePickerBtn, self.phoneNumberField]];
    self.phoneStack.axis = UILayoutConstraintAxisHorizontal;
    self.phoneStack.spacing = 10;
    self.phoneStack.distribution = UIStackViewDistributionFill;
    self.phoneStack.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    
    // Continue Button
    self.continuePhoneButton = [PPButtonHelper pp_buttonWithTitle:kLang(@"Continue with Mobile") font:[GM boldFontWithSize:17] textColor:[AppForgroundColr colorWithAlphaComponent:1.0] corners:18 imageName:@"" target:self config:glassConfig btnSize:56 action:@selector(handlePhoneSignIn)];
    self.continuePhoneButton.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:1.0];
    [self setContinuePhoneButtonTitle:kLang(@"Continue with Mobile")];
    [self pp_addPressAnimationToButton:self.continuePhoneButton];

    UILabel *phoneSectionTitleLabel = [[UILabel alloc] init];
    phoneSectionTitleLabel.text = kLang(@"login_with_phone");
    phoneSectionTitleLabel.font = [GM boldFontWithSize:18];
    phoneSectionTitleLabel.textColor = UIColor.labelColor;
    phoneSectionTitleLabel.textAlignment = NSTextAlignmentNatural;

    self.phoneLiveLabel = [[UILabel alloc] init];
    self.phoneLiveLabel.font = [GM MidFontWithSize:14];
    self.phoneLiveLabel.textColor = UIColor.secondaryLabelColor;
    self.phoneLiveLabel.numberOfLines = 0;
    self.phoneLiveLabel.textAlignment = NSTextAlignmentNatural;

    UIStackView *phoneSectionStack = [[UIStackView alloc] initWithArrangedSubviews:@[phoneSectionTitleLabel, self.phoneStack, self.phoneLiveLabel, self.continuePhoneButton]];
    phoneSectionStack.axis = UILayoutConstraintAxisVertical;
    phoneSectionStack.spacing = 14;
    phoneSectionStack.translatesAutoresizingMaskIntoConstraints = NO;

    self.phoneSectionCard = [[UIView alloc] initWithFrame:CGRectZero];
    self.phoneSectionCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.phoneSectionCard.backgroundColor = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.54 : 0.98];
    self.phoneSectionCard.layer.cornerRadius = 28.0;
    self.phoneSectionCard.layer.masksToBounds = YES;
    [self.phoneSectionCard addSubview:phoneSectionStack];
    [self.containerStack addArrangedSubview:self.phoneSectionCard];

    [NSLayoutConstraint activateConstraints:@[
        [phoneSectionStack.topAnchor constraintEqualToAnchor:self.phoneSectionCard.topAnchor constant:20],
        [phoneSectionStack.leadingAnchor constraintEqualToAnchor:self.phoneSectionCard.leadingAnchor constant:18],
        [phoneSectionStack.trailingAnchor constraintEqualToAnchor:self.phoneSectionCard.trailingAnchor constant:-18],
        [phoneSectionStack.bottomAnchor constraintEqualToAnchor:self.phoneSectionCard.bottomAnchor constant:-18]
    ]];

    [self refreshPhoneLiveState];
    
}


- (void)setupSeparator {
    UIView *separatorContainer = [[UIView alloc] init];
    separatorContainer.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *leadingLine = [[UIView alloc] init];
    leadingLine.translatesAutoresizingMaskIntoConstraints = NO;
    leadingLine.backgroundColor = [[UIColor separatorColor] colorWithAlphaComponent:0.72];

    UIView *trailingLine = [[UIView alloc] init];
    trailingLine.translatesAutoresizingMaskIntoConstraints = NO;
    trailingLine.backgroundColor = [[UIColor separatorColor] colorWithAlphaComponent:0.72];

    UILabel *separatorLabel = [[UILabel alloc] init];
    separatorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    separatorLabel.text = kLang(@"auth_alt_methods_title");
    separatorLabel.font = [GM MidFontWithSize:13];
    separatorLabel.textColor = UIColor.tertiaryLabelColor;
    separatorLabel.textAlignment = NSTextAlignmentCenter;

    [separatorContainer addSubview:leadingLine];
    [separatorContainer addSubview:separatorLabel];
    [separatorContainer addSubview:trailingLine];
    [separatorContainer.heightAnchor constraintEqualToConstant:20].active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [separatorLabel.centerXAnchor constraintEqualToAnchor:separatorContainer.centerXAnchor],
        [separatorLabel.centerYAnchor constraintEqualToAnchor:separatorContainer.centerYAnchor],
        [leadingLine.leadingAnchor constraintEqualToAnchor:separatorContainer.leadingAnchor],
        [leadingLine.trailingAnchor constraintEqualToAnchor:separatorLabel.leadingAnchor constant:-12],
        [leadingLine.centerYAnchor constraintEqualToAnchor:separatorContainer.centerYAnchor],
        [leadingLine.heightAnchor constraintEqualToConstant:1],
        [trailingLine.leadingAnchor constraintEqualToAnchor:separatorLabel.trailingAnchor constant:12],
        [trailingLine.trailingAnchor constraintEqualToAnchor:separatorContainer.trailingAnchor],
        [trailingLine.centerYAnchor constraintEqualToAnchor:separatorContainer.centerYAnchor],
        [trailingLine.heightAnchor constraintEqualToConstant:1]
    ]];

    self.separatorView = separatorContainer;
    [self.containerStack addArrangedSubview:self.separatorView];
}

- (void)setupSocialAuthSection {
    UIStackView *socialStack = [[UIStackView alloc] init];
    socialStack.axis = UILayoutConstraintAxisVertical;
    socialStack.spacing = 12;
    
    // Apple Sign In
    if (@available(iOS 13.0, *)) {
        self.appleSignInButton = [self createSocialButtonWithTitle:kLang(@"login_with_apple")
                                                          iconName:@"applelogo"
                                                         isPrimary:YES];
        [self.appleSignInButton addTarget:self action:@selector(handleAppleSignIn) forControlEvents:UIControlEventTouchUpInside];
        [socialStack addArrangedSubview:self.appleSignInButton];
    }
    
    // Google Sign In
    self.googleSignInButton = [self createSocialButtonWithTitle:kLang(@"login_with_google")
                                                       iconName:@"google2"
                                                      isPrimary:NO];
    [self.googleSignInButton addTarget:self action:@selector(handleGoogleSignIn) forControlEvents:UIControlEventTouchUpInside];
    [socialStack addArrangedSubview:self.googleSignInButton];
    
    UIStackView *socialSectionStack = [[UIStackView alloc] initWithArrangedSubviews:@[socialStack]];
    socialSectionStack.axis = UILayoutConstraintAxisVertical;
    socialSectionStack.spacing = 12.0;
    socialSectionStack.translatesAutoresizingMaskIntoConstraints = NO;

    self.socialSectionCard = [[UIView alloc] initWithFrame:CGRectZero];
    self.socialSectionCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.socialSectionCard.backgroundColor = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.50 : 0.98];
    self.socialSectionCard.layer.cornerRadius = 26.0;
    self.socialSectionCard.layer.masksToBounds = YES;
    [self.socialSectionCard addSubview:socialSectionStack];
    [self.containerStack addArrangedSubview:self.socialSectionCard];

    [NSLayoutConstraint activateConstraints:@[
        [socialSectionStack.topAnchor constraintEqualToAnchor:self.socialSectionCard.topAnchor constant:16],
        [socialSectionStack.leadingAnchor constraintEqualToAnchor:self.socialSectionCard.leadingAnchor constant:16],
        [socialSectionStack.trailingAnchor constraintEqualToAnchor:self.socialSectionCard.trailingAnchor constant:-16],
        [socialSectionStack.bottomAnchor constraintEqualToAnchor:self.socialSectionCard.bottomAnchor constant:-16]
    ]];
}


- (void)setupCloseButton {
    if (self.presentationStyle == PPUserSigningPresentationStyleSheet) {
        UIButtonConfiguration *glassConfig;
        if (@available(iOS 26.0, *)) {
            glassConfig = [UIButtonConfiguration clearGlassButtonConfiguration];
        } else {
            glassConfig = [UIButtonConfiguration filledButtonConfiguration];
        }
        glassConfig.background.backgroundColor = [AppBackgroundClrLigter colorWithAlphaComponent:0.2];
        
        self.closeButton = [PPButtonHelper pp_buttonWithTitle:kLang(@"Maybe Later") font:[GM MidFontWithSize:16] textColor:[UIColor secondaryLabelColor] corners:18 imageName:@"" target:self config:glassConfig btnSize:56 action:@selector(handleClose)];
        self.closeButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:PPIOS26() ? 0.10 : 0.70];
        [self.containerStack addArrangedSubview:self.closeButton];
    }
}

#pragma mark - UI Factory Methods

- (UITextField *)createGlassTextField {
    UITextField *textField = [[UITextField alloc] init];
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    textField.font = [GM boldFontWithSize:18];
    textField.textColor = [UIColor labelColor];
    textField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:PPIOS26() ? 0.10 : 0.94];
    textField.layer.cornerRadius = 18;
    textField.clipsToBounds = YES;
    textField.keyboardType =  UIKeyboardTypeASCIICapable;
    textField.textAlignment = NSTextAlignmentLeft;
    textField.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    textField.tintColor = AppPrimaryClr;
    // Add padding
    UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 18, 20)];
    textField.leftView = paddingView;
    textField.leftViewMode = UITextFieldViewModeAlways;
    [textField.heightAnchor constraintEqualToConstant:56].active = YES;
    
    return textField;
}


- (UIButton *)createSocialButtonWithTitle:(NSString *)title iconName:(NSString *)iconName isPrimary:(BOOL)isPrimary {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
    UIImage *iconImage = [UIImage imageNamed:iconName];
    if (iconImage) {
        CGFloat maxDimension = 20.0;
        if (MAX(iconImage.size.width, iconImage.size.height) > maxDimension) {
            CGFloat aspectRatio = iconImage.size.width / MAX(iconImage.size.height, 1.0);
            CGSize targetSize = aspectRatio >= 1.0
            ? CGSizeMake(maxDimension, maxDimension / MAX(aspectRatio, 1.0))
            : CGSizeMake(maxDimension * aspectRatio, maxDimension);
            UIGraphicsBeginImageContextWithOptions(targetSize, NO, 0.0);
            [iconImage drawInRect:(CGRect){CGPointZero, targetSize}];
            UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            if (resizedImage) {
                iconImage = resizedImage;
            }
        }
        iconImage = [iconImage imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    } else {
        UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
        iconImage = [[UIImage systemImageNamed:iconName] imageByApplyingSymbolConfiguration:symbolConfig];
    }
    config.image = iconImage;
    config.imagePlacement = NSDirectionalRectEdgeLeading;
    config.imagePadding = 12;
    config.title = title;
    config.baseForegroundColor = isPrimary ? UIColor.whiteColor : AppPrimaryTextClr;
    config.background.backgroundColor = isPrimary ? AppShadowClr  : AppBackgroundClr;
    config.background.cornerRadius = 20;
    config.contentInsets = NSDirectionalEdgeInsetsMake(16, 16, 16, 16);
    config.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> * _Nonnull incoming) {
        NSMutableDictionary *attrs = incoming.mutableCopy ?: [NSMutableDictionary dictionary];
        attrs[NSFontAttributeName] = [GM boldFontWithSize:16];
        return attrs;
    };
    
   
    button.configuration = config;
    button.layer.cornerRadius = 20.0;
    button.layer.masksToBounds = NO;
    [button pp_setShadowColor:[UIColor blackColor]];
    button.layer.shadowOpacity = isPrimary ? 0.10 : 0.08;
    button.layer.shadowRadius = 18.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    [self pp_addPressAnimationToButton:button];
    [button.heightAnchor constraintEqualToConstant:56].active = YES;
    
    return button;
}

#pragma mark - Constraints

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Scroll View
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        
        // Container Stack
        [self.containerStack.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor constant:22],
        [self.containerStack.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor constant:24],
        [self.containerStack.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor constant:-24],
        [self.containerStack.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:-24],
        [self.containerStack.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor constant:-48]
    ]];
}

#pragma mark - Keyboard Handling

- (void)keyboardWillShow:(NSNotification *)notification {
    if (self.isKeyboardVisible) return;
    
    NSDictionary *userInfo = notification.userInfo;
    CGRect keyboardFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    [UIView animateWithDuration:duration animations:^{
        UIEdgeInsets contentInset = self.scrollView.contentInset;
        contentInset.bottom = keyboardFrame.size.height - self.view.safeAreaInsets.bottom;
        self.scrollView.contentInset = contentInset;
        self.scrollView.scrollIndicatorInsets = contentInset;
    }];
    
    self.isKeyboardVisible = YES;
    

    [self lockSheetDetentForKeyboard];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    if (!self.isKeyboardVisible) return;
    
    NSDictionary *userInfo = notification.userInfo;
    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    [UIView animateWithDuration:duration animations:^{
        self.scrollView.contentInset = UIEdgeInsetsZero;
        self.scrollView.scrollIndicatorInsets = UIEdgeInsetsZero;
    }];
    
    self.isKeyboardVisible = NO;

    [self unlockSheetDetentAfterKeyboard];
}

- (void)lockSheetDetentForKeyboard {
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = self.sheetPresentationController;
        if (!sheet) {
            return;
        }
        self.savedSheetDetents = sheet.detents;
        sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
        if (@available(iOS 16.0, *)) {
            [sheet animateChanges:^{
                sheet.selectedDetentIdentifier = kPPSheetCustomMediumDetentIdentifier;
            }];
        } else {
            sheet.largestUndimmedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
        }
    }
}

- (void)unlockSheetDetentAfterKeyboard {
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = self.sheetPresentationController;
        if (!sheet) {
            return;
        }
        if (self.savedSheetDetents.count > 0) {
            sheet.detents = self.savedSheetDetents;
            self.savedSheetDetents = nil;
        }
        sheet.prefersScrollingExpandsWhenScrolledToEdge = YES;
        if (@available(iOS 16.0, *)) {
            [sheet animateChanges:^{
                sheet.selectedDetentIdentifier = kPPSheetCustomMediumDetentIdentifier;
            }];
        } else {
            sheet.largestUndimmedDetentIdentifier = nil;
        }
    }
}
  

#pragma mark - Auth Handlers

- (NSString *)normalizedCountryCode:(NSString *)countryCode {
    NSString *trimmed = [[countryCode ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (trimmed.length == 0) {
        return self.defaultCountryCode ?: @"+974";
    }
    if (![trimmed hasPrefix:@"+"]) {
        trimmed = [@"+" stringByAppendingString:trimmed];
    }
    return trimmed;
}

- (CountryCodeModel *)pp_countryWithID:(NSInteger)countryID
                           inCountries:(NSArray<CountryCodeModel *> *)countries {
    if (countryID <= 0 || countries.count == 0) {
        return nil;
    }
    for (CountryCodeModel *country in countries) {
        if (country.ID == countryID) {
            return country;
        }
    }
    return nil;
}

- (CountryCodeModel *)pp_countryWithISOCode:(NSString *)isoCode
                                 inCountries:(NSArray<CountryCodeModel *> *)countries {
    if (isoCode.length == 0 || countries.count == 0) {
        return nil;
    }
    NSString *normalizedISO = isoCode.uppercaseString;
    for (CountryCodeModel *country in countries) {
        if ([country.isoCountryCode.uppercaseString isEqualToString:normalizedISO]) {
            return country;
        }
    }
    return nil;
}

- (CountryCodeModel *)pp_countryWithPhoneCode:(NSString *)phoneCode
                                   inCountries:(NSArray<CountryCodeModel *> *)countries {
    NSString *normalizedCode = [self normalizedCountryCode:phoneCode];
    if (normalizedCode.length == 0 || countries.count == 0) {
        return nil;
    }
    for (CountryCodeModel *country in countries) {
        if ([[self normalizedCountryCode:country.phoneCode] isEqualToString:normalizedCode]) {
            return country;
        }
    }
    return nil;
}

- (CountryCodeModel *)pp_countryForAppCountry:(CountryModel *)country
                                  inCountries:(NSArray<CountryCodeModel *> *)countries {
    if (!country || countries.count == 0) {
        return nil;
    }

    CountryCodeModel *byISO =
    [self pp_countryWithISOCode:PPSafeString(country.iso)
                     inCountries:countries];
    if (byISO) {
        return byISO;
    }

    return [self pp_countryWithPhoneCode:PPSafeString(country.countryCode)
                              inCountries:countries];
}

- (NSString *)pp_normalizedCountryLookupText:(NSString *)text {
    NSString *safe =
    [[PPSafeString(text) lowercaseString] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (safe.length == 0) {
        return @"";
    }

    NSCharacterSet *separators =
    [NSCharacterSet characterSetWithCharactersInString:@",،.-_/\\|()[]{}"];
    NSString *joined =
    [[safe componentsSeparatedByCharactersInSet:separators] componentsJoinedByString:@" "];
    NSArray<NSString *> *parts =
    [joined componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableArray<NSString *> *filtered = [NSMutableArray arrayWithCapacity:parts.count];
    for (NSString *part in parts) {
        if (part.length > 0) {
            [filtered addObject:part];
        }
    }
    return [filtered componentsJoinedByString:@" "];
}

- (BOOL)pp_locationText:(NSString *)locationText matchesCandidate:(NSString *)candidate {
    NSString *normalizedLocation = [self pp_normalizedCountryLookupText:locationText];
    NSString *normalizedCandidate = [self pp_normalizedCountryLookupText:candidate];
    if (normalizedLocation.length == 0 || normalizedCandidate.length == 0) {
        return NO;
    }

    return [normalizedLocation containsString:normalizedCandidate] ||
           [normalizedCandidate containsString:normalizedLocation];
}

- (CountryCodeModel *)pp_countryFromSavedHomeAreaInCountries:(NSArray<CountryCodeModel *> *)countries {
    if (countries.count == 0) {
        return nil;
    }

    NSString *savedArea =
    [[NSUserDefaults standardUserDefaults] stringForKey:kPPHomeNearbySelectedAreaNameDefaultsKey];
    if ([self pp_normalizedCountryLookupText:savedArea].length == 0) {
        return nil;
    }

    for (CountryModel *country in CitiesManager.shared.countries) {
        if ([self pp_locationText:savedArea matchesCandidate:country.enName] ||
            [self pp_locationText:savedArea matchesCandidate:country.arName]) {
            return [self pp_countryForAppCountry:country inCountries:countries];
        }

        for (CityModel *city in country.cities) {
            if ([self pp_locationText:savedArea matchesCandidate:city.enName] ||
                [self pp_locationText:savedArea matchesCandidate:city.arName]) {
                return [self pp_countryForAppCountry:country inCountries:countries];
            }

            for (StateModel *state in city.states) {
                if ([self pp_locationText:savedArea matchesCandidate:state.enName] ||
                    [self pp_locationText:savedArea matchesCandidate:state.arName]) {
                    return [self pp_countryForAppCountry:country inCountries:countries];
                }
            }
        }
    }

    return nil;
}

- (CountryCodeModel *)pp_resolveAutomaticCountryFromCountries:(NSArray<CountryCodeModel *> *)countries {
    if (countries.count == 0) {
        return nil;
    }

    NSInteger currentUserCountryID = UserManager.sharedManager.currentUser.CountryID;
    NSInteger savedCountryID = [[NSUserDefaults standardUserDefaults] integerForKey:@"CountryID"];

    CountryModel *currentCountry = CitiesManager.shared.CurrentCountry;
    NSString *carrierISO = [GM getCurrentCountryFromCarrier];
    NSString *localeISO = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];

    CountryCodeModel *resolved = nil;
    if (PPIOS26()) {
        NSInteger explicitCountryID = currentUserCountryID > 0 ? currentUserCountryID : savedCountryID;
        resolved = [self pp_countryWithID:explicitCountryID inCountries:countries];
    } else {
        resolved = [self pp_countryWithID:currentUserCountryID inCountries:countries];
        if (!resolved) {
            resolved = [self pp_countryFromSavedHomeAreaInCountries:countries];
        }
        if (!resolved) {
            resolved = [self pp_countryWithID:savedCountryID inCountries:countries];
        }
    }
    if (!resolved) {
        resolved = [self pp_countryWithISOCode:PPSafeString(carrierISO) inCountries:countries];
    }
    if (!resolved) {
        resolved = [self pp_countryWithISOCode:PPSafeString(currentCountry.iso) inCountries:countries];
    }
    if (!resolved) {
        resolved = [self pp_countryWithISOCode:PPSafeString(localeISO) inCountries:countries];
    }
    if (!resolved) {
        resolved = [self pp_countryWithPhoneCode:PPSafeString(currentCountry.countryCode)
                                     inCountries:countries];
    }
    if (!resolved) {
        resolved = [self pp_countryWithPhoneCode:self.defaultCountryCode
                                     inCountries:countries];
    }
    if (!resolved) {
        resolved = [self pp_countryWithISOCode:@"QA" inCountries:countries];
    }
    return resolved ?: countries.firstObject;
}

- (void)pp_applyCountryCodeToButton:(NSString *)countryCode {
    NSString *safePhoneCode = [self normalizedCountryCode:countryCode];
    if (safePhoneCode.length == 0) {
        return;
    }
    NSString *flag = PPSafeString(self.autoDetectedCountry.flag);
    NSString *displayTitle = flag.length > 0 ? [NSString stringWithFormat:@"%@ %@", flag, safePhoneCode] : safePhoneCode;
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *config = self.countryCodePickerBtn.configuration;
        NSMutableAttributedString *title =
        [[NSMutableAttributedString alloc] initWithString:displayTitle
                                                attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:18],
            NSForegroundColorAttributeName: AppPrimaryClr
        }];
        config.attributedTitle = title;
        self.countryCodePickerBtn.configuration = config;
    } else {
        [self.countryCodePickerBtn setTitle:displayTitle forState:UIControlStateNormal];
        [self.countryCodePickerBtn setTitleColor:AppPrimaryClr forState:UIControlStateNormal];
        self.countryCodePickerBtn.titleLabel.font = [GM boldFontWithSize:18];
    }
}

- (void)handlePhoneFieldChanged:(UITextField *)textField {
    NSString *digits = [self normalizedPhoneDigitsFromRawInput:textField.text hasInvalidCharacters:NULL];
    if (![textField.text isEqualToString:digits]) {
        textField.text = digits;
    }
    self.normalizedPhoneDigits = digits;
    [self refreshPhoneLiveState];
    [self updateContinuePhoneButtonState];
}

- (void)refreshPhoneLiveState {
    NSString *countryCode = [self normalizedCountryCode:self.currentPhoneCode];
    BOOL hasInvalidCharacters = NO;
    NSString *digits = [self normalizedPhoneDigitsFromRawInput:self.phoneNumberField.text hasInvalidCharacters:&hasInvalidCharacters];
    self.normalizedPhoneDigits = digits;

    if (digits.length == 0) {
        self.phoneLiveLabel.text = kLang(@"auth_phone_live_hint");
        self.phoneLiveLabel.textColor = UIColor.secondaryLabelColor;
        return;
    }

    NSString *preview = [NSString stringWithFormat:@"%@%@", countryCode ?: @"", digits ?: @""];
    self.phoneLiveLabel.text = [NSString stringWithFormat:kLang(@"auth_phone_live_ready"), preview];
    self.phoneLiveLabel.textColor = (digits.length >= kPPMinimumPhoneDigits && !hasInvalidCharacters)
    ? AppPrimaryClr
    : UIColor.secondaryLabelColor;
}

- (void)pp_lockCountryCodePicker {
    self.countryCodePickerBtn.enabled = NO;
    self.countryCodePickerBtn.userInteractionEnabled = NO;
    self.countryCodePickerBtn.accessibilityHint = kLang(@"auth_country_code_auto_selected");
}

- (NSString *)pp_joinedErrorTextForError:(NSError *)error {
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
            NSString *nested = [self pp_joinedErrorTextForError:(NSError *)value];
            if (nested.length > 0) {
                [parts addObject:nested];
            }
        }
    }
    return [[parts componentsJoinedByString:@" "] lowercaseString];
}

- (NSString *)pp_localizedAuthMessageForError:(NSError *)error fallbackKey:(NSString *)fallbackKey {
    NSString *joined = [self pp_joinedErrorTextForError:error];
    if ([joined containsString:@"too_long"] || [joined containsString:@"too long"]) {
        return kLang(@"auth_phone_error_too_long");
    }
    if ([joined containsString:@"too_short"] || [joined containsString:@"too short"]) {
        return kLang(@"auth_phone_error_too_short");
    }
    if ([joined containsString:@"missing_phone"] || [joined containsString:@"missing phone"]) {
        return kLang(@"auth_phone_required_message");
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
    if ([joined containsString:@"cancel"]) {
        return kLang(@"auth_error_message");
    }

    NSString *fallback = fallbackKey.length > 0 ? kLang(fallbackKey) : nil;
    return fallback.length > 0 ? fallback : kLang(@"auth_error_message");
}

- (NSString *)normalizedPhoneDigitsFromRawInput:(NSString *)rawInput hasInvalidCharacters:(BOOL *)hasInvalidCharacters {
    NSString *trimmed = [[rawInput ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSCharacterSet *digitsSet = [NSCharacterSet decimalDigitCharacterSet];
    NSMutableString *digits = [NSMutableString string];
    BOOL invalidCharacterFound = NO;
    
    for (NSUInteger i = 0; i < trimmed.length; i++) {
        unichar ch = [trimmed characterAtIndex:i];
        if ([digitsSet characterIsMember:ch]) {
            NSString *rawDigit = [NSString stringWithFormat:@"%C", ch];
            NSString *latinDigit = [rawDigit stringByApplyingTransform:NSStringTransformToLatin reverse:NO] ?: rawDigit;
            NSCharacterSet *asciiDigits = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
            unichar normalized = latinDigit.length > 0 ? [latinDigit characterAtIndex:0] : 0;
            if ([asciiDigits characterIsMember:normalized]) {
                [digits appendFormat:@"%C", normalized];
            } else {
                invalidCharacterFound = YES;
            }
        } else {
            invalidCharacterFound = YES;
        }
    }
    
    if (hasInvalidCharacters) {
        *hasInvalidCharacters = invalidCharacterFound;
    }
    return digits;
}

- (void)setContinuePhoneButtonTitle:(NSString *)title {
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = self.continuePhoneButton.configuration;
        UIColor *titleColor = UIColor.whiteColor;
        if (!PPIOS26() && self.continuePhoneButton && !self.continuePhoneButton.enabled) {
            titleColor = [AppPrimaryClr colorWithAlphaComponent:0.64];
        }
        NSDictionary *attributes = @{
            NSFontAttributeName: [GM boldFontWithSize:17],
            NSForegroundColorAttributeName: titleColor
        };
        config.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:attributes];
        config.baseForegroundColor = titleColor;
        self.continuePhoneButton.configuration = config;
    } else {
        [self.continuePhoneButton setTitle:title forState:UIControlStateNormal];
        [self.continuePhoneButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        self.continuePhoneButton.titleLabel.font = [GM boldFontWithSize:17];
    }
}

- (void)updateContinuePhoneButtonState {
    BOOL onCooldown = self.phoneCooldownRemaining > 0;
    BOOL isAuthLocked = self.isAuthenticating;
    BOOL hasInvalidCharacters = NO;
    NSString *digits = [self normalizedPhoneDigitsFromRawInput:self.phoneNumberField.text hasInvalidCharacters:&hasInvalidCharacters];
    self.normalizedPhoneDigits = digits;
    BOOL hasValidPhone = (digits.length >= kPPMinimumPhoneDigits && !hasInvalidCharacters);
    BOOL enabled = !onCooldown && !isAuthLocked && hasValidPhone;
    self.continuePhoneButton.enabled = enabled;
    self.continuePhoneButton.alpha = enabled ? 1.0 : 0.6;
    
    if (onCooldown) {
        [self setContinuePhoneButtonTitle:[NSString stringWithFormat:@"%@ (%lds)", kLang(@"Continue with Mobile"), (long)self.phoneCooldownRemaining]];
    } else {
        [self setContinuePhoneButtonTitle:kLang(@"Continue with Mobile")];
    }

    if (!PPIOS26()) {
        [self pp_applyBelowIOS26PhoneFallbackChrome];
    }

    [self refreshPhoneLiveState];
}

- (void)startPhoneSMSCooldown {
    [self.phoneCooldownTimer invalidate];
    self.phoneCooldownTimer = nil;
    self.phoneCooldownRemaining = (NSInteger)kPPSMSCooldownSeconds;
    [self updateContinuePhoneButtonState];

    __weak typeof(self) weakSelf = self;
    self.phoneCooldownTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        PPDispatchMain(^{
            if (!weakSelf) {
                [timer invalidate];
                return;
            }
            weakSelf.phoneCooldownRemaining -= 1;
            if (weakSelf.phoneCooldownRemaining <= 0) {
                weakSelf.phoneCooldownRemaining = 0;
                [weakSelf.phoneCooldownTimer invalidate];
                weakSelf.phoneCooldownTimer = nil;
            }
            [weakSelf updateContinuePhoneButtonState];
        });
    }];
}

- (void)resetPhoneSMSCooldown {
    [self.phoneCooldownTimer invalidate];
    self.phoneCooldownTimer = nil;
    self.phoneCooldownRemaining = 0;
    [self updateContinuePhoneButtonState];
}
- (void)handlePhoneSignIn {
    NSString *countryCode = [self normalizedCountryCode:self.currentPhoneCode];
    BOOL hasInvalidCharacters = NO;
    NSString *phoneDigits = [self normalizedPhoneDigitsFromRawInput:self.phoneNumberField.text hasInvalidCharacters:&hasInvalidCharacters];
    
    if (phoneDigits.length == 0) {
        [PPAlertHelper showWarningIn:self
                               title:kLang(@"auth_phone_required_title")
                            subtitle:kLang(@"auth_phone_required_message")];
        return;
    }
    
    if (hasInvalidCharacters) {
        [PPAlertHelper showWarningIn:self
                               title:kLang(@"auth_error_title")
                            subtitle:kLang(@"auth_phone_digits_only")];
        return;
    }
    
    if (phoneDigits.length < kPPMinimumPhoneDigits) {
        [PPAlertHelper showWarningIn:self
                               title:kLang(@"auth_error_title")
                            subtitle:kLang(@"auth_phone_error_invalid")];
        return;
    }
    
    NSString *fullNumber = [NSString stringWithFormat:@"%@%@", countryCode, phoneDigits];
    self.normalizedPhoneDigits = phoneDigits;
    self.currentPhoneCode = countryCode;
    self.phoneNumberField.text = phoneDigits;
    self.isAuthenticating = YES;
    [self updateContinuePhoneButtonState];
    
    [PPHUD showIndeterminateIn:self.view
                          title:kLang(@"auth_sending_code_title")
                       subtitle:nil];
    [self setInteractionEnabled:NO];
    
    [[FIRPhoneAuthProvider provider] verifyPhoneNumber:fullNumber
                                            UIDelegate:nil
                                            completion:^(NSString * _Nullable verificationID, NSError * _Nullable error) {
        PPDispatchMain(^{
            [PPHUD dismiss];
            self.isAuthenticating = NO;
            [self setInteractionEnabled:YES];
            [self updateContinuePhoneButtonState];
            
            if (error) {
                [self notifySignInFailure:error];
                [PPAlertHelper showErrorIn:self
                                     title:kLang(@"auth_sending_code_failed_title")
                                  subtitle:[self pp_localizedAuthMessageForError:error
                                                                    fallbackKey:@"auth_sending_code_failed_message"]];
                return;
            }
            if (verificationID.length == 0) {
                NSError *verificationError = [NSError errorWithDomain:@"PPAuth"
                                                                 code:1001
                                                             userInfo:@{NSLocalizedDescriptionKey: kLang(@"auth_verification_start_failed")}];
                [self notifySignInFailure:verificationError];
                [PPAlertHelper showErrorIn:self
                                     title:kLang(@"auth_sending_code_failed_title")
                                  subtitle:kLang(@"auth_verification_start_failed")];
                return;
            }
            
            self.verificationID = verificationID;
            [[NSUserDefaults standardUserDefaults] setObject:verificationID forKey:kPPDefaultsAuthVerificationIDKey];
            [self startPhoneSMSCooldown];
            
            [self promptForVerificationCode];
        });
    }];
}


- (void)startAppleSignInFlowResetRetry:(BOOL)resetRetry {
    if (self.isAuthenticating) {
        return;
    }
    if (resetRetry) {
        self.appleSignInRetryCount = 0;
    }
    self.isAuthenticating = YES;
    [self setInteractionEnabled:NO];
    [self updateContinuePhoneButtonState];
    
    if (@available(iOS 13.0, *)) {
        NSString *nonce = [self randomNonce:32];
        self.currentNonce = nonce;
        
        ASAuthorizationAppleIDProvider *appleProvider = [[ASAuthorizationAppleIDProvider alloc] init];
        ASAuthorizationAppleIDRequest *request = [appleProvider createRequest];
        request.requestedScopes = @[ASAuthorizationScopeFullName, ASAuthorizationScopeEmail];
        request.nonce = [self stringBySha256HashingString:nonce];
        
        ASAuthorizationController *controller = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[request]];
        controller.delegate = self;
        controller.presentationContextProvider = self;
        [controller performRequests];
    } else {
        self.isAuthenticating = NO;
        [self setInteractionEnabled:YES];
        [self updateContinuePhoneButtonState];
        NSError *iosVersionError = [NSError errorWithDomain:@"PPAuth"
                                                       code:1005
                                                   userInfo:@{NSLocalizedDescriptionKey: kLang(@"auth_apple_requires_ios13")}];
        [self notifySignInFailure:iosVersionError];
        [PPAlertHelper showWarningIn:self
                               title:kLang(@"auth_error_title")
                            subtitle:kLang(@"auth_apple_requires_ios13")];
    }
}

- (void)handleAppleSignIn {
    [self startAppleSignInFlowResetRetry:YES];
}

- (nullable NSString *)pp_googleClientIDFromReversedScheme:(NSString *)scheme
{
    if (![scheme isKindOfClass:[NSString class]] || ![scheme hasPrefix:kPPGoogleReversedClientIDPrefix]) {
        return nil;
    }
    NSString *suffix = [scheme substringFromIndex:kPPGoogleReversedClientIDPrefix.length];
    if (suffix.length == 0) {
        return nil;
    }
    return [NSString stringWithFormat:@"%@%@", suffix, kPPGoogleClientIDSuffix];
}

- (NSString *)pp_trimmedGoogleConfigString:(id)value
{
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (nullable NSString *)pp_googleServerClientID
{
    NSDictionary *info = NSBundle.mainBundle.infoDictionary ?: @{};
    NSString *serverClientID = [self pp_trimmedGoogleConfigString:info[kPPGoogleSignInServerClientIDKey]];
    if ([serverClientID hasSuffix:kPPGoogleClientIDSuffix]) {
        return serverClientID;
    }
    return nil;
}

- (nullable GIDConfiguration *)pp_googleConfigurationForClientID:(NSString *)clientID
{
    NSString *safeClientID = [self pp_trimmedGoogleConfigString:clientID];
    if (safeClientID.length == 0) {
        return nil;
    }

    NSString *serverClientID = [self pp_googleServerClientID];
    if (serverClientID.length > 0 && ![serverClientID isEqualToString:safeClientID]) {
        return [[GIDConfiguration alloc] initWithClientID:safeClientID serverClientID:serverClientID];
    }
    return [[GIDConfiguration alloc] initWithClientID:safeClientID];
}

- (BOOL)pp_configureGoogleSignInForClientID:(NSString *)clientID
{
    GIDConfiguration *configuration = [self pp_googleConfigurationForClientID:clientID];
    if (!configuration) {
        return NO;
    }
    GIDSignIn.sharedInstance.configuration = configuration;
    return YES;
}

- (NSString *)pp_redactedGoogleClientIDForLog:(NSString *)clientID
{
    NSString *safeClientID = [self pp_trimmedGoogleConfigString:clientID];
    if (safeClientID.length <= 12) {
        return safeClientID.length ? @"configured" : @"missing";
    }
    return [NSString stringWithFormat:@"...%@", [safeClientID substringFromIndex:safeClientID.length - 12]];
}

- (NSArray<NSString *> *)pp_googleClientIDCandidates
{
    NSDictionary *info = NSBundle.mainBundle.infoDictionary ?: @{};
    NSMutableOrderedSet<NSString *> *candidates = [NSMutableOrderedSet orderedSet];

    NSString *gidClientID = [self pp_trimmedGoogleConfigString:info[kPPGoogleSignInClientIDKey]];
    if (gidClientID.length > 0) {
        [candidates addObject:gidClientID];
    }
    NSString *firebaseClientID = [self pp_trimmedGoogleConfigString:[FIRApp defaultApp].options.clientID];
    if (firebaseClientID.length > 0) {
        [candidates addObject:firebaseClientID];
    }

    NSMutableSet<NSString *> *urlTypeSchemes = [NSMutableSet set];
    id urlTypes = info[@"CFBundleURLTypes"];
    if ([urlTypes isKindOfClass:[NSArray class]]) {
        for (id urlType in (NSArray *)urlTypes) {
            if (![urlType isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            NSDictionary *urlTypeDict = (NSDictionary *)urlType;
            NSArray *schemes = [urlTypeDict[@"CFBundleURLSchemes"] isKindOfClass:[NSArray class]] ? urlTypeDict[@"CFBundleURLSchemes"] : @[];
            for (id schemeObj in schemes) {
                if (![schemeObj isKindOfClass:[NSString class]]) {
                    continue;
                }
                NSString *scheme = (NSString *)schemeObj;
                if ([scheme hasPrefix:kPPGoogleReversedClientIDPrefix]) {
                    [urlTypeSchemes addObject:scheme];
                    NSString *candidate = [self pp_googleClientIDFromReversedScheme:scheme];
                    if (candidate.length > 0) {
                        [candidates addObject:[self pp_trimmedGoogleConfigString:candidate]];
                    }
                }
            }
        }
    }

    NSMutableArray<NSString *> *result = [NSMutableArray array];
    for (NSString *candidate in candidates) {
        NSString *trimmed = [self pp_trimmedGoogleConfigString:candidate];
        if (trimmed.length == 0) {
            continue;
        }
        if (![trimmed hasSuffix:kPPGoogleClientIDSuffix]) {
            continue;
        }
        NSString *prefix = [trimmed stringByReplacingOccurrencesOfString:kPPGoogleClientIDSuffix withString:@""];
        NSString *reversedScheme = [NSString stringWithFormat:@"%@%@", kPPGoogleReversedClientIDPrefix, prefix];
        if (![urlTypeSchemes containsObject:reversedScheme]) {
            continue;
        }
        if (trimmed.length > 0) {
            [result addObject:trimmed];
        }
    }
    return result.copy;
}

- (BOOL)pp_googleErrorIndicatesOAuthAssertionFailure:(NSError *)error
{
    if (!error) {
        return NO;
    }
    NSMutableArray<NSString *> *messages = [NSMutableArray array];
    if (error.localizedDescription.length > 0) {
        [messages addObject:error.localizedDescription];
    }
    for (id value in (error.userInfo ?: @{}).allValues) {
        if ([value isKindOfClass:NSString.class]) {
            [messages addObject:(NSString *)value];
        }
    }
    NSString *joined = [[messages componentsJoinedByString:@" "] lowercaseString];
    return ([joined containsString:@"token failed"] ||
            [joined containsString:@"authenticity"] ||
            [joined containsString:@"client_assertion"] ||
            [joined containsString:@"client assertion"] ||
            [joined containsString:@"app check"]);
}

- (BOOL)pp_googleErrorIndicatesWrongClientType:(NSError *)error
{
    if (!error) {
        return NO;
    }
    NSString *msg = [error.localizedDescription lowercaseString];
    if ([msg containsString:@"invalid_request"] &&
        ([msg containsString:@"web client"] ||
         [msg containsString:@"custom scheme"] ||
         [msg containsString:@"authorization error"])) {
        return YES;
    }
    NSDictionary *userInfo = error.userInfo ?: @{};
    for (id value in userInfo.allValues) {
        if (![value isKindOfClass:NSString.class]) continue;
        NSString *lower = [(NSString *)value lowercaseString];
        if ([lower containsString:@"web client"] || [lower containsString:@"custom scheme"]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)pp_isGoogleSignInCancellationError:(NSError *)error
{
    return (error &&
            [error.domain isEqualToString:kGIDSignInErrorDomain] &&
            error.code == kGIDSignInErrorCodeCanceled);
}

- (NSString *)pp_googleDisplayMessageForError:(NSError *)error
{
    if (error.code == kPPGoogleSignInConfigMissingCode) {
        return kLang(@"error_google_signin_client_config_missing");
    }
    if ([self pp_googleErrorIndicatesOAuthAssertionFailure:error]) {
        return kLang(@"auth_google_failed_message");
    }
    return [self pp_localizedAuthMessageForError:error fallbackKey:@"auth_google_failed_message"];
}

- (void)pp_resetGoogleSignInLoadingState
{
    [PPHUD dismiss];
    self.isAuthenticating = NO;
    [self setInteractionEnabled:YES];
    [self updateContinuePhoneButtonState];
}

- (void)pp_finishGoogleSignInWithError:(NSError *)error
{
    [self pp_resetGoogleSignInLoadingState];
    [self notifySignInFailure:error];
    [PPAlertHelper showErrorIn:self
                         title:kLang(@"auth_google_failed_title")
                      subtitle:[self pp_googleDisplayMessageForError:error]];
}

- (void)pp_startGoogleSignInWithCandidates:(NSArray<NSString *> *)candidates
                                     index:(NSUInteger)index
{
    if (index >= candidates.count) {
        NSError *missingConfigError = [NSError errorWithDomain:@"PPAuth"
                                                          code:kPPGoogleSignInConfigMissingCode
                                                      userInfo:@{NSLocalizedDescriptionKey: kLang(@"error_google_signin_client_config_missing")}];
        [self pp_finishGoogleSignInWithError:missingConfigError];
        return;
    }

    NSString *clientID = [self pp_trimmedGoogleConfigString:candidates[index]];
    if (clientID.length == 0) {
        [self pp_startGoogleSignInWithCandidates:candidates index:index + 1];
        return;
    }
    if (![self pp_configureGoogleSignInForClientID:clientID]) {
        [self pp_startGoogleSignInWithCandidates:candidates index:index + 1];
        return;
    }

    PPAuthDebugLog(@"[GoogleSignIn] Attempt %lu using client ID %@", (unsigned long)(index + 1), [self pp_redactedGoogleClientIDForLog:clientID]);
    PPAuthDebugLog(@"[GoogleSignIn] Configuration — clientID: %@ | serverClientID: %@ | redirectURI scheme: com.googleusercontent.apps.%@",
                   GIDSignIn.sharedInstance.configuration.clientID,
                   GIDSignIn.sharedInstance.configuration.serverClientID ?: @"(none)",
                   [clientID stringByReplacingOccurrencesOfString:@".apps.googleusercontent.com" withString:@""]);

    __weak typeof(self) weakSelf = self;
    [GIDSignIn.sharedInstance signInWithPresentingViewController:self
                                                            hint:nil
                                                      completion:^(GIDSignInResult *_Nullable signInResult,
                                                                   NSError *_Nullable error) {
        PPDispatchMain(^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            if (error) {
                PPAuthDebugLog(@"[GoogleSignIn] Error domain=%@ code=%ld description=%@ userInfo=%@",
                               error.domain, (long)error.code, error.localizedDescription, error.userInfo);
                if ([self pp_isGoogleSignInCancellationError:error]) {
                    [self pp_resetGoogleSignInLoadingState];
                    return;
                }
                if ([self pp_googleErrorIndicatesWrongClientType:error] && (index + 1) < candidates.count) {
                    [self pp_startGoogleSignInWithCandidates:candidates index:index + 1];
                    return;
                }
                [self pp_finishGoogleSignInWithError:error];
                return;
            }
            if (!signInResult.user) {
                NSError *googleUserError = [NSError errorWithDomain:@"PPAuth"
                                                               code:1006
                                                           userInfo:@{NSLocalizedDescriptionKey: kLang(@"auth_google_account_unavailable_message")}];
                [self pp_finishGoogleSignInWithError:googleUserError];
                return;
            }
            [self handleGoogleAuthResult:signInResult.user];
        });
    }];
}

- (void)handleGoogleSignIn {
    if (self.isAuthenticating) {
        return;
    }
    NSArray<NSString *> *candidates = [self pp_googleClientIDCandidates];
    if (candidates.count == 0) {
        NSError *missingConfigError = [NSError errorWithDomain:@"PPAuth"
                                                          code:kPPGoogleSignInConfigMissingCode
                                                      userInfo:@{NSLocalizedDescriptionKey: kLang(@"error_google_signin_client_config_missing")}];
        [self notifySignInFailure:missingConfigError];
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"auth_google_failed_title")
                          subtitle:[self pp_googleDisplayMessageForError:missingConfigError]];
        return;
    }

    self.isAuthenticating = YES;
    [self setInteractionEnabled:NO];
    [self updateContinuePhoneButtonState];
    
    [PPHUD showIndeterminateIn:self.view
                          title:kLang(@"auth_google_connecting_title")
                       subtitle:nil];

    [self pp_startGoogleSignInWithCandidates:candidates index:0];
}


- (void)handleClose {
    if (self.signInCancelled) {
        self.signInCancelled();
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Verification Flow

- (void)promptForVerificationCode {
    NSString *fullPhone = [NSString stringWithFormat:@"%@%@",
                           self.currentPhoneCode ?: @"",
                           self.normalizedPhoneDigits ?: @""];
    PPVerificationCodeViewController *vc =
    [[PPVerificationCodeViewController alloc] initWithPhone:fullPhone];
    __weak typeof(self) weakSelf = self;
    vc.onAuthResultSuccess = ^(FIRAuthDataResult *authResult) {
        PPDispatchMain(^{
            if (!weakSelf) {
                return;
            }
            [PPHUD dismiss];
            [weakSelf handleSuccessfulAuth:authResult method:PPSignInMethodPhone];
        });
    };
    vc.onResendRequested = ^(PPVerificationResendCompletion completion) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            if (completion) {
                NSError *deallocatedError = [NSError errorWithDomain:@"PPAuth"
                                                                code:1002
                                                            userInfo:@{NSLocalizedDescriptionKey: kLang(@"auth_session_expired_message")}];
                completion(NO, deallocatedError);
            }
            return;
        }
        NSString *safeFullPhone = [NSString stringWithFormat:@"%@%@",
                                   strongSelf.currentPhoneCode ?: @"",
                                   strongSelf.normalizedPhoneDigits ?: @""];
        [strongSelf resendVerificationCodeForPhone:safeFullPhone completion:completion];
    };
    vc.onBackRequested = ^{
        PPDispatchMain(^{
            if (!weakSelf) return;
            [weakSelf resetPhoneSMSCooldown];
        });
    };

    [PPFunc presentSheetFrom:self sheetVC:vc detentStyle:PPSheetDetentStyleMediumOnly];
}

- (void)resendVerificationCodeForPhone:(NSString *)fullPhone
                            completion:(PPVerificationResendCompletion)completion {
    if (fullPhone.length == 0) {
        if (completion) {
            NSError *invalidPhoneError = [NSError errorWithDomain:@"PPAuth"
                                                             code:1003
                                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"auth_phone_error_invalid")}];
            completion(NO, invalidPhoneError);
        }
        return;
    }
    
    [[FIRPhoneAuthProvider provider] verifyPhoneNumber:fullPhone
                                            UIDelegate:nil
                                            completion:^(NSString * _Nullable verificationID, NSError * _Nullable error) {
        PPDispatchMain(^{
            if (error) {
                if (completion) {
                    NSError *displayError = [NSError errorWithDomain:error.domain ?: @"PPAuth"
                                                                 code:error.code
                                                             userInfo:@{
                        NSLocalizedDescriptionKey: [self pp_localizedAuthMessageForError:error
                                                                             fallbackKey:@"auth_sending_code_failed_message"],
                        NSUnderlyingErrorKey: error
                    }];
                    completion(NO, displayError);
                }
                return;
            }
            if (verificationID.length == 0) {
                if (completion) {
                    NSError *verificationError = [NSError errorWithDomain:@"PPAuth"
                                                                     code:1004
                                                                 userInfo:@{NSLocalizedDescriptionKey: kLang(@"auth_resend_code_failed_message")}];
                    completion(NO, verificationError);
                }
                return;
            }
            
            self.verificationID = verificationID;
            [[NSUserDefaults standardUserDefaults] setObject:verificationID forKey:kPPDefaultsAuthVerificationIDKey];
            [self startPhoneSMSCooldown];
            
            if (completion) {
                completion(YES, nil);
            }
        });
    }];
}



#pragma mark - Social Auth Handlers

- (void)handleGoogleAuthResult:(GIDGoogleUser *)user {
    NSString *idToken = user.idToken.tokenString;
    NSString *accessToken = user.accessToken.tokenString;
    
    if (!idToken || !accessToken) {
        [PPHUD dismiss];
        self.isAuthenticating = NO;
        [self setInteractionEnabled:YES];
        [self updateContinuePhoneButtonState];
        NSError *googleTokenError = [NSError errorWithDomain:@"PPAuth"
                                                        code:1007
                                                    userInfo:@{NSLocalizedDescriptionKey: kLang(@"google_no_token_message")}];
        [self notifySignInFailure:googleTokenError];
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"google_no_token_title")
                          subtitle:kLang(@"google_no_token_message")];
        return;
    }
    
    FIRAuthCredential *credential =
        [FIRGoogleAuthProvider credentialWithIDToken:idToken
                                         accessToken:accessToken];
    
    [[FIRAuth auth] signInWithCredential:credential
                              completion:^(FIRAuthDataResult * _Nullable authResult,
                                           NSError * _Nullable error) {
        PPDispatchMain(^{
            [PPHUD dismiss];
            self.isAuthenticating = NO;
            [self setInteractionEnabled:YES];
            [self updateContinuePhoneButtonState];
            
            if (error) {
                [self notifySignInFailure:error];
                [PPAlertHelper showErrorIn:self
                                     title:kLang(@"auth_firebase_error_title")
                                  subtitle:[self pp_localizedAuthMessageForError:error
                                                                    fallbackKey:@"auth_error_message"]];
                return;
            }
            
            [self handleSuccessfulAuth:authResult method:PPSignInMethodGoogle];
        });
    }];
}


#pragma mark - Apple Sign-In Delegate

- (void)retryAppleSignInAfterMissingToken {
    self.appleSignInRetryCount += 1;
    if (self.appleSignInRetryCount > kPPAppleSignInMaxRetryCount) {
        self.isAuthenticating = NO;
        [self setInteractionEnabled:YES];
        [self updateContinuePhoneButtonState];
        NSError *appleTokenError = [NSError errorWithDomain:@"PPAuth"
                                                       code:1008
                                                   userInfo:@{NSLocalizedDescriptionKey: kLang(@"auth_apple_no_token")}];
        [self notifySignInFailure:appleTokenError];
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"auth_apple_failed_title")
                          subtitle:kLang(@"auth_apple_no_token")];
        return;
    }
    
    PPDispatchMain(^{
        [PPHUD dismiss];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.isAuthenticating = NO;
            [self setInteractionEnabled:YES];
            [self updateContinuePhoneButtonState];
            [self startAppleSignInFlowResetRetry:NO];
        });
    });
}

- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithAuthorization:(ASAuthorization *)authorization API_AVAILABLE(ios(13.0)) {
    if ([authorization.credential isKindOfClass:[ASAuthorizationAppleIDCredential class]]) {
        ASAuthorizationAppleIDCredential *appleIDCredential = (ASAuthorizationAppleIDCredential *)authorization.credential;
        NSData *identityToken = appleIDCredential.identityToken;
        if (identityToken.length == 0) {
            [self retryAppleSignInAfterMissingToken];
            return;
        }
        NSString *idToken = [[NSString alloc] initWithData:identityToken encoding:NSUTF8StringEncoding];
        
        if (!idToken || self.currentNonce.length == 0) {
            [self retryAppleSignInAfterMissingToken];
            return;
        }
        
        FIROAuthCredential *credential = [FIROAuthProvider appleCredentialWithIDToken:idToken
                                                                             rawNonce:self.currentNonce
                                                                             fullName:appleIDCredential.fullName];
        
        [PPHUD showIndeterminateIn:self.view
                              title:kLang(@"auth_apple_signing_in")
                           subtitle:nil];

        [[FIRAuth auth] signInWithCredential:credential completion:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable error) {
            PPDispatchMain(^{
                [PPHUD dismiss];
                self.isAuthenticating = NO;
                [self setInteractionEnabled:YES];
                [self updateContinuePhoneButtonState];
                
                if (error) {
                    [self notifySignInFailure:error];
                    [PPAlertHelper showErrorIn:self
                                         title:kLang(@"auth_apple_failed_title")
                                      subtitle:[self pp_localizedAuthMessageForError:error
                                                                        fallbackKey:@"auth_apple_no_token"]];
                    return;
                }
                
                self.appleSignInRetryCount = 0;
                [self handleSuccessfulAuth:authResult method:PPSignInMethodApple];
            });
        }];
    }
}

- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithError:(NSError *)error API_AVAILABLE(ios(13.0)) {
    PPDispatchMain(^{
        self.isAuthenticating = NO;
        [self setInteractionEnabled:YES];
        [self updateContinuePhoneButtonState];
        [PPHUD dismiss];
        [self notifySignInFailure:error];
        [PPAlertHelper showWarningIn:self
                             title:kLang(@"auth_apple_failed_title")
                          subtitle:[self pp_localizedAuthMessageForError:error
                                                              fallbackKey:@"auth_apple_no_token"]];
    });
}

- (ASPresentationAnchor)presentationAnchorForAuthorizationController:(ASAuthorizationController *)controller API_AVAILABLE(ios(13.0)) {
    return self.view.window;
}

#pragma mark - Post-Auth Handling

- (void)handleSuccessfulAuth:(FIRAuthDataResult *)authResult method:(PPSignInMethod)method {
    PPAuthDebugLog(@"[Auth] Successful %@ sign-in.", [self stringFromSignInMethod:method]);
    [self.view endEditing:YES];
    
    [PPHUD showLoading:kLang(@"auth_setting_up_account")];

    [self fetchOrCreateUserModelWithAuthResult:authResult completion:^(UserModel *userModel, NSError *error) {
        [PPHUD dismiss];
        
        if (error) {
            [self notifySignInFailure:error];
            [PPAlertHelper showErrorIn:self
                                 title:kLang(@"auth_error_title")
                              subtitle:[self pp_localizedAuthMessageForError:error
                                                                 fallbackKey:@"auth_error_message"]];
            return;
        }
        
        [PPHUD showSuccess:kLang(@"auth_signin_success_title")];

        // ----------------------------------------------------
        // STEP 1 — Check if user needs to complete profile
        // ----------------------------------------------------

        BOOL needsProfile =
        (
            userModel.UserName.length == 0 ||
            userModel.UserName.length < 3 ||
            [userModel.UserName hasPrefix:@"user"] ||     // auto-generated → ask user to customize
            userModel.MobileNo.length == 0 ||
            userModel.UserEmail.length == 0
        );

        // ----------------------------------------------------
        // STEP 2 — If incomplete → show PPCompleteProfileVC
        // ----------------------------------------------------

        if (needsProfile) {
            PPCompleteProfileVC *vc = [[PPCompleteProfileVC alloc] initWithUser:userModel];

            vc.onProfileCompleted = ^(UserModel *userModel) {
                PPDispatchMain(^{
                    if (self.signInSuccess) {
                        self.signInSuccess(userModel);
                    }

                    if (self.shouldAutoDismissOnSuccess) {
                        [self dismissViewControllerAnimated:YES completion:nil];
                    }
                });
            };

            [PPFunc presentSheetFrom:self sheetVC:vc detentStyle:PPSheetDetentStyle80];
            return; // stop flow here
        }

        // ----------------------------------------------------
        // STEP 3 — Profile is complete, continue as normal
        // ----------------------------------------------------

        if (self.signInSuccess) {
            self.signInSuccess(userModel);
        }

        if (self.shouldAutoDismissOnSuccess) {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }];
}

- (void)completeUserFetchWithUser:(UserModel *)user
                            error:(NSError *)error
                       completion:(void(^)(UserModel *user, NSError *error))completion {
    if (!completion) {
        return;
    }
    PPDispatchMain(^{
        completion(user, error);
    });
}

- (void)fetchOrCreateUserModelWithAuthResult:(FIRAuthDataResult *)authResult
                                  completion:(void(^)(UserModel *user, NSError *error))completion {
    FIRUser *authUser = authResult.user;
    if (!authUser.uid.length) {
        NSError *missingAuthError = [NSError errorWithDomain:@"PPAuth"
                                                         code:401
                                                     userInfo:@{NSLocalizedDescriptionKey: kLang(@"error_missing_authenticated_user")}];
        [self completeUserFetchWithUser:nil error:missingAuthError completion:completion];
        return;
    }

    BOOL isNewUser = authResult.additionalUserInfo.isNewUser;
    if (isNewUser && !self.shouldCreateUserDocument) {
        NSError *createDisabledError = [NSError errorWithDomain:@"PPAuth"
                                                           code:403
                                                       userInfo:@{NSLocalizedDescriptionKey: kLang(@"error_user_creation_is_disabled")}];
        [self completeUserFetchWithUser:nil error:createDisabledError completion:completion];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [UsrMgr handlePostSignInForAuthResult:authResult
                                isNewUser:isNewUser
                                completion:^(UserModel * _Nullable syncedUser, NSError * _Nullable syncError) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        if (syncError && !syncedUser) {
            [self completeUserFetchWithUser:nil error:syncError completion:completion];
            return;
        }

        BOOL isBlockedAccountError =
            syncError &&
            [syncError.domain isEqualToString:FUErrorDomain] &&
            syncError.code == FUErrorCodePermissionDenied;
        if (isBlockedAccountError) {
            [self completeUserFetchWithUser:nil error:syncError completion:completion];
            return;
        }

        UserModel *resolvedUser = syncedUser ?: UsrMgr.currentUser;
        if (!resolvedUser) {
            [UsrMgr reloadCurrentUserWithCompletion:^(UserModel * _Nullable user, NSError * _Nullable reloadError) {
                [self completeUserFetchWithUser:user error:reloadError completion:completion];
            }];
            return;
        }

        NSString *pushToken = PPSafeString([[NSUserDefaults standardUserDefaults] valueForKey:kPPDefaultsUserTokenKey]) ?: @"";
        if (pushToken.length > 0) {
            resolvedUser.PPUserTokenID = pushToken;
            [UsrMgr updateCurrentUserWithPPUserTokenID:pushToken];
        }

        // Bootstrap country/mobile metadata once for fresh accounts when we can infer safe values.
        NSMutableDictionary<NSString *, id> *bootstrapUpdates = [NSMutableDictionary dictionary];
        CountryCodeModel *bootstrapCountry = self.autoDetectedCountry;
        if (bootstrapCountry.ID <= 0) {
            NSString *currentCountryISO = PPSafeString(CitiesManager.shared.CurrentCountry.iso);
            if (currentCountryISO.length > 0) {
                NSArray<CountryCodeModel *> *countries =
                    [GM getMiddleEastCountriesForLanguage:[Language currentLanguageCode]];
                bootstrapCountry = [self pp_countryWithISOCode:currentCountryISO inCountries:countries];
            }
        }

        NSString *existingMobile = [PPSafeString(resolvedUser.MobileNo)
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        if (isNewUser && bootstrapCountry.ID > 0) {
            bootstrapUpdates[@"CountryID"] = @(bootstrapCountry.ID);
        }
        NSString *countryName = [PPSafeString(bootstrapCountry.country)
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (isNewUser && countryName.length > 0) {
            bootstrapUpdates[@"CountryName"] = countryName;
        }

        NSString *normalizedDialCode = [self normalizedCountryCode:bootstrapCountry.phoneCode];
        if (isNewUser && normalizedDialCode.length > 0) {
            bootstrapUpdates[@"CountryDialCode"] = normalizedDialCode;
        }

        NSString *isoCode = [[PPSafeString(bootstrapCountry.isoCountryCode)
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
        if (isNewUser && isoCode.length == 2) {
            bootstrapUpdates[@"CountryIsoCode"] = isoCode;
        }

        NSString *phoneDialCode = [self normalizedCountryCode:self.currentPhoneCode];
        if (phoneDialCode.length == 0) {
            phoneDialCode = normalizedDialCode;
        }
        NSString *candidateMobile = @"";
        if (self.normalizedPhoneDigits.length > 0 && phoneDialCode.length > 0) {
            candidateMobile = [NSString stringWithFormat:@"%@%@",
                               phoneDialCode,
                               self.normalizedPhoneDigits];
        }
        if (existingMobile.length == 0 && candidateMobile.length > 0) {
            bootstrapUpdates[@"MobileNo"] = candidateMobile;
        }

        if (bootstrapUpdates.count > 0) {
            [UsrMgr updateCurrentUserProfileWithValues:bootstrapUpdates completion:^(NSError * _Nullable updateError) {
                if (updateError) {
                    NSLog(@"[Auth] Bootstrap user metadata update failed: %@", updateError.localizedDescription);
                }
                [UsrMgr reloadCurrentUserWithCompletion:^(UserModel * _Nullable refreshedUser, NSError * _Nullable reloadError) {
                    UserModel *finalUser = refreshedUser ?: resolvedUser;
                    NSError *finalError = finalUser ? nil : (syncError ?: updateError ?: reloadError);
                    [self completeUserFetchWithUser:finalUser error:finalError completion:completion];
                }];
            }];
            return;
        }

        [self completeUserFetchWithUser:resolvedUser error:nil completion:completion];
    }];
}

#pragma mark - Username Generator (Enhanced)

- (void)generateSmartUsernameForUser:(UserModel *)userModel
                           authUser:(FIRUser *)user
                          completion:(void(^)(NSString *username))completion {

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSString *base = @"";
        
        // 1. Phone login → use last 3–4 digits
        if (user.phoneNumber.length >= 4) {
            NSString *last = [user.phoneNumber substringFromIndex:user.phoneNumber.length - 4];
            base = [NSString stringWithFormat:@"user%@", last];
        }
        // 2. Email login → use prefix
        else if (user.email.length > 0) {
            NSString *rawPrefix = [[user.email componentsSeparatedByString:@"@"] firstObject] ?: @"";
            NSRange fullRange = NSMakeRange(0, rawPrefix.length);

            NSString *emailPrefix = [rawPrefix stringByReplacingOccurrencesOfString:@"[^a-zA-Z0-9]"
                                                                         withString:@""
                                                                            options:NSRegularExpressionSearch
                                                                              range:fullRange];

            base = [NSString stringWithFormat:@"user%@", emailPrefix.lowercaseString];
        }
        // 3. Random pet word + number
        else {
            NSArray *petWords = @[ @"paws", @"whisker", @"furball", @"puppy", @"kitty", @"pawprint" ];
            NSString *word = petWords[arc4random_uniform((uint32_t)petWords.count)];
            base = [NSString stringWithFormat:@"%@%d", word, arc4random_uniform(999)];
        }

        // 4. Remove profanity / special chars / spaces
        base = [self sanitizeUsername:base];

        completion(base);
    });
}

- (NSString *)sanitizeUsername:(NSString *)input {

    // Remove special chars
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"];
    NSMutableString *filtered = [NSMutableString string];

    for (int i = 0; i < input.length; i++) {
        unichar c = [input characterAtIndex:i];
        if ([allowed characterIsMember:c]) {
            [filtered appendFormat:@"%c", c];
        }
    }

    NSString *clean = filtered.lowercaseString;

    // Profanity filter
    NSArray *badWords = @[ @"fuck", @"shit", @"bitch", @"ass", @"sex", @"dick" ];
    for (NSString *bad in badWords) {
        if ([clean containsString:bad]) {
            clean = [clean stringByReplacingOccurrencesOfString:bad withString:@"user"];
        }
    }

    // Trim long usernames
    if (clean.length > 20) {
        clean = [clean substringToIndex:20];
    }

    return clean;
}

- (void)ensureUniqueUsername:(NSString *)base completion:(void(^)(NSString *unique))completion {
    NSString *normalizedBase = [self sanitizeUsername:base ?: @""];
    if (normalizedBase.length == 0) {
        normalizedBase = [NSString stringWithFormat:@"user%u", arc4random_uniform(10000)];
    }
    
    FIRCollectionReference *users = [[FIRFirestore firestore] collectionWithPath:kPPUsersCollection];
    [self checkUsernameCandidateWithBase:normalizedBase
                                  suffix:0
                                   users:users
                              completion:completion];
}

- (void)checkUsernameCandidateWithBase:(NSString *)normalizedBase
                                suffix:(NSInteger)suffix
                                 users:(FIRCollectionReference *)users
                            completion:(void(^)(NSString *unique))completion {
    NSString *candidate = suffix == 0
    ? normalizedBase
    : [NSString stringWithFormat:@"%@%ld", normalizedBase, (long)suffix];
    
    [[users queryWhereField:kPPFirestoreUserNameField isEqualTo:candidate]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            NSString *fallback = [NSString stringWithFormat:@"%@%u", normalizedBase, arc4random_uniform(10000)];
            completion(fallback);
            return;
        }
        
        if (snapshot.documents.count == 0) {
            completion(candidate);
            return;
        }
        
        [self checkUsernameCandidateWithBase:normalizedBase
                                      suffix:suffix + 1
                                       users:users
                                  completion:completion];
    }];
}

#pragma mark - Utility Methods

- (void)animateAuthEntranceIfNeeded {
    if (self.didRunEntranceAnimation) {
        return;
    }
    self.didRunEntranceAnimation = YES;

    NSArray<UIView *> *views = @[
        self.heroBadgeView ?: UIView.new,
        self.titleLabel ?: UIView.new,
        self.subtitleLabel ?: UIView.new,
        self.phoneSectionCard ?: UIView.new,
        self.separatorView ?: UIView.new,
        self.socialSectionCard ?: UIView.new,
        self.closeButton ?: UIView.new
    ];

    [views enumerateObjectsUsingBlock:^(UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 18.0);
        [UIView animateWithDuration:0.56
                              delay:0.04 * idx
             usingSpringWithDamping:0.88
              initialSpringVelocity:0.18
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
        (void)stop;
    }];
}

- (void)startAmbientGlowAnimationsIfNeeded {
    if (self.didStartAmbientGlowAnimation) {
        return;
    }
    self.didStartAmbientGlowAnimation = YES;

    [self pp_startFloatingAnimationForGlowView:self.backgroundTopGlowView
                                   translation:CGPointMake(14.0, -18.0)
                                         scale:1.08
                                   targetAlpha:0.86
                                      duration:7.6];
    [self pp_startFloatingAnimationForGlowView:self.backgroundBottomGlowView
                                   translation:CGPointMake(-18.0, 16.0)
                                         scale:1.10
                                   targetAlpha:0.72
                                      duration:8.8];
}

- (void)pp_startFloatingAnimationForGlowView:(UIView *)glowView
                                 translation:(CGPoint)translation
                                       scale:(CGFloat)scale
                                 targetAlpha:(CGFloat)targetAlpha
                                    duration:(NSTimeInterval)duration {
    if (!glowView) {
        return;
    }

    [UIView animateWithDuration:duration
                          delay:0.0
                        options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        glowView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(translation.x, translation.y),
                                                     CGAffineTransformMakeScale(scale, scale));
        glowView.alpha = targetAlpha;
    } completion:nil];
}

- (void)pp_addPressAnimationToButton:(UIButton *)button {
    if (!button) {
        return;
    }
    [button addTarget:self action:@selector(pp_pressDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(pp_pressUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
}

- (void)pp_pressDown:(UIButton *)button {
    [UIView animateWithDuration:0.08
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        button.transform = CGAffineTransformMakeScale(0.965, 0.965);
        button.layer.shadowOpacity = MAX(button.layer.shadowOpacity * 0.7, 0.04);
    } completion:nil];
}

- (void)pp_pressUp:(UIButton *)button {
    [UIView animateWithDuration:0.22
                          delay:0.0
         usingSpringWithDamping:0.78
          initialSpringVelocity:0.45
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        button.transform = CGAffineTransformIdentity;
        if (button == self.googleSignInButton) {
            button.layer.shadowOpacity = 0.08;
        } else if (button == self.appleSignInButton) {
            button.layer.shadowOpacity = 0.10;
        } else {
            button.layer.shadowOpacity = 0.0;
        }
    } completion:nil];
}

- (void)notifySignInFailure:(NSError *)error {
    if (!error || !self.signInFailure) {
        return;
    }
    self.signInFailure(error);
}

- (void)setInteractionEnabled:(BOOL)enabled {
    self.appleSignInButton.enabled = enabled;
    self.googleSignInButton.enabled = enabled;
    self.phoneNumberField.enabled = enabled;
    self.countryCodePickerBtn.enabled = enabled;
    self.countryCodePickerBtn.userInteractionEnabled = enabled;
    self.closeButton.enabled = enabled;
    
    CGFloat alpha = enabled ? 1.0 : 0.6;
    self.appleSignInButton.alpha = alpha;
    self.googleSignInButton.alpha = alpha;
    self.closeButton.alpha = alpha;
    
    if (!enabled) {
        self.continuePhoneButton.enabled = NO;
        self.continuePhoneButton.alpha = 0.6;
    } else {
        [self updateContinuePhoneButtonState];
    }
}

- (NSString *)stringFromSignInMethod:(PPSignInMethod)method {
    switch (method) {
        case PPSignInMethodPhone: return @"Phone";
        case PPSignInMethodApple: return @"Apple";
        case PPSignInMethodGoogle: return @"Google";
        default: return @"Unknown";
    }
}

#pragma mark - Security Utilities

- (NSString *)randomNonce:(NSInteger)length {
    if (length <= 0) {
        return @"";
    }
    NSString *characterSet = @"0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._";
    NSMutableString *result = [NSMutableString stringWithCapacity:length];
    
    while (result.length < length) {
        uint8_t random = 0;
        int status = SecRandomCopyBytes(kSecRandomDefault, 1, &random);
        if (status != errSecSuccess) {
            random = (uint8_t)arc4random_uniform((uint32_t)characterSet.length);
        }
        if (random < characterSet.length) {
            unichar character = [characterSet characterAtIndex:random];
            [result appendFormat:@"%C", character];
        }
    }
    
    return result;
}

- (NSString *)stringBySha256HashingString:(NSString *)input {
    const char *string = [input UTF8String];
    unsigned char result[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(string, (CC_LONG)strlen(string), result);
    
    NSMutableString *hashed = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hashed appendFormat:@"%02x", result[i]];
    }
    return hashed;
}

@end
