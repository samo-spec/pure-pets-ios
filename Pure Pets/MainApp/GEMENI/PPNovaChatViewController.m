//
//  PPNovaChatViewController.m
//  Pure Pets
//

#import "PPNovaChatViewController.h"
#import "ChatMessageModel.h"
#import "ChatMessageCell.h"
#import "PPNovaProductMessageCell.h"
#import "PPChatInputBarView.h"
#import "EnumValues.h"
#import "AppManager.h"
#import "PPNavigationController.h"
#import "PetAccessoryManager.h"
#import "CartManager.h"
#import "CartItem.h"
#import "PPHUD.h"
#import <IQKeyboardManager/IQKeyboardManager.h>

@interface PPNovaChatViewController () <UITableViewDelegate, UITableViewDataSource, PPChatInputBarViewDelegate, PPNovaProductMessageCellDelegate>

@property (nonatomic, strong) UIView *novaHeaderView;
@property (nonatomic, strong) UIView *headerGlowHost;
@property (nonatomic, strong) CAGradientLayer *headerGlowLayer;
@property (nonatomic, strong) UIView *headerHairlineHost;
@property (nonatomic, strong) CAGradientLayer *headerHairlineLayer;
@property (nonatomic, strong) UIView *headerLiveCapsule;
@property (nonatomic, strong) UIView *statusDot;
@property (nonatomic, strong) UIVisualEffectView *typingContainer;
@property (nonatomic, strong) UILabel *typingLabel;
@property (nonatomic, copy)   NSArray<UIView *> *typingDots;

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<ChatMessageModel *> *messages;
@property (nonatomic, strong) PPChatInputBarView *inputbar;
@property (nonatomic, strong) NSLayoutConstraint *inputBarBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *typingBottomConstraint;
@property (nonatomic, strong) UIButton *bottomFillBlurView;
@property (nonatomic, copy, nullable) NSString *novaPendingPetType;
@property (nonatomic, strong) FIRHTTPSCallable *novaCallable;

// Nova Product / Cart Context
@property (nonatomic, strong, nullable) PetAccessory *lastSuggestedProduct;
@property (nonatomic, strong, nullable) NSArray<PetAccessory *> *lastShownProducts;
@property (nonatomic, strong, nullable) PetAccessory *pendingCartProduct;

// In-session local memory. Lives only while this VC is on screen.
@property (nonatomic, copy, nullable) NSString *novaMemoryPetType;
@property (nonatomic, copy, nullable) NSString *novaMemoryNeed;
@property (nonatomic, copy, nullable) NSString *novaMemoryLanguage;
@property (nonatomic, assign) BOOL novaHasShownGreeting;

@property (nonatomic, assign) BOOL previousIQEnabled;
@property (nonatomic, assign) BOOL previousToolbarEnabled;

@end

@implementation PPNovaChatViewController

+ (void)presentNovaFromViewController:(UIViewController *)presentingVC {
    PPNovaChatViewController *novaVC = [[PPNovaChatViewController alloc] init];
    if (@available(iOS 15.0, *)) {
        novaVC.modalPresentationStyle = UIModalPresentationPageSheet;
        UISheetPresentationController *sheet = novaVC.sheetPresentationController;
        if (sheet) {
            if (@available(iOS 16.0, *)) {
                UISheetPresentationControllerDetent *customDetent = [UISheetPresentationControllerDetent customDetentWithIdentifier:@"Nova85" resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
                    return UIScreen.mainScreen.bounds.size.height * 0.85;
                }];
                sheet.detents = @[customDetent, [UISheetPresentationControllerDetent largeDetent]];
            } else {
                sheet.detents = @[[UISheetPresentationControllerDetent largeDetent]];
            }
            sheet.prefersGrabberVisible = YES;
            sheet.preferredCornerRadius = 42.0;
        }
    } else {
        novaVC.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    [presentingVC presentViewController:novaVC animated:YES completion:nil];
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"";
    self.view.backgroundColor = AppBackgroundClr;
    self.messages = [NSMutableArray array];

    [self setupNovaBackend];
    [self setupNovaHeader];
    [self setupInputView];
    [self setupTypingIndicator];
    [self setupTableView];
    [self setupBottomFillBlur];

    [self registerForKeyboardNotifications];

    // Delayed load for premium motion feel
    self.novaHeaderView.alpha = 0.0;
    self.novaHeaderView.transform = CGAffineTransformMakeTranslation(0, -10);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self insertNovaGreeting];
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.previousIQEnabled = [IQKeyboardManager sharedManager].enable;
    self.previousToolbarEnabled = [IQKeyboardManager sharedManager].enableAutoToolbar;
    [IQKeyboardManager sharedManager].enable = NO;
    [IQKeyboardManager sharedManager].enableAutoToolbar = NO;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();

    if (reduceMotion) {
        self.novaHeaderView.alpha = 1.0;
        self.novaHeaderView.transform = CGAffineTransformIdentity;
    } else {
        [UIView animateWithDuration:0.46
                              delay:0.05
             usingSpringWithDamping:0.92
              initialSpringVelocity:0.3
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.novaHeaderView.alpha = 1.0;
            self.novaHeaderView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }

    [self pp_startHeaderLiveAnimations];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [IQKeyboardManager sharedManager].enable = self.previousIQEnabled;
    [IQKeyboardManager sharedManager].enableAutoToolbar = self.previousToolbarEnabled;

    [self pp_stopHeaderLiveAnimations];
    [self pp_stopTypingDotsAnimation];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    // Resize CAGradientLayer frames in sync with the header layout (sheet resize, rotation).
    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    if (self.headerGlowHost && self.headerGlowLayer) {
        self.headerGlowLayer.frame = self.headerGlowHost.bounds;
    }
    if (self.headerHairlineHost && self.headerHairlineLayer) {
        self.headerHairlineLayer.frame = self.headerHairlineHost.bounds;
    }

    [CATransaction commit];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.statusDot.layer removeAllAnimations];
    [self.headerGlowLayer removeAllAnimations];
    for (UIView *dot in self.typingDots) {
        [dot.layer removeAllAnimations];
    }
}

