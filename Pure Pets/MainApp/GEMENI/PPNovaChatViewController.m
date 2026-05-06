//
//  PPNovaChatViewController.m
//  Pure Pets
//

#import "PPNovaChatViewController.h"
#import "ChatMessageModel.h"
#import "PPNovaMessageBubbleCell.h"
#import "PPNovaProductMessageCell.h"
#import "PPNovaFloatingInputBarView.h"
#import "EnumValues.h"
#import "AppManager.h"
#import "PPNavigationController.h"
#import "PetAccessoryManager.h"
#import "CartManager.h"
#import "CartItem.h"
#import "PPHUD.h"
#import "AccessViewerVC.h"
#import "PPOverlayCoordinator.h"
#import <IQKeyboardManager/IQKeyboardManager.h>

static UIColor *PPNovaDynamicColor(UIColor *lightColor, UIColor *darkColor) {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
        }];
    }
    return lightColor;
}

@interface PPNovaChatViewController () <UITableViewDelegate, UITableViewDataSource, PPNovaFloatingInputBarViewDelegate, PPNovaProductMessageCellDelegate>

@property (nonatomic, strong) UIView *ambientBackgroundView;
@property (nonatomic, strong) UIView *novaHeaderView;
@property (nonatomic, strong) UIView *headerBrandRingView;
@property (nonatomic, strong) UIView *headerBrandMarkView;
@property (nonatomic, strong) UIView *headerHairlineHost;
@property (nonatomic, strong) UIView *headerLiveCapsule;
@property (nonatomic, strong) UIView *statusDot;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIVisualEffectView *typingContainer;
@property (nonatomic, strong) UILabel *typingLabel;
@property (nonatomic, copy)   NSArray<UIView *> *typingDots;
@property (nonatomic, strong) UIView *emptyStateView;
@property (nonatomic, strong) UIView *emptyStatePulseView;

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<ChatMessageModel *> *messages;
@property (nonatomic, strong) PPNovaFloatingInputBarView *inputbar;
@property (nonatomic, strong) NSLayoutConstraint *inputBarBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *typingBottomConstraint;
@property (nonatomic, assign) CGFloat inputBarRestingBottomConstant;
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
@property (nonatomic, copy, nonnull) NSString *novaSessionId;

@property (nonatomic, assign) BOOL previousIQEnabled;
@property (nonatomic, assign) BOOL previousToolbarEnabled;
@property (nonatomic, assign) CGFloat lastNovaTableLayoutWidth;

@end

@implementation PPNovaChatViewController

+ (void)presentNovaFromViewController:(UIViewController *)presentingVC {
    PPNovaChatViewController *novaVC = [[PPNovaChatViewController alloc] init];
    if (@available(iOS 15.0, *)) {
        novaVC.modalPresentationStyle = UIModalPresentationPageSheet;
        UISheetPresentationController *sheet = novaVC.sheetPresentationController;
        if (sheet) {
            if (@available(iOS 16.0, *)) {
                UISheetPresentationControllerDetent *customDetent = [UISheetPresentationControllerDetent customDetentWithIdentifier:@"Nova89" resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
                    return UIScreen.mainScreen.bounds.size.height * 0.89;
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

    self.novaSessionId = [[NSUUID UUID] UUIDString];
    self.title = @"";
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.view.backgroundColor = AppBackgroundClr ?: UIColor.systemBackgroundColor;
    self.messages = [NSMutableArray array];

    [self setupAmbientBackground];
    [self setupNovaBackend];
    [self setupNovaHeader];
    [self setupInputView];
    [self setupTypingIndicator];
    [self setupTableView];
    [self setupNovaEmptyState];

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
    [self pp_startAmbientBackgroundAnimations];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [IQKeyboardManager sharedManager].enable = self.previousIQEnabled;
    [IQKeyboardManager sharedManager].enableAutoToolbar = self.previousToolbarEnabled;

    [self pp_stopHeaderLiveAnimations];
    [self pp_stopAmbientBackgroundAnimations];
    [self pp_stopTypingDotsAnimation];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self pp_applyNovaSurfaceColors];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat tableWidth = CGRectGetWidth(self.tableView.bounds);
    if (tableWidth <= 1.0 || fabs(tableWidth - self.lastNovaTableLayoutWidth) <= 1.0) {
        return;
    }

    self.lastNovaTableLayoutWidth = tableWidth;
    [self pp_updateVisibleNovaMessageCellWidthsForTableWidth:tableWidth];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.statusDot.layer removeAllAnimations];
    [self.headerBrandRingView.layer removeAllAnimations];
    [self.headerBrandMarkView.layer removeAllAnimations];
    [self.emptyStatePulseView.layer removeAllAnimations];
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
        @"context": [self pp_currentContextDictionary],
        @"history": [self pp_currentHistoryArray],
        @"sessionId": self.novaSessionId
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
            NSArray *productIDs = nil;
            if ([result.data isKindOfClass:NSDictionary.class]) {
                NSDictionary *data = (NSDictionary *)result.data;
                id textValue = data[@"text"];
                if ([textValue isKindOfClass:NSString.class]) {
                    replyText = (NSString *)textValue;
                }
                id productsValue = data[@"productIDs"];
                if ([productsValue isKindOfClass:NSArray.class]) {
                    productIDs = (NSArray *)productsValue;
                }
            }
            
            replyText = [replyText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (replyText.length == 0 && productIDs.count == 0) {
                [self insertNovaReplyForUserText:trimmedText];
                return;
            }
            
            if (replyText.length > 0) {
                replyText = [self pp_sanitizeNovaReply:replyText];
                if (replyText.length > 0) {
                    [self addNovaMessage:replyText];
                }
            }

            if (productIDs.count > 0) {
                [self pp_fetchAndShowNovaProducts:productIDs];
            }
        });
    }];
}

- (void)pp_fetchAndShowNovaProducts:(NSArray<NSString *> *)productIDs {
    [PetAccessoryManager fetchAccessoriesWithIDs:productIDs completion:^(NSArray<PetAccessory *> * _Nonnull accessories) {
        if (accessories.count == 0) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            self.lastShownProducts = accessories;
            if (accessories.count == 1) {
                self.lastSuggestedProduct = accessories.firstObject;
                self.pendingCartProduct = accessories.firstObject;
            } else {
                self.lastSuggestedProduct = nil;
                self.pendingCartProduct = nil;
            }

            ChatMessageModel *msg = [[ChatMessageModel alloc] init];
            msg.ID = [[NSUUID UUID] UUIDString];
            msg.messageType = accessories.count > 1 ? ChatMessageTypeNovaProductList : ChatMessageTypeNovaProduct;
            msg.novaProducts = accessories;
            msg.timestamp = [NSDate date];
            msg.senderID = @"nova";

            [self.messages addObject:msg];
            [self updateNovaEmptyStateAnimated:YES];
            [self animateInsertedRowAtIndexPath:[NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0]];
        });
    }];
}

#pragma mark - Initial Data

- (void)insertNovaGreeting {
    if (self.novaHasShownGreeting) return;

    NSString *greeting = kLang(@"nova_greeting");

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
        NSString *format = [self pp_novaLocalizedStringForKey:@"nova_fallback_pet_need_format" arabic:isArabic];
        if (isArabic) {
            return [NSString stringWithFormat:format,
                    [self pp_arabicPetWord:petType],
                    [self pp_arabicNeedWord:need]];
        }
        return [NSString stringWithFormat:format, petType, need];
    }

    if (hasPet) {
        NSString *format = [self pp_novaLocalizedStringForKey:@"nova_fallback_pet_format" arabic:isArabic];
        if (isArabic) {
            return [NSString stringWithFormat:format,
                    [self pp_arabicPetWord:petType]];
        }
        return [NSString stringWithFormat:format, petType];
    }

    if (hasNeed) {
        NSString *format = [self pp_novaLocalizedStringForKey:@"nova_fallback_need_format" arabic:isArabic];
        if (isArabic) {
            return [NSString stringWithFormat:format,
                    [self pp_arabicNeedWord:need]];
        }
        return [NSString stringWithFormat:format, need];
    }

    return [self pp_novaLocalizedStringForKey:@"nova_fallback_prompt" arabic:isArabic];
}