#pragma mark - Backend

- (void)setupNovaBackend {
    FIRFunctions *functions = [FIRFunctions functionsForRegion:@"us-central1"];
    self.novaCallable = [functions HTTPSCallableWithName:@"geminiProxy"];
}

- (void)sendNovaRequestForUserText:(NSString *)userText {
    NSString *trimmedText = [userText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmedText.length == 0) {
        [self hideNovaTyping];
        return;
    }

    // Update local session memory BEFORE we build the context payload.
    [self pp_updateMemoryFromUserText:trimmedText];

    if (!self.novaCallable) {
        [self hideNovaTyping];
        [self insertNovaReplyForUserText:trimmedText];
        return;
    }

    NSDictionary *payload = @{
        @"prompt": trimmedText,
        @"context": [self pp_currentContextDictionary]
    };

    __weak typeof(self) weakSelf = self;
    [self.novaCallable callWithObject:payload
                           completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            
            [self hideNovaTyping];
            
            if (error) {
                NSLog(@"[PPNovaChat] geminiProxy error: %@", error.localizedDescription);
                [self insertNovaReplyForUserText:trimmedText];
                return;
            }
            
            NSString *replyText = nil;
            if ([result.data isKindOfClass:NSDictionary.class]) {
                NSDictionary *data = (NSDictionary *)result.data;
                id textValue = data[@"text"];
                if ([textValue isKindOfClass:NSString.class]) {
                    replyText = (NSString *)textValue;
                }
            }
            
            replyText = [replyText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (replyText.length == 0) {
                [self insertNovaReplyForUserText:trimmedText];
                return;
            }
            
            [self addNovaMessage:replyText];
        });
    }];
}

#pragma mark - Initial Data

- (void)insertNovaGreeting {
    NSString *greeting = Language.isRTL
        ? @"أهلاً، أنا نوفا من بيور بتس. أقدر أساعدك في المنتجات، الطلبات، أو نصائح العناية بحيوانك."
        : @"Hi, I'm Nova from Pure Pets. I can help with products, orders, or pet care guidance.";

    [self addMessageWithText:greeting isIncoming:YES];

    // The greeting bubble is the only welcome the user should ever see in this session.
    // From now on, the backend is told isFirstAssistantMessage=false so it does not re-greet.
    self.novaHasShownGreeting = YES;
    self.novaMemoryLanguage = Language.isRTL ? @"ar" : @"en";
}