- (NSString *)pp_novaLocalizedStringForKey:(NSString *)key arabic:(BOOL)arabic {
    NSString *languageCode = arabic ? @"ar" : @"en";
    NSString *path = [[NSBundle mainBundle] pathForResource:languageCode ofType:@"lproj"];
    NSBundle *bundle = path.length > 0 ? [NSBundle bundleWithPath:path] : nil;
    NSString *localized = [bundle localizedStringForKey:key value:nil table:nil];
    return localized.length > 0 ? localized : kLang(key);
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

- (NSArray *)pp_currentHistoryArray {
    NSMutableArray *history = [NSMutableArray array];
    // Only send the last 6 messages to keep the payload efficient.
    // We skip the current message being sent as it's passed in the 'prompt' field.
    NSInteger total = self.messages.count;
    NSInteger start = MAX(0, total - 7);
    for (NSInteger i = start; i < total; i++) {
        ChatMessageModel *msg = self.messages[i];
        if (msg.messageType != ChatMessageTypeText) continue;

        // Skip the very last message if it matches the current prompt being sent
        // (to avoid duplication since the prompt is sent separately).
        // However, standard Vertex history includes the user message.
        // But for our proxy, handleNovaRequest adds the prompt to the history.
        // So history should ONLY be previous messages.
        if (i == total - 1) continue;

        NSString *role = [msg.senderID isEqualToString:@"nova_bot_id"] ? @"model" : @"user";
        [history addObject:@{
            @"role": role,
            @"parts": @[@{ @"text": msg.text ?: @"" }]
        }];
    }
    return [history copy];
}

#pragma mark - Setup UI

- (void)setupAmbientBackground {
    UIView *backgroundView = [[UIView alloc] init];
    backgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    backgroundView.userInteractionEnabled = NO;
    backgroundView.backgroundColor = AppBackgroundClr ?: UIColor.systemBackgroundColor;
    [self.view addSubview:backgroundView];
    self.ambientBackgroundView = backgroundView;

    [NSLayoutConstraint activateConstraints:@[
        [backgroundView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [backgroundView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [backgroundView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [backgroundView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [self pp_applyNovaSurfaceColors];
}

- (void)pp_applyNovaSurfaceColors {
    UIColor *brand = AppPrimaryClr ?: UIColor.systemOrangeColor;
    UIColor *baseBackground = AppBackgroundClr ?: UIColor.systemBackgroundColor;
    self.ambientBackgroundView.backgroundColor = baseBackground;
    self.emptyStatePulseView.backgroundColor = [brand colorWithAlphaComponent:0.10];
    self.headerHairlineHost.backgroundColor = [UIColor.separatorColor colorWithAlphaComponent:0.28];
    self.statusDot.backgroundColor = brand;
    self.statusDot.layer.shadowColor = brand.CGColor;
    self.headerLiveCapsule.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.40].CGColor;
    self.headerBrandRingView.layer.borderColor = [brand colorWithAlphaComponent:0.20].CGColor;
    self.headerBrandMarkView.backgroundColor = PPNovaDynamicColor([UIColor colorWithWhite:1.0 alpha:0.82],
                                                                  [UIColor colorWithWhite:1.0 alpha:0.10]);
    self.headerBrandMarkView.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.30].CGColor;
}

- (void)pp_startAmbientBackgroundAnimations {
    [self.emptyStatePulseView.layer removeAllAnimations];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.emptyStatePulseView.transform = CGAffineTransformIdentity;
        return;
    }

    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulse.fromValue = @0.985;
    pulse.toValue = @1.025;
    pulse.duration = 4.8;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.emptyStatePulseView.layer addAnimation:pulse forKey:@"pp_novaEmptyPulse"];
}

- (void)pp_stopAmbientBackgroundAnimations {
    [self.emptyStatePulseView.layer removeAllAnimations];
}

- (void)setupNovaHeader {
    UIBlurEffectStyle blurStyle = UIBlurEffectStyleProminent;
    if (@available(iOS 13.0, *)) {
        blurStyle = UIBlurEffectStyleSystemUltraThinMaterial;
    }
    UIVisualEffect *blurEffect = [UIBlurEffect effectWithStyle:blurStyle];
    UIVisualEffectView *header = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.layer.shadowColor = UIColor.blackColor.CGColor;
    header.layer.shadowOpacity = 0.04;
    header.layer.shadowRadius = 18.0;
    header.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    [self.view addSubview:header];
    self.novaHeaderView = header;

    UIView *contentView = header.contentView;

    UIColor *accentColor = AppPrimaryClr ?: [UIColor colorWithRed:0.98 green:0.70 blue:0.42 alpha:1.0];

    UIView *brandRing = [[UIView alloc] init];
    brandRing.translatesAutoresizingMaskIntoConstraints = NO;
    brandRing.backgroundColor = UIColor.clearColor;
    brandRing.layer.cornerRadius = 25.0;
    brandRing.layer.borderWidth = 0.8 / UIScreen.mainScreen.scale;
    brandRing.layer.borderColor = [accentColor colorWithAlphaComponent:0.20].CGColor;
    if (@available(iOS 13.0, *)) {
        brandRing.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [contentView addSubview:brandRing];
    self.headerBrandRingView = brandRing;

    UIView *brandMark = [[UIView alloc] init];
    brandMark.translatesAutoresizingMaskIntoConstraints = NO;
    brandMark.backgroundColor = PPNovaDynamicColor([UIColor colorWithWhite:1.0 alpha:0.82],
                                                   [UIColor colorWithWhite:1.0 alpha:0.10]);
    brandMark.layer.cornerRadius = 20.0;
    brandMark.layer.borderWidth = 0.5 / UIScreen.mainScreen.scale;
    brandMark.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.30].CGColor;
    brandMark.layer.shadowColor = UIColor.blackColor.CGColor;
    brandMark.layer.shadowOpacity = 0.07;
    brandMark.layer.shadowRadius = 12.0;
    brandMark.layer.shadowOffset = CGSizeMake(0.0, 5.0);
    if (@available(iOS 13.0, *)) {
        brandMark.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [contentView addSubview:brandMark];
    self.headerBrandMarkView = brandMark;

    UILabel *brandLabel = [[UILabel alloc] init];
    brandLabel.translatesAutoresizingMaskIntoConstraints = NO;
    brandLabel.text = @"N";
    brandLabel.textAlignment = NSTextAlignmentCenter;
    brandLabel.textColor = accentColor;
    brandLabel.font = [GM boldFontWithSize:18.0] ?: [UIFont systemFontOfSize:18.0 weight:UIFontWeightBold];
    [brandMark addSubview:brandLabel];

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.font = [GM boldFontWithSize:PPFontTitle1] ?: [UIFont systemFontOfSize:28.0 weight:UIFontWeightBold];
    nameLabel.textColor = AppPrimaryTextClr;
    nameLabel.text = kLang(@"nova_title");
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
    subtitleLabel.text = kLang(@"nova_subtitle");
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    [contentView addSubview:subtitleLabel];

    UIVisualEffectView *liveCapsule;
    if (@available(iOS 13.0, *)) {
        liveCapsule = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
    } else {
        liveCapsule = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular]];
    }
    liveCapsule.translatesAutoresizingMaskIntoConstraints = NO;
    liveCapsule.layer.cornerRadius = 13.0;
    liveCapsule.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        liveCapsule.layer.cornerCurve = kCACornerCurveContinuous;
    }
    liveCapsule.layer.borderWidth = 0.5 / UIScreen.mainScreen.scale;
    liveCapsule.layer.borderColor = [[UIColor separatorColor] colorWithAlphaComponent:0.55].CGColor;
    [contentView addSubview:liveCapsule];
    self.headerLiveCapsule = liveCapsule;

    UIView *liveContent = liveCapsule.contentView;

    UIView *accentDot = [[UIView alloc] init];
    accentDot.translatesAutoresizingMaskIntoConstraints = NO;
    accentDot.backgroundColor = accentColor;
    accentDot.layer.cornerRadius = 3.5;
    accentDot.layer.shadowColor = accentColor.CGColor;
    accentDot.layer.shadowOpacity = 0.55;
    accentDot.layer.shadowRadius = 4.0;
    accentDot.layer.shadowOffset = CGSizeZero;
    [liveContent addSubview:accentDot];
    self.statusDot = accentDot;

    UILabel *statusLabel = [[UILabel alloc] init];
    statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    statusLabel.font = [GM MidFontWithSize:PPFontCaption2] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    statusLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.78];
    statusLabel.text = kLang(@"nova_status_online");
    [liveContent addSubview:statusLabel];
    self.statusLabel = statusLabel;

    UIView *hairlineHost = [[UIView alloc] init];
    hairlineHost.translatesAutoresizingMaskIntoConstraints = NO;
    hairlineHost.userInteractionEnabled = NO;
    hairlineHost.backgroundColor = [UIColor.separatorColor colorWithAlphaComponent:0.28];
    [contentView addSubview:hairlineHost];
    self.headerHairlineHost = hairlineHost;

    header.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", nameLabel.text, statusLabel.text];

    CGFloat topOffset = 22.0; // Sheet grabber clearance.

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [brandRing.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:topOffset],
        [brandRing.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [brandRing.widthAnchor constraintEqualToConstant:50.0],
        [brandRing.heightAnchor constraintEqualToConstant:50.0],

        [brandMark.centerXAnchor constraintEqualToAnchor:brandRing.centerXAnchor],
        [brandMark.centerYAnchor constraintEqualToAnchor:brandRing.centerYAnchor],
        [brandMark.widthAnchor constraintEqualToConstant:40.0],
        [brandMark.heightAnchor constraintEqualToConstant:40.0],

        [brandLabel.topAnchor constraintEqualToAnchor:brandMark.topAnchor],
        [brandLabel.leadingAnchor constraintEqualToAnchor:brandMark.leadingAnchor],
        [brandLabel.trailingAnchor constraintEqualToAnchor:brandMark.trailingAnchor],
        [brandLabel.bottomAnchor constraintEqualToAnchor:brandMark.bottomAnchor],

        [nameLabel.topAnchor constraintEqualToAnchor:brandRing.bottomAnchor constant:8.0],
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

    [self pp_applyNovaSurfaceColors];
}

- (void)pp_startHeaderLiveAnimations {
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();

    [self.statusDot.layer removeAllAnimations];
    [self.headerBrandRingView.layer removeAllAnimations];
    [self.headerBrandMarkView.layer removeAllAnimations];
    if (reduceMotion) {
        self.statusDot.alpha = 1.0;
        self.statusDot.transform = CGAffineTransformIdentity;
        self.headerBrandRingView.alpha = 1.0;
        self.headerBrandRingView.transform = CGAffineTransformIdentity;
        self.headerBrandMarkView.transform = CGAffineTransformIdentity;
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

    CABasicAnimation *ringOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    ringOpacity.fromValue = @0.42;
    ringOpacity.toValue = @1.0;
    ringOpacity.duration = 4.8;
    ringOpacity.autoreverses = YES;
    ringOpacity.repeatCount = HUGE_VALF;
    ringOpacity.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.headerBrandRingView.layer addAnimation:ringOpacity forKey:@"pp_novaBrandRingOpacity"];

    CABasicAnimation *ringScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    ringScale.fromValue = @0.985;
    ringScale.toValue = @1.035;
    ringScale.duration = 4.8;
    ringScale.autoreverses = YES;
    ringScale.repeatCount = HUGE_VALF;
    ringScale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.headerBrandRingView.layer addAnimation:ringScale forKey:@"pp_novaBrandRingScale"];

    CABasicAnimation *markScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    markScale.fromValue = @0.99;
    markScale.toValue = @1.018;
    markScale.duration = 5.6;
    markScale.autoreverses = YES;
    markScale.repeatCount = HUGE_VALF;
    markScale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.headerBrandMarkView.layer addAnimation:markScale forKey:@"pp_novaBrandMarkScale"];
}

- (void)pp_stopHeaderLiveAnimations {
    [self.statusDot.layer removeAllAnimations];
    [self.headerBrandRingView.layer removeAllAnimations];
    [self.headerBrandMarkView.layer removeAllAnimations];
}

- (void)setupInputView {
    self.inputbar = [[PPNovaFloatingInputBarView alloc] init];
    self.inputbar.delegate = self;
    self.inputbar.translatesAutoresizingMaskIntoConstraints = NO;
    self.inputbar.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    [self.view addSubview:self.inputbar];

    self.inputBarRestingBottomConstant = -10.0;
    self.inputBarBottomConstraint = [self.inputbar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:self.inputBarRestingBottomConstant];
    NSLayoutConstraint *compactWidth = [self.inputbar.widthAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.widthAnchor constant:-24.0];
    compactWidth.priority = 999.0;
    NSLayoutConstraint *readableWidth = [self.inputbar.widthAnchor constraintEqualToConstant:760.0];
    readableWidth.priority = 998.0;

    [NSLayoutConstraint activateConstraints:@[
        [self.inputbar.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:12.0],
        [self.inputbar.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-12.0],
        [self.inputbar.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.inputbar.widthAnchor constraintLessThanOrEqualToConstant:760.0],
        compactWidth,
        readableWidth,
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
    capsule.layer.borderWidth = 0.0 / [UIScreen mainScreen].scale;
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
        [capsule.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:0],
        [capsule.heightAnchor constraintEqualToConstant:32.0],

        [dotsStack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:12.0],
        [dotsStack.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],

        [self.typingLabel.leadingAnchor constraintEqualToAnchor:dotsStack.trailingAnchor constant:8.0],
        [self.typingLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-12.0],
        [self.typingLabel.centerYAnchor constraintEqualToAnchor:content.centerYAnchor]
    ]];
}