- (void)insertNovaReplyForUserText:(NSString *)userText {
    NSString *trimmedText = [userText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    // Memory is updated by sendNovaRequestForUserText before we get here, but in case
    // the local fallback runs from another path, do it here too — idempotent.
    [self pp_updateMemoryFromUserText:trimmedText];

    BOOL isArabic = [self.novaMemoryLanguage isEqualToString:@"ar"]
                  || [self textContainsArabic:trimmedText];

    NSString *petType = self.novaMemoryPetType;
    NSString *needType = self.novaMemoryNeed;

    NSString *reply = [self pp_buildLocalFallbackReplyArabic:isArabic
                                                     petType:petType
                                                        need:needType];
    [self addMessageWithText:reply isIncoming:YES];
}

// Memory-aware local fallback. Never includes a greeting/intro because the screen
// already showed one when it opened (novaHasShownGreeting is YES from then on).
- (NSString *)pp_buildLocalFallbackReplyArabic:(BOOL)isArabic
                                       petType:(NSString *)petType
                                          need:(NSString *)need {
    BOOL hasPet = petType.length > 0;
    BOOL hasNeed = need.length > 0;

    if (hasPet && hasNeed) {
        if (isArabic) {
            return [NSString stringWithFormat:
                    @"تمام، لـ%@ الذي تربيه أقدر أساعدك تختار %@ مناسب من بيور بتس. تحب خيار اقتصادي أو مميز؟",
                    [self pp_arabicPetWord:petType], [self pp_arabicNeedWord:need]];
        }
        return [NSString stringWithFormat:
                @"Got it — for your %@, I can help pick the right %@ from Pure Pets. Want a budget option or a premium pick?",
                petType, need];
    }

    if (hasPet) {
        if (isArabic) {
            return [NSString stringWithFormat:
                    @"للـ%@ الخاص بك، تبحث عن أكل، قفص، ألعاب، أو عناية؟",
                    [self pp_arabicPetWord:petType]];
        }
        return [NSString stringWithFormat:
                @"For your %@, are you looking for food, cage, toys, or care?",
                petType];
    }

    if (hasNeed) {
        if (isArabic) {
            return [NSString stringWithFormat:
                    @"تمام، تبحث عن %@. أي حيوان عندك؟ (قط، كلب، طائر، سمك...)",
                    [self pp_arabicNeedWord:need]];
        }
        return [NSString stringWithFormat:
                @"Got it, looking for %@. Which pet — cat, dog, bird, or fish?",
                need];
    }

    if (isArabic) {
        return @"اكتب لي نوع حيوانك (قط، كلب، طائر) وما تبحث عنه (أكل، قفص، ألعاب).";
    }
    return @"Tell me your pet (cat, dog, bird) and what you need (food, cage, toys).";
}

- (BOOL)textContainsArabic:(NSString *)text {
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if (c >= 0x0600 && c <= 0x06FF) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Local Session Memory

- (void)pp_updateMemoryFromUserText:(NSString *)text {
    if (text.length == 0) return;

    NSString *lower = [text lowercaseString];
    BOOL isArabic = [self textContainsArabic:text];

    // Language sticks to the user's last expressed language; never overwritten to nil.
    self.novaMemoryLanguage = isArabic ? @"ar" : @"en";

    NSArray<NSDictionary *> *petKeywords = @[
        @{@"label": @"cat",     @"keys": @[@"cat", @"cats", @"kitten", @"kitty",
                                            @"قط", @"قطة", @"قطه", @"قطتي", @"قطط", @"بسة", @"بسه", @"هر", @"هرة"]},
        @{@"label": @"dog",     @"keys": @[@"dog", @"dogs", @"puppy", @"pup",
                                            @"كلب", @"كلبة", @"كلبه", @"كلبي", @"جرو", @"كلاب"]},
        @{@"label": @"bird",    @"keys": @[@"bird", @"birds",
                                            @"طير", @"طائر", @"طيور", @"عصفور", @"عصافير"]},
        @{@"label": @"parrot",  @"keys": @[@"parrot", @"parrots", @"cockatiel", @"cockatoo", @"budgie",
                                            @"ببغاء", @"ببغاوات", @"كاسكو", @"درة", @"كروان"]},
        @{@"label": @"fish",    @"keys": @[@"fish", @"fishes", @"aquarium",
                                            @"سمك", @"سمكة", @"سمكه", @"أسماك", @"اسماك"]},
        @{@"label": @"rabbit",  @"keys": @[@"rabbit", @"rabbits", @"bunny",
                                            @"أرنب", @"ارنب", @"أرانب", @"ارانب"]},
        @{@"label": @"hamster", @"keys": @[@"hamster", @"hamsters",
                                            @"هامستر", @"هامستار"]},
        @{@"label": @"turtle",  @"keys": @[@"turtle", @"turtles", @"tortoise",
                                            @"سلحفاة", @"سلحفاه", @"سلاحف"]}
    ];

    for (NSDictionary *p in petKeywords) {
        BOOL matched = NO;
        for (NSString *kw in p[@"keys"]) {
            if ([lower containsString:kw] || [text containsString:kw]) {
                matched = YES;
                break;
            }
        }
        if (matched) {
            self.novaMemoryPetType = p[@"label"];
            break;
        }
    }

    NSArray<NSDictionary *> *needKeywords = @[
        @{@"label": @"food",     @"keys": @[@"food", @"feed", @"meal", @"kibble", @"treat", @"snack",
                                             @"dry food", @"wet food", @"dry", @"wet",
                                             @"أكل", @"اكل", @"طعام", @"غذاء", @"دراي", @"وجبة", @"وجبه", @"تغذية"]},
        @{@"label": @"cage",     @"keys": @[@"cage", @"carrier", @"crate", @"kennel", @"bed",
                                             @"aquarium", @"tank",
                                             @"قفص", @"أقفاص", @"اقفاص", @"حاملة", @"حقيبة", @"حقيبه",
                                             @"بيت", @"حوض", @"ناقلة", @"كاريير"]},
        @{@"label": @"toy",      @"keys": @[@"toy", @"toys", @"play", @"ball", @"chew",
                                             @"لعبة", @"لعبه", @"لعب", @"ألعاب", @"العاب", @"كرة"]},
        @{@"label": @"medicine", @"keys": @[@"medicine", @"medication", @"vitamin", @"vitamins",
                                             @"supplement", @"supplements", @"treatment",
                                             @"دواء", @"أدوية", @"ادوية", @"فيتامين", @"فيتامينات", @"علاج"]},
        @{@"label": @"care",     @"keys": @[@"care", @"grooming", @"groom", @"shampoo", @"brush",
                                             @"bath", @"nail", @"clean",
                                             @"عناية", @"عنايه", @"شامبو", @"تنظيف", @"نظافة",
                                             @"تمشيط", @"استحمام", @"تقليم"]},
        @{@"label": @"litter",   @"keys": @[@"litter", @"litter box", @"potty", @"toilet", @"sand",
                                             @"رمل", @"فضلات", @"ليتر"]}
    ];

    for (NSDictionary *n in needKeywords) {
        BOOL matched = NO;
        for (NSString *kw in n[@"keys"]) {
            if ([lower containsString:kw] || [text containsString:kw]) {
                matched = YES;
                break;
            }
        }
        if (matched) {
            self.novaMemoryNeed = n[@"label"];
            break;
        }
    }
}

- (NSString *)pp_arabicPetWord:(NSString *)label {
    NSDictionary *map = @{
        @"cat": @"قطة", @"dog": @"كلب", @"bird": @"طائر", @"parrot": @"ببغاء",
        @"fish": @"سمكة", @"rabbit": @"أرنب", @"hamster": @"هامستر", @"turtle": @"سلحفاة"
    };
    return map[label] ?: label;
}

- (NSString *)pp_arabicNeedWord:(NSString *)label {
    NSDictionary *map = @{
        @"food": @"أكل", @"cage": @"قفص", @"toy": @"لعبة",
        @"medicine": @"دواء", @"care": @"عناية", @"litter": @"رمل"
    };
    return map[label] ?: label;
}

- (NSString *)pp_buildPreviousUserFactsString {
    BOOL isArabic = [self.novaMemoryLanguage isEqualToString:@"ar"];
    NSMutableArray<NSString *> *bits = [NSMutableArray array];

    if (self.novaMemoryPetType.length > 0) {
        if (isArabic) {
            [bits addObject:[NSString stringWithFormat:@"المستخدم لديه %@", [self pp_arabicPetWord:self.novaMemoryPetType]]];
        } else {
            [bits addObject:[NSString stringWithFormat:@"User has a %@", self.novaMemoryPetType]];
        }
    }
    if (self.novaMemoryNeed.length > 0) {
        if (isArabic) {
            [bits addObject:[NSString stringWithFormat:@"يبحث عن %@", [self pp_arabicNeedWord:self.novaMemoryNeed]]];
        } else {
            [bits addObject:[NSString stringWithFormat:@"is looking for %@", self.novaMemoryNeed]];
        }
    }
    if (bits.count == 0) return @"";

    NSString *joiner = isArabic ? @" و" : @" and ";
    return [bits componentsJoinedByString:joiner];
}

- (NSDictionary *)pp_currentContextDictionary {
    NSMutableDictionary *ctx = [NSMutableDictionary dictionary];
    if (self.novaMemoryPetType.length > 0)  ctx[@"petType"] = self.novaMemoryPetType;
    if (self.novaMemoryNeed.length > 0)     ctx[@"need"] = self.novaMemoryNeed;
    if (self.novaMemoryLanguage.length > 0) ctx[@"language"] = self.novaMemoryLanguage;

    // Greeting was already shown locally — tell the backend not to re-greet.
    ctx[@"isFirstAssistantMessage"] = @(!self.novaHasShownGreeting);

    NSString *facts = [self pp_buildPreviousUserFactsString];
    if (facts.length > 0) {
        ctx[@"previousUserFacts"] = facts;
    }
    return [ctx copy];
}

#pragma mark - Setup UI

- (void)setupNovaHeader {
    // Minimal premium glass: ultra-thin material instead of prominent.
    UIBlurEffectStyle blurStyle = UIBlurEffectStyleProminent;
    if (@available(iOS 13.0, *)) {
        blurStyle = UIBlurEffectStyleSystemUltraThinMaterial;
    }
    UIVisualEffect *blurEffect = [UIBlurEffect effectWithStyle:blurStyle];
    UIVisualEffectView *header = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:header];
    self.novaHeaderView = header;

    UIView *contentView = header.contentView;

    // 1) Ambient brand glow plate (lives behind everything, breathes when visible).
    UIView *glowHost = [[UIView alloc] init];
    glowHost.translatesAutoresizingMaskIntoConstraints = NO;
    glowHost.userInteractionEnabled = NO;
    glowHost.backgroundColor = UIColor.clearColor;
    [contentView addSubview:glowHost];
    self.headerGlowHost = glowHost;

    UIColor *glowColor = AppPrimaryClr ?: [UIColor colorWithRed:0.98 green:0.70 blue:0.42 alpha:1.0];
    CAGradientLayer *glow = [CAGradientLayer layer];
    glow.colors = @[
        (id)[glowColor colorWithAlphaComponent:0.22].CGColor,
        (id)[glowColor colorWithAlphaComponent:0.10].CGColor,
        (id)[glowColor colorWithAlphaComponent:0.0].CGColor
    ];
    glow.locations = @[@0.0, @0.55, @1.0];
    if (@available(iOS 12.0, *)) {
        glow.type = kCAGradientLayerRadial;
    }
    glow.startPoint = CGPointMake(0.5, 0.5);
    glow.endPoint = CGPointMake(1.0, 1.0);
    glow.opacity = 0.0; // revealed by pp_startHeaderLiveAnimations
    [glowHost.layer addSublayer:glow];
    self.headerGlowLayer = glow;

    // 2) Title + subtitle.
    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.font = [GM boldFontWithSize:PPFontTitle1] ?: [UIFont systemFontOfSize:28.0 weight:UIFontWeightBold];
    nameLabel.textColor = AppPrimaryTextClr;
    nameLabel.text = Language.isRTL ? @"نوفا" : @"Nova";
    nameLabel.textAlignment = NSTextAlignmentCenter;
    if (!Language.isRTL) {
        // Subtle premium tracking on the wordmark.
        NSAttributedString *attr = [[NSAttributedString alloc]
                                    initWithString:nameLabel.text
                                    attributes:@{ NSKernAttributeName: @1.4 }];
        nameLabel.attributedText = attr;
    }
    [contentView addSubview:nameLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:PPFontCaption1 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [AppSecondaryTextClr colorWithAlphaComponent:0.92];
    subtitleLabel.text = Language.isRTL ? @"المساعد الذكي من بيور بتس" : @"Pure Pets smart assistant";
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    [contentView addSubview:subtitleLabel];

    // 3) Live capsule: ultra-thin glass pill with breathing dot + status text.
    UIVisualEffectView *liveCapsule;
    if (@available(iOS 13.0, *)) {
        liveCapsule = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]];
    } else {
        liveCapsule = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular]];
    }
    liveCapsule.translatesAutoresizingMaskIntoConstraints = NO;
    liveCapsule.layer.cornerRadius = 13.0;
    liveCapsule.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        liveCapsule.layer.cornerCurve = kCACornerCurveContinuous;
    }
    liveCapsule.layer.borderWidth = 1.0 / [UIScreen mainScreen].scale;
    liveCapsule.layer.borderColor = [[UIColor separatorColor] colorWithAlphaComponent:0.55].CGColor;
    [contentView addSubview:liveCapsule];
    self.headerLiveCapsule = liveCapsule;

    UIView *liveContent = liveCapsule.contentView;

    UIView *accentDot = [[UIView alloc] init];
    accentDot.translatesAutoresizingMaskIntoConstraints = NO;
    accentDot.backgroundColor = glowColor;
    accentDot.layer.cornerRadius = 3.5;
    accentDot.layer.shadowColor = glowColor.CGColor;
    accentDot.layer.shadowOpacity = 0.55;
    accentDot.layer.shadowRadius = 4.0;
    accentDot.layer.shadowOffset = CGSizeZero;
    [liveContent addSubview:accentDot];
    self.statusDot = accentDot;

    UILabel *statusLabel = [[UILabel alloc] init];
    statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    statusLabel.font = [GM MidFontWithSize:PPFontCaption2] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    statusLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.78];
    statusLabel.text = Language.isRTL ? @"متصل" : @"Online";
    [liveContent addSubview:statusLabel];

    // 4) Hairline divider — fades from clear → border → clear at the bottom edge.
    UIView *hairlineHost = [[UIView alloc] init];
    hairlineHost.translatesAutoresizingMaskIntoConstraints = NO;
    hairlineHost.userInteractionEnabled = NO;
    hairlineHost.backgroundColor = UIColor.clearColor;
    [contentView addSubview:hairlineHost];
    self.headerHairlineHost = hairlineHost;

    UIColor *hairlineColor = [[UIColor separatorColor] colorWithAlphaComponent:0.85];
    CAGradientLayer *hairline = [CAGradientLayer layer];
    hairline.colors = @[
        (id)[hairlineColor colorWithAlphaComponent:0.0].CGColor,
        (id)hairlineColor.CGColor,
        (id)[hairlineColor colorWithAlphaComponent:0.0].CGColor
    ];
    hairline.locations = @[@0.0, @0.5, @1.0];
    hairline.startPoint = CGPointMake(0.0, 0.5);
    hairline.endPoint = CGPointMake(1.0, 0.5);
    [hairlineHost.layer addSublayer:hairline];
    self.headerHairlineLayer = hairline;

    header.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", nameLabel.text, statusLabel.text];

    CGFloat topOffset = 24.0; // Sheet grabber clearance.

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [glowHost.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [glowHost.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [glowHost.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [glowHost.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],

        [nameLabel.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:topOffset],
        [nameLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],

        [subtitleLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:2.0],
        [subtitleLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],

        [liveCapsule.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:8.0],
        [liveCapsule.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [liveCapsule.heightAnchor constraintEqualToConstant:26.0],
        [liveCapsule.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-14.0],

        [accentDot.leadingAnchor constraintEqualToAnchor:liveContent.leadingAnchor constant:10.0],
        [accentDot.centerYAnchor constraintEqualToAnchor:liveContent.centerYAnchor],
        [accentDot.widthAnchor constraintEqualToConstant:7.0],
        [accentDot.heightAnchor constraintEqualToConstant:7.0],

        [statusLabel.leadingAnchor constraintEqualToAnchor:accentDot.trailingAnchor constant:6.0],
        [statusLabel.trailingAnchor constraintEqualToAnchor:liveContent.trailingAnchor constant:-12.0],
        [statusLabel.centerYAnchor constraintEqualToAnchor:liveContent.centerYAnchor],

        [hairlineHost.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [hairlineHost.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [hairlineHost.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
        [hairlineHost.heightAnchor constraintEqualToConstant:1.0]
    ]];
}

- (void)pp_startHeaderLiveAnimations {
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();

    // Glow plate: stay subtle, fade to a calm baseline; breathe only when motion is allowed.
    [self.headerGlowLayer removeAllAnimations];
    self.headerGlowLayer.opacity = reduceMotion ? 0.55 : 0.55;
    if (!reduceMotion) {
        CABasicAnimation *breath = [CABasicAnimation animationWithKeyPath:@"opacity"];
        breath.fromValue = @0.42;
        breath.toValue = @0.85;
        breath.duration = 5.4;
        breath.autoreverses = YES;
        breath.repeatCount = HUGE_VALF;
        breath.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.headerGlowLayer addAnimation:breath forKey:@"pp_headerGlowBreath"];
    }

    // Status dot: scale + opacity spring loop. Plain opacity in reduce-motion.
    [self.statusDot.layer removeAllAnimations];
    if (reduceMotion) {
        self.statusDot.alpha = 1.0;
        self.statusDot.transform = CGAffineTransformIdentity;
        return;
    }

    CABasicAnimation *scale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scale.fromValue = @0.78;
    scale.toValue = @1.18;
    scale.duration = 1.4;
    scale.autoreverses = YES;
    scale.repeatCount = HUGE_VALF;
    scale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.statusDot.layer addAnimation:scale forKey:@"pp_statusDotScale"];

    CABasicAnimation *opacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacity.fromValue = @0.55;
    opacity.toValue = @1.0;
    opacity.duration = 1.4;
    opacity.autoreverses = YES;
    opacity.repeatCount = HUGE_VALF;
    opacity.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.statusDot.layer addAnimation:opacity forKey:@"pp_statusDotOpacity"];
}

- (void)pp_stopHeaderLiveAnimations {
    [self.headerGlowLayer removeAllAnimations];
    [self.statusDot.layer removeAllAnimations];
}

- (void)setupInputView {
    self.inputbar = [[PPChatInputBarView alloc] init];
    self.inputbar.delegate = self;
    self.inputbar.translatesAutoresizingMaskIntoConstraints = NO;
    self.inputbar.semanticContentAttribute = GM.setSemantic;

    [self.view addSubview:self.inputbar];
    [self.inputbar resetRecordingUI];

    self.inputBarBottomConstraint = [self.inputbar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor];

    [NSLayoutConstraint activateConstraints:@[
        [self.inputbar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-2],
        [self.inputbar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:2],
        self.inputBarBottomConstraint
    ]];
}

- (void)setupTypingIndicator {
    UIBlurEffectStyle typingBlurStyle = UIBlurEffectStyleRegular;
    if (@available(iOS 13.0, *)) {
        typingBlurStyle = UIBlurEffectStyleSystemThinMaterial;
    }
    UIVisualEffectView *capsule = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:typingBlurStyle]];
    capsule.translatesAutoresizingMaskIntoConstraints = NO;
    capsule.layer.cornerRadius = 16.0;
    capsule.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        capsule.layer.cornerCurve = kCACornerCurveContinuous;
    }
    capsule.layer.borderWidth = 1.0 / [UIScreen mainScreen].scale;
    capsule.layer.borderColor = [[UIColor separatorColor] colorWithAlphaComponent:0.55].CGColor;
    capsule.alpha = 0.0;
    capsule.transform = CGAffineTransformMakeScale(0.94, 0.94);
    [self.view addSubview:capsule];
    self.typingContainer = capsule;

    UIView *content = capsule.contentView;

    UIColor *dotColor = AppPrimaryClr ?: [UIColor colorWithRed:0.98 green:0.70 blue:0.42 alpha:1.0];
    UIStackView *dotsStack = [[UIStackView alloc] init];
    dotsStack.translatesAutoresizingMaskIntoConstraints = NO;
    dotsStack.axis = UILayoutConstraintAxisHorizontal;
    dotsStack.alignment = UIStackViewAlignmentCenter;
    dotsStack.spacing = 4.0;
    [content addSubview:dotsStack];

    NSMutableArray<UIView *> *dots = [NSMutableArray arrayWithCapacity:3];
    for (NSInteger i = 0; i < 3; i++) {
        UIView *dot = [[UIView alloc] init];
        dot.translatesAutoresizingMaskIntoConstraints = NO;
        dot.backgroundColor = dotColor;
        dot.layer.cornerRadius = 3.0;
        [dotsStack addArrangedSubview:dot];
        [NSLayoutConstraint activateConstraints:@[
            [dot.widthAnchor constraintEqualToConstant:6.0],
            [dot.heightAnchor constraintEqualToConstant:6.0]
        ]];
        [dots addObject:dot];
    }
    self.typingDots = [dots copy];

    self.typingLabel = [[UILabel alloc] init];
    self.typingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.typingLabel.font = [GM MidFontWithSize:PPFontFootnote] ?: [UIFont systemFontOfSize:PPFontFootnote weight:UIFontWeightMedium];
    self.typingLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.78];
    [content addSubview:self.typingLabel];

    self.typingBottomConstraint = [capsule.bottomAnchor constraintEqualToAnchor:self.inputbar.topAnchor constant:-8];

    [NSLayoutConstraint activateConstraints:@[
        self.typingBottomConstraint,
        [capsule.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [capsule.heightAnchor constraintEqualToConstant:32.0],

        [dotsStack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:12.0],
        [dotsStack.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],

        [self.typingLabel.leadingAnchor constraintEqualToAnchor:dotsStack.trailingAnchor constant:8.0],
        [self.typingLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-12.0],
        [self.typingLabel.centerYAnchor constraintEqualToAnchor:content.centerYAnchor]
    ]];
}