- (void)setupNovaEmptyState {
    UIView *emptyView = [[UIView alloc] init];
    emptyView.translatesAutoresizingMaskIntoConstraints = NO;
    emptyView.userInteractionEnabled = NO;
    emptyView.alpha = 1.0;
    emptyView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view insertSubview:emptyView belowSubview:self.tableView];
    self.emptyStateView = emptyView;

    UIView *pulseView = [[UIView alloc] init];
    pulseView.translatesAutoresizingMaskIntoConstraints = NO;
    pulseView.backgroundColor = [(AppPrimaryClr ?: UIColor.systemOrangeColor) colorWithAlphaComponent:0.10];
    pulseView.layer.cornerRadius = 28.0;
    pulseView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        pulseView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [emptyView addSubview:pulseView];
    self.emptyStatePulseView = pulseView;

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"sparkles"]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [pulseView addSubview:iconView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:PPFontTitle3] ?: [UIFont systemFontOfSize:20.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.text = kLang(@"nova_empty_title");
    [emptyView addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightRegular];
    subtitleLabel.textColor = [AppSecondaryTextClr colorWithAlphaComponent:0.82];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.text = kLang(@"nova_empty_subtitle");
    [emptyView addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [emptyView.leadingAnchor constraintEqualToAnchor:self.view.layoutMarginsGuide.leadingAnchor constant:12.0],
        [emptyView.trailingAnchor constraintEqualToAnchor:self.view.layoutMarginsGuide.trailingAnchor constant:-12.0],
        [emptyView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:8.0],

        [pulseView.topAnchor constraintEqualToAnchor:emptyView.topAnchor],
        [pulseView.centerXAnchor constraintEqualToAnchor:emptyView.centerXAnchor],
        [pulseView.widthAnchor constraintEqualToConstant:56.0],
        [pulseView.heightAnchor constraintEqualToConstant:56.0],

        [iconView.centerXAnchor constraintEqualToAnchor:pulseView.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:pulseView.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:24.0],
        [iconView.heightAnchor constraintEqualToConstant:24.0],

        [titleLabel.topAnchor constraintEqualToAnchor:pulseView.bottomAnchor constant:14.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:emptyView.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:emptyView.trailingAnchor],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:7.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:emptyView.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:emptyView.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:emptyView.bottomAnchor]
    ]];

    [self pp_applyNovaSurfaceColors];
    [self updateNovaEmptyStateAnimated:NO];
}