- (void)pp_startTypingDotsAnimation {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        for (UIView *dot in self.typingDots) {
            [dot.layer removeAllAnimations];
            dot.layer.opacity = 1.0;
        }
        return;
    }

    CFTimeInterval baseTime = CACurrentMediaTime();
    NSTimeInterval phase = 0.14;
    NSTimeInterval duration = 0.86;

    [self.typingDots enumerateObjectsUsingBlock:^(UIView *dot, NSUInteger idx, __unused BOOL *stop) {
        [dot.layer removeAllAnimations];

        CAKeyframeAnimation *bounce = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.y"];
        bounce.values = @[@0.0, @(-4.0), @0.0, @0.0];
        bounce.keyTimes = @[@0.0, @0.30, @0.55, @1.0];
        bounce.duration = duration;
        bounce.repeatCount = HUGE_VALF;
        bounce.beginTime = baseTime + (idx * phase);
        bounce.timingFunctions = @[
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]
        ];
        [dot.layer addAnimation:bounce forKey:@"pp_typingDotBounce"];

        CAKeyframeAnimation *fade = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
        fade.values = @[@0.45, @1.0, @0.45, @0.45];
        fade.keyTimes = @[@0.0, @0.30, @0.55, @1.0];
        fade.duration = duration;
        fade.repeatCount = HUGE_VALF;
        fade.beginTime = baseTime + (idx * phase);
        [dot.layer addAnimation:fade forKey:@"pp_typingDotFade"];
    }];
}

- (void)pp_stopTypingDotsAnimation {
    for (UIView *dot in self.typingDots) {
        [dot.layer removeAllAnimations];
    }
}

- (void)showNovaTyping {
    self.typingLabel.text = Language.isRTL ? @"نوفا تكتب" : @"Nova is typing";

    [self pp_startTypingDotsAnimation];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.typingContainer.alpha = 1.0;
        self.typingContainer.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.42
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.4
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.typingContainer.alpha = 1.0;
        self.typingContainer.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)hideNovaTyping {
    [UIView animateWithDuration:0.22
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        self.typingContainer.alpha = 0.0;
        self.typingContainer.transform = CGAffineTransformMakeScale(0.94, 0.94);
    } completion:^(BOOL finished) {
        if (self.typingContainer.alpha == 0.0) {
            [self pp_stopTypingDotsAnimation];
        }
    }];
}

- (void)setupBottomFillBlur {
    if (self.bottomFillBlurView) return;

    self.bottomFillBlurView = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleFixed configType:PPButtonConfigrationGlass];

    UIButtonConfiguration *cfg = self.bottomFillBlurView.configuration;
    cfg.background.backgroundColor = [UIColor clearColor];
    cfg.baseBackgroundColor = [UIColor clearColor];
    self.bottomFillBlurView.configuration = cfg;

    [self.view insertSubview:self.bottomFillBlurView belowSubview:self.inputbar];

    [NSLayoutConstraint activateConstraints:@[
        [self.bottomFillBlurView.topAnchor constraintEqualToAnchor:self.inputbar.topAnchor],
        [self.bottomFillBlurView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bottomFillBlurView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bottomFillBlurView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;

    [self.tableView registerClass:[ChatMessageCell class] forCellReuseIdentifier:@"ChatMessageCell"];
    [self.tableView registerClass:[PPNovaProductMessageCell class] forCellReuseIdentifier:@"PPNovaProductMessageCell"];

    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 64;
    self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = UIColor.clearColor;
    // Add extra top inset so content starts below the glass header
    self.tableView.contentInset = UIEdgeInsetsMake(120, 0, PPSpaceSM, 0);

    [self.view addSubview:self.tableView];

    if (self.novaHeaderView) {
        [self.view bringSubviewToFront:self.novaHeaderView];
    }
    if (self.typingContainer) {
        [self.view bringSubviewToFront:self.typingContainer];
    }
    if (self.bottomFillBlurView) {
        [self.view bringSubviewToFront:self.bottomFillBlurView];
    }
    if (self.inputbar) {
        [self.view bringSubviewToFront:self.inputbar];
    }

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.inputbar.topAnchor],
    ]];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;

    UITapGestureRecognizer *dismissTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_dismissKeyboardOnTap:)];
    dismissTap.cancelsTouchesInView = NO;
    [self.tableView addGestureRecognizer:dismissTap];
}