- (void)updateNovaEmptyStateAnimated:(BOOL)animated {
    BOOL shouldShow = self.messages.count == 0;
    CGFloat targetAlpha = shouldShow ? 1.0 : 0.0;

    void (^changes)(void) = ^{
        self.emptyStateView.alpha = targetAlpha;
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        changes();
        self.emptyStateView.hidden = !shouldShow;
        return;
    }

    if (shouldShow) {
        self.emptyStateView.hidden = NO;
    }
    [UIView animateWithDuration:0.24 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:changes completion:^(__unused BOOL finished) {
        self.emptyStateView.hidden = !shouldShow;
    }];
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
    self.typingLabel.text = kLang(@"nova_typing");
    self.statusLabel.text = kLang(@"nova_status_thinking");

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
    self.statusLabel.text = kLang(@"nova_status_online");

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

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;

    [self.tableView registerClass:[PPNovaMessageBubbleCell class] forCellReuseIdentifier:[PPNovaMessageBubbleCell reuseIdentifier]];
    [self.tableView registerClass:[PPNovaProductMessageCell class] forCellReuseIdentifier:@"PPNovaProductMessageCell"];

    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 92;
    self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.delaysContentTouches = NO;
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }
    self.tableView.contentInset = UIEdgeInsetsMake(174, 0, PPSpaceBase, 0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;

    [self.view addSubview:self.tableView];

    if (self.novaHeaderView) {
        [self.view bringSubviewToFront:self.novaHeaderView];
    }
    if (self.typingContainer) {
        [self.view bringSubviewToFront:self.typingContainer];
    }
    if (self.inputbar) {
        [self.view bringSubviewToFront:self.inputbar];
    }

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:12],
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
    CGFloat keyboardOffset = MAX(keyboardFrame.size.height - safeAreaBottom, 0.0);
    self.inputBarBottomConstraint.constant = -(keyboardOffset + 8.0);

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

    self.inputBarBottomConstraint.constant = self.inputBarRestingBottomConstant;

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

    PPNovaMessageBubbleCell *cell = [tableView dequeueReusableCellWithIdentifier:[PPNovaMessageBubbleCell reuseIdentifier] forIndexPath:indexPath];
    [cell configureWithMessage:msg maxWidth:[self pp_novaMessageLayoutWidthForTableView:tableView]];

    return cell;
}