- (void)pp_dismissKeyboardOnTap:(UITapGestureRecognizer *)tap {
    [self.view endEditing:YES];
}

#pragma mark - Keyboard

- (void)registerForKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    CGRect keyboardFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];

    CGFloat safeAreaBottom = self.view.safeAreaInsets.bottom;
    self.inputBarBottomConstraint.constant = -(keyboardFrame.size.height - safeAreaBottom);

    [UIView animateWithDuration:duration delay:0.0 options:(curve << 16) animations:^{
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        [self scrollToBottomAnimated:YES];
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];

    self.inputBarBottomConstraint.constant = 0;

    [UIView animateWithDuration:duration delay:0.0 options:(curve << 16) animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)scrollToBottomAnimated:(BOOL)animated {
    if (self.messages.count == 0) return;
    NSIndexPath *bottomIP = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
    [self.tableView scrollToRowAtIndexPath:bottomIP atScrollPosition:UITableViewScrollPositionBottom animated:animated];
}

#pragma mark - Data Source & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ChatMessageModel *msg = self.messages[indexPath.row];
    
    if (msg.messageType == ChatMessageTypeNovaProduct || msg.messageType == ChatMessageTypeNovaProductList) {
        PPNovaProductMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPNovaProductMessageCell" forIndexPath:indexPath];
        cell.delegate = self;
        [cell configureWithMessage:msg maxWidth:self.view.bounds.size.width];
        return cell;
    }

    ChatMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ChatMessageCell" forIndexPath:indexPath];

    BOOL isIncoming = ![msg.senderID isEqualToString:[UserManager sharedManager].currentUser.ID];

    PPChatGroupPosition groupPos = PPChatGroupPositionSingle;

    [cell configureWithMessage:msg.text
                          date:msg.timestamp
                    isIncoming:isIncoming
                      maxWidth:MAX_BUBBLE_WIDTH(self.view)
                        status:msg.status
                  messageModel:msg
                 groupPosition:groupPos];

    return cell;
}

#pragma mark - PPChatInputBarViewDelegate

- (void)inputBar:(PPChatInputBarView *)bar didSendText:(NSString *)text {
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmedText.length == 0) return;

    [self addUserMessage:trimmedText];
    [self showNovaTyping];
    [self sendNovaRequestForUserText:trimmedText];
}

- (void)addUserMessage:(NSString *)text {
    [self addMessageWithText:text isIncoming:NO];
}

- (void)addNovaMessage:(NSString *)text {
    [self addMessageWithText:text isIncoming:YES];
}

- (void)addMessageWithText:(NSString *)text isIncoming:(BOOL)isIncoming {
    ChatMessageModel *msg = [[ChatMessageModel alloc] init];
    msg.ID = [[NSUUID UUID] UUIDString];
    msg.text = text;
    msg.timestamp = [NSDate date];
    msg.status = ChatMessageStatusSent;
    msg.messageType = ChatMessageTypeText;
    msg.senderID = isIncoming ? @"nova_bot_id" : [UserManager sharedManager].currentUser.ID;

    [self.messages addObject:msg];
    [self animateInsertedRowAtIndexPath:[NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0]];
}

- (void)animateInsertedRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationBottom];
    [self scrollToBottomAnimated:YES];
}

- (void)inputBar:(PPChatInputBarView *)bar didChangeText:(UITextView *)textView {}
- (void)inputBarDidStartRecording:(PPChatInputBarView *)bar {}
- (void)inputBar:(PPChatInputBarView *)bar didFinishRecordingWithURL:(nullable NSURL *)fileURL duration:(NSTimeInterval)duration locked:(BOOL)locked {}
- (void)inputBarDidCancelRecording:(PPChatInputBarView *)bar {}
- (void)inputBarDidTapAttachImage:(PPChatInputBarView *)bar {}
- (void)inputBarDidTapAttachVideo:(PPChatInputBarView *)bar {}
- (void)inputBar:(PPChatInputBarView *)bar didChangeHeight:(CGFloat)newHeight {}
- (void)inputBarDidToggleRecordingPreview:(PPChatInputBarView *)bar {}
- (void)finishVoiceRecordingAndSend {}
- (void)inputBarDidStopRecordingPreview:(PPChatInputBarView *)bar {}
- (void)recordingBarDidTapPlayFromLocked {}
- (void)recordingBarDidTogglePlayback {}

@end