- (CGFloat)pp_novaMessageLayoutWidthForTableView:(UITableView *)tableView {
    CGFloat width = CGRectGetWidth(tableView.bounds);
    if (width <= 1.0) {
        width = CGRectGetWidth(self.view.bounds);
    }
    if (width <= 1.0) {
        width = UIScreen.mainScreen.bounds.size.width;
    }
    return width;
}

- (void)pp_updateVisibleNovaMessageCellWidthsForTableWidth:(CGFloat)tableWidth {
    for (UITableViewCell *visibleCell in self.tableView.visibleCells) {
        if (![visibleCell isKindOfClass:PPNovaMessageBubbleCell.class]) continue;

        PPNovaMessageBubbleCell *cell = (PPNovaMessageBubbleCell *)visibleCell;
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        if (indexPath.row < 0 || indexPath.row >= self.messages.count) continue;

        ChatMessageModel *message = self.messages[indexPath.row];
        [cell configureWithMessage:message maxWidth:tableWidth];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= self.messages.count) return;

    ChatMessageModel *message = self.messages[indexPath.row];
    if (message.didAnimateInsert || UIAccessibilityIsReduceMotionEnabled()) {
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
        message.didAnimateInsert = YES;
        return;
    }

    message.didAnimateInsert = YES;
    cell.alpha = 0.0;
    cell.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 16.0),
                                             CGAffineTransformMakeScale(0.985, 0.985));
    NSTimeInterval delay = MIN(indexPath.row * 0.025, 0.09);
    [UIView animateWithDuration:0.38
                          delay:delay
         usingSpringWithDamping:0.91
          initialSpringVelocity:0.16
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - PPNovaFloatingInputBarViewDelegate

- (void)novaInputBar:(PPNovaFloatingInputBarView *)bar didSendText:(NSString *)text {
    [self pp_handleNovaSubmittedText:text];
}

- (void)novaInputBar:(PPNovaFloatingInputBarView *)bar didChangeHeight:(CGFloat)height {
    [UIView animateWithDuration:0.18 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        [self.view layoutIfNeeded];
    } completion:^(__unused BOOL finished) {
        [self scrollToBottomAnimated:YES];
    }];
}

- (void)pp_handleNovaSubmittedText:(NSString *)text {
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmedText.length == 0) return;

    [self addUserMessage:trimmedText];

    // Check for "add to cart" intent
    if ([self pp_isAddToCartIntent:trimmedText]) {
        if (self.pendingCartProduct) {
            [self pp_handleAddToCartForProduct:self.pendingCartProduct];
            return;
        } else if (self.lastShownProducts.count > 1) {
            NSString *reply = kLang(@"nova_add_to_cart_which");
            [self addNovaMessage:reply];
            return;
        }
    }

    [self showNovaTyping];
    [self sendNovaRequestForUserText:trimmedText];
}

- (BOOL)pp_isAddToCartIntent:(NSString *)text {
    NSString *lower = [text lowercaseString];
    NSArray *keywords = @[@"yes", @"add", @"buy", @"want", @"أضف", @"اضف", @"نعم", @"اريد", @"أريد", @"شراء", @"ايوه", @"ايه"];
    for (NSString *kw in keywords) {
        if ([lower containsString:kw]) return YES;
    }
    return NO;
}

- (void)pp_handleAddToCartForProduct:(PetAccessory *)product {
    [PPHUD showLoading:@""];

    CartItem *item = [[CartItem alloc] initWithAccessory:product quantity:1];

    BOOL success = [[CartManager sharedManager] addItem:item];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

        [PPHUD dismiss];
        if (success) {
            NSString *msg = kLang(@"nova_added_to_cart");
            [self addNovaMessage:msg];
            self.pendingCartProduct = nil; // Clear after adding
        } else {
            NSString *msg = kLang(@"nova_add_to_cart_failed");
            [self addNovaMessage:msg];
        }
    });
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
    [self updateNovaEmptyStateAnimated:YES];
    [self animateInsertedRowAtIndexPath:[NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0]];
}

- (NSString *)pp_sanitizeNovaReply:(NSString *)text {
    if (text.length == 0) return text;

    NSArray<NSString *> *greetingPrefixes = @[
        @"أهلا بك في بيور بتس،",
        @"أهلا بك في بيور بتس.",
        @"أهلاً بك في بيور بتس،",
        @"أهلاً بك في بيور بتس.",
        @"أهلا بك في Pure Pets،",
        @"أهلا بك في Pure Pets.",
        @"أهلاً بك في Pure Pets،",
        @"أهلاً بك في Pure Pets.",
        @"أهلا بك في",
        @"أهلاً بك في",
        @"Welcome to Pure Pets,",
        @"Welcome to Pure Pets.",
        @"Hi, I'm Nova from Pure Pets."
    ];

    NSString *result = text;

    for (NSString *prefix in greetingPrefixes) {
        if ([result hasPrefix:prefix]) {
            result = [result substringFromIndex:prefix.length];

            result = [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

            if (result.length == 0) break;

            unichar firstChar = [result characterAtIndex:0];
            if (firstChar == 0x060C || firstChar == 0x002C || firstChar == 0x002E) {
                result = [result substringFromIndex:1];
                result = [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            }

            break;
        }
    }

    return result;
}

- (void)animateInsertedRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    [self scrollToBottomAnimated:YES];
}

#pragma mark - PPNovaProductMessageCellDelegate

- (void)novaProductCell_didTapAddToCart:(PetAccessory *)product {
    [self pp_handleAddToCartForProduct:product];
}

- (void)novaProductCell_didTapProduct:(PetAccessory *)product {
    AccessViewerVC *viewer = [[AccessViewerVC alloc] init];
    viewer.accessAds = product;

    if (self.navigationController) {
        [self.navigationController pushViewController:viewer animated:YES];
    } else {
        PPNavigationController *nav = [[PPNavigationController alloc] initWithRootViewController:viewer];
        [self presentViewController:nav animated:YES completion:nil];
    }
}

@end
