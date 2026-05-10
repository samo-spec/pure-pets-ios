//
//  PPNovaChatViewController.m
//  Pure Pets
//

#import "PPNovaChatViewController.h"
#import "ChatMessageModel.h"
#import "ChatMessageCell.h" // #import "PPNovaMessageBubbleCell.h"
#import "PPNovaProductMessageCell.h"
#import "PPNovaReviewMessageCell.h"
#import "PPNovaFloatingInputBarView.h"
#import "AppManager.h"
#import "PPNavigationController.h"
#import "PetAccessoryManager.h"
#import "CartManager.h"
#import "PPNovaLocalChatMemory.h"
#import "CartItem.h"
#import "PPHUD.h"
#import "AccessViewerVC.h"
#import "ViewerVC.h"
#import "ServiceViewerViewController.h"
#import "PPPetCareViewerVC.h"
#import "PetAdManager.h"
#import "AdoptPetManager.h"
#import "AdoptPetModel.h"
#import "AdoptPetDetailsViewController.h"
#import "PPPetCareVetViewrVC.h"
#import "PPOverlayCoordinator.h"
#import "PPChatFeedbackManager.h"
#import "PPAnalytics.h"
#import "PPUserSigningManager.h"
#import <IQKeyboardManager/IQKeyboardManager.h>

static UIColor *PPNovaDynamicColor(UIColor *lightColor, UIColor *darkColor) {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
        }];
    }
    return lightColor;
}

static const CGFloat PPNovaExpandedTableTopInset = 218.0;
static const CGFloat PPNovaCollapsedTableTopInset = 124.0;
static const CGFloat PPNovaTableBottomInset = 22.0;
static NSString * const PPNovaCallableRegion = @"us-central1";
static NSString * const PPNovaCallableName = @"geminiProxy";
static NSString * const PPNovaFirebaseProjectID = @"pure-pets-49199";

@interface PPNovaChatViewController () <UITableViewDelegate, UITableViewDataSource, PPNovaFloatingInputBarViewDelegate, PPNovaProductMessageCellDelegate>

@property (nonatomic, strong) UIView *ambientBackgroundView;
@property (nonatomic, strong) UIView *novaChatBottomGlowView;
@property (nonatomic, strong) UIView *novaHeaderView;
@property (nonatomic, strong) UIView *novaHeaderChromeView;
@property (nonatomic, strong) UIView *novaHeaderTopGlowView;
@property (nonatomic, strong) UIView *novaHeaderBottomGlowView;
@property (nonatomic, strong) UIView *novaHeaderSheenView;
@property (nonatomic, strong) CAShapeLayer *novaHeaderLiquidBorderLayer;
@property (nonatomic, strong) CAShapeLayer *novaHeaderLiquidHighlightLayer;
@property (nonatomic, copy) NSArray<UIView *> *novaHeaderMotionDots;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIView *headerBrandHaloView;
@property (nonatomic, strong) UIView *headerBrandRingView;
@property (nonatomic, strong) UIView *headerBrandMarkView;
@property (nonatomic, strong) UIView *headerHairlineHost;
@property (nonatomic, strong) UIView *headerLiveCapsule;
@property (nonatomic, strong) UIView *statusDot;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *headerNameLabel;
@property (nonatomic, strong) UILabel *headerSubtitleLabel;
@property (nonatomic, strong) NSLayoutConstraint *brandRingCenterXConstraint;
@property (nonatomic, strong) NSLayoutConstraint *brandRingLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *nameLabelCenterXConstraint;
@property (nonatomic, strong) NSLayoutConstraint *nameLabelLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *nameLabelTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *nameLabelCenterYConstraint;
@property (nonatomic, strong) NSLayoutConstraint *subtitleLabelCenterXConstraint;
@property (nonatomic, strong) NSLayoutConstraint *subtitleLabelLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *subtitleLabelTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *novaHeaderExpandedBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *emptyStateCenterYConstraint;
@property (nonatomic, strong) NSLayoutConstraint *novaHeaderCollapsedBottomConstraint;
@property (nonatomic, assign) BOOL didInitialInset;
@property (nonatomic, assign) BOOL novaHeaderCollapsed;
@property (nonatomic, strong) UIVisualEffectView *typingContainer;
@property (nonatomic, strong) UILabel *typingLabel;
@property (nonatomic, copy)   NSArray<UIView *> *typingDots;
@property (nonatomic, strong) UIView *emptyStateView;
@property (nonatomic, strong) UIView *emptyStatePulseView;
@property (nonatomic, strong) UIVisualEffectView *smartSuggestionSurfaceView;
@property (nonatomic, strong) UILabel *smartSuggestionTitleLabel;
@property (nonatomic, copy) NSArray<UIButton *> *smartSuggestionButtons;

@property (nonatomic, strong) LOTAnimationView *novaHeaderBackgroundLottie;
@property (nonatomic, copy) NSString *currentHeaderBgAnimationName;
@property (nonatomic, strong) LOTAnimationView *novaRingBackgroundLottie;
@property (nonatomic, strong) LOTAnimationView *novaLoadingLottie; // Added for thinking state
@property (nonatomic, assign) BOOL novaHeaderThinkingAnimationVisible;

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
@property (nonatomic, assign) BOOL iqStateSaved;
@property (nonatomic, assign) BOOL dismissed;
@property (nonatomic, assign) CGFloat lastNovaTableLayoutWidth;
@property (nonatomic, assign) NSUInteger novaRequestGeneration;

@end

@implementation PPNovaChatViewController

+ (void)presentNovaFromViewController:(UIViewController *)presentingVC {
    // Auth gate. Logged-out users see the standard sign-in flow instead of a
    // dead Nova chat that would only ever return "session expired" from the
    // server. requireSignInFrom: returns YES if already signed in (continue),
    // NO if it just presented sign-in (re-present Nova on success).
    if (presentingVC) {
        BOOL alreadyAuthed =
            [PPUserSigningManager requireSignInFrom:presentingVC
                                            success:^(UserModel * _Nonnull user) {
                                                if (user && presentingVC) {
                                                    [PPNovaChatViewController presentNovaFromViewController:presentingVC];
                                                }
                                            }
                                          cancelled:nil];
        if (!alreadyAuthed) {
            return;
        }
    }

    PPNovaChatViewController *novaVC = [[PPNovaChatViewController alloc] init];
    if (@available(iOS 15.0, *)) {
        novaVC.modalPresentationStyle = UIModalPresentationPageSheet;
        UISheetPresentationController *sheet = novaVC.sheetPresentationController;
        if (sheet) {
            if (@available(iOS 16.0, *)) {
                UISheetPresentationControllerDetent *customDetent = [UISheetPresentationControllerDetent customDetentWithIdentifier:@"Nova89" resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
                    return UIScreen.mainScreen.bounds.size.height * 0.89;
                }];
                sheet.detents = @[ [UISheetPresentationControllerDetent largeDetent]];//customDetent,
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
    [PPAnalytics logNovaOpenedWithSessionID:self.novaSessionId];

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

    __weak typeof(self) wself = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(wself) self = wself;
        if (!self || self.dismissed) return;
        [self insertNovaGreeting];
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (!self.iqStateSaved) {
        self.previousIQEnabled = [IQKeyboardManager sharedManager].enable;
        self.previousToolbarEnabled = [IQKeyboardManager sharedManager].enableAutoToolbar;
        self.iqStateSaved = YES;
    }
    [IQKeyboardManager sharedManager].enable = NO;
    [IQKeyboardManager sharedManager].enableAutoToolbar = NO;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();

    if (reduceMotion) {
        self.novaHeaderView.alpha = 1.0;
        self.novaHeaderView.transform = CGAffineTransformIdentity;
        self.novaHeaderTopGlowView.alpha = 1.0;
        self.novaChatBottomGlowView.alpha = 1.0;
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

        [UIView animateWithDuration:0.92
                              delay:0.18
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.novaHeaderTopGlowView.alpha = 1.0;
            self.novaChatBottomGlowView.alpha = 1.0;
        } completion:nil];
    }

    [self pp_startHeaderLiveAnimations];
    [self pp_startAmbientBackgroundAnimations];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    BOOL leavingForGood = self.isBeingDismissed || self.isMovingFromParentViewController;
    if (leavingForGood) {
        self.dismissed = YES;
        if (self.iqStateSaved) {
            [IQKeyboardManager sharedManager].enable = self.previousIQEnabled;
            [IQKeyboardManager sharedManager].enableAutoToolbar = self.previousToolbarEnabled;
        }
        [PPAnalytics logNovaClosedWithSessionID:self.novaSessionId
                                    messageCount:self.messages.count];
    }

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
    [self pp_updateNovaHeaderLiquidBorderPath];

    if (!self.didInitialInset && CGRectGetHeight(self.inputbar.frame) > 0) {
        self.didInitialInset = YES;
        UIEdgeInsets currentInset = self.tableView.contentInset;
        currentInset.bottom = PPNovaTableBottomInset;
        self.tableView.contentInset = currentInset;
        self.tableView.scrollIndicatorInsets = currentInset;
    }

    CGFloat tableWidth = CGRectGetWidth(self.tableView.bounds);
    if (tableWidth <= 1.0 || fabs(tableWidth - self.lastNovaTableLayoutWidth) <= 1.0) {
        return;
    }

    self.lastNovaTableLayoutWidth = tableWidth;
    [self pp_refreshVisibleNovaCellLayoutForCurrentTableWidth];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.statusDot.layer removeAllAnimations];
    [self.headerBrandRingView.layer removeAllAnimations];
    [self.headerBrandMarkView.layer removeAllAnimations];
    [self.novaHeaderLiquidBorderLayer removeAllAnimations];
    [self.novaHeaderLiquidHighlightLayer removeAllAnimations];
    [self.emptyStatePulseView.layer removeAllAnimations];
    [self.novaChatBottomGlowView.layer removeAllAnimations];
    for (UIView *dot in self.typingDots) {
        [dot.layer removeAllAnimations];
    }
}

#pragma mark - Backend

- (void)setupNovaBackend {
    FIRFunctions *functions = [FIRFunctions functionsForRegion:PPNovaCallableRegion];
    self.novaCallable = [functions HTTPSCallableWithName:PPNovaCallableName];
    // Reverting timeout to default 70.0s because 15.0s caused Firebase Functions
    // cold starts and AI delays to timeout frequently.
    self.novaCallable.timeoutInterval = 70.0;
    LOG_INFO(@"[PPNovaChat][Debug] callable url=%@ timeout=%.0fs", [PPNovaChatViewController pp_novaCallableDebugURL], self.novaCallable.timeoutInterval);
}

- (void)sendNovaRequestForUserText:(NSString *)userText {
    NSString *trimmedText = [userText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmedText.length == 0) {
        [self hideNovaTyping];
        return;
    }

    // Update local session memory BEFORE we build the context payload. Idempotent across retries.
    [self pp_updateMemoryFromUserText:trimmedText];

    [PPAnalytics logNovaMessageSentWithCharCount:trimmedText.length
                                         isArabic:[self textContainsArabic:trimmedText]
                                       sessionID:self.novaSessionId];

    self.novaRequestGeneration = self.novaRequestGeneration + 1;
    NSUInteger generation = self.novaRequestGeneration;
    [self pp_startNovaRequestWatchdogForGeneration:generation userText:trimmedText];
    [self pp_dispatchNovaRequest:trimmedText attempt:0 generation:generation];
}

- (void)pp_dispatchNovaRequest:(NSString *)trimmedText attempt:(NSInteger)attempt generation:(NSUInteger)generation {
    if (self.dismissed) return;
    BOOL hasCatalogIntent = [self pp_novaHasCatalogSearchIntentForUserText:trimmedText];

    if (!self.novaCallable) {
        // Backend not initialized — don't fabricate a Nova reply, just try a
        // local product showcase. If nothing scores high enough, the chat stays
        // silent rather than injecting a templated apology.
        [self hideNovaTyping];
        [self pp_fetchAndShowLocalNovaShowcaseForUserText:trimmedText completion:nil];
        return;
    }

    NSDictionary *payload = @{
        @"prompt": trimmedText,
        @"context": [self pp_currentContextDictionary],
        @"history": [self pp_currentHistoryArray],
        @"sessionId": self.novaSessionId,
        @"conversation_state": [self pp_currentNovaBrainStateDictionary]
    };

    LOG_INFO(@"[PPNovaChat][Debug] send url=%@ requestKeys=%@ authUIDPresent=%@",
             [PPNovaChatViewController pp_novaCallableDebugURL],
             [PPNovaChatViewController pp_sortedDictionaryKeys:payload],
             PPCurrentFIRAuthUser.uid.length > 0 ? @"YES" : @"NO");

    __weak typeof(self) weakSelf = self;
    [self.novaCallable callWithObject:payload
                           completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.dismissed) return;

            if (error) {
                if (attempt == 0 && [PPNovaChatViewController pp_isRetryableNovaError:error]) {
                    LOG_WARN(@"[PPNovaChat][Debug] branch=retryable_transient attempt=%ld code=%ld httpStatus=%@",
                             (long)attempt,
                             (long)error.code,
                             [PPNovaChatViewController pp_httpStatusDebugStringFromError:error]);
                    LOG_WARN(@"[PPNovaChat] geminiProxy transient error (will retry once): %@", error.localizedDescription);
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        __strong typeof(weakSelf) inner = weakSelf;
                        if (!inner || inner.dismissed) return;
                        [inner pp_dispatchNovaRequest:trimmedText attempt:1 generation:generation];
                    });
                    return;
                }
                if (generation != self.novaRequestGeneration) {
                    return;
                }
                [self hideNovaTyping];
                LOG_ERROR(@"[PPNovaChat] geminiProxy failed (attempt %ld, code=%ld): %@",
                          (long)attempt, (long)error.code, error.localizedDescription);
                LOG_WARN(@"[PPNovaChat][Debug] error url=%@ httpStatus=%@ userInfoKeys=%@",
                         [PPNovaChatViewController pp_novaCallableDebugURL],
                         [PPNovaChatViewController pp_httpStatusDebugStringFromError:error],
                         [PPNovaChatViewController pp_sortedDictionaryKeys:error.userInfo]);
                [PPAnalytics logNovaErrorWithCode:error.code
                                            domain:error.domain
                                           attempt:attempt
                                         sessionID:self.novaSessionId];

                // If the server attached a structured reason, route to the right UX
                // (sign-in for no_auth/no_profile; dedicated copy for blocked) instead
                // of collapsing every auth-side failure into "session expired".
                NSString *serverReason = [PPNovaChatViewController pp_novaServerReasonFromError:error];
                if ([serverReason isEqualToString:@"no_auth"] ||
                    [serverReason isEqualToString:@"no_profile"]) {
                    LOG_WARN(@"[PPNovaChat][Debug] branch=auth_required reason=%@", serverReason);
                    [self pp_dismissNovaForSignInRequired];
                    return;
                }
                if ([serverReason isEqualToString:@"blocked"]) {
                    LOG_WARN(@"[PPNovaChat][Debug] branch=blocked_account reason=%@", serverReason);
                    [self pp_addNovaSystemBubbleIfNew:kLang(@"nova_error_account_blocked")];
                    return;
                }

                // Connectivity-class errors get a localized status message —
                // these are system events, not Nova "answering" a query. Show
                // them at most once per outage streak so the chat doesn't fill
                // up with identical "unavailable" bubbles when the user keeps
                // typing while the backend is down.
                NSString *userFacing = [PPNovaChatViewController pp_userFacingErrorForNovaError:error];
                if (userFacing.length > 0) {
                    NSString *branch = [userFacing isEqualToString:kLang(@"nova_error_unavailable")]
                        ? @"unavailable_connectivity_or_backend"
                        : @"auth_or_permission_error";
                    LOG_WARN(@"[PPNovaChat][Debug] branch=%@ code=%ld httpStatus=%@",
                             branch,
                             (long)error.code,
                             [PPNovaChatViewController pp_httpStatusDebugStringFromError:error]);
                    // Only the connectivity bubble can be suppressed by a
                    // successful local product showcase — auth/permission
                    // errors must always surface so the user knows to re-auth.
                    if ([userFacing isEqualToString:kLang(@"nova_error_unavailable")]) {
                        __weak typeof(self) localWeakSelf = self;
                        [self pp_fetchAndShowLocalNovaShowcaseForUserText:trimmedText
                                                              completion:^(BOOL didShow) {
                            __strong typeof(localWeakSelf) strongSelf = localWeakSelf;
                            if (!strongSelf || strongSelf.dismissed) return;
                            if (!didShow) {
                                [strongSelf pp_addNovaSystemBubbleIfNew:userFacing];
                            }
                        }];
                        return;
                    }
                    [self pp_addNovaSystemBubbleIfNew:userFacing];
                    return;
                }
                // Anything else: try a local product showcase silently. No
                // templated apology — if local search has no relevant items,
                // the chat stays quiet rather than fabricating a Nova reply.
                [self pp_fetchAndShowLocalNovaShowcaseForUserText:trimmedText completion:nil];
                return;
            }
            if (generation != self.novaRequestGeneration) {
                return;
            }

            NSString *replyText = nil;
            NSString *serverAction = nil;
            NSArray<NSDictionary<NSString *, NSString *> *> *suggestionRefs = @[];
            if ([result.data isKindOfClass:NSDictionary.class]) {
                NSDictionary *data = (NSDictionary *)result.data;
                LOG_INFO(@"[PPNovaChat][Debug] responseKeys=%@ httpStatus=%@",
                         [PPNovaChatViewController pp_sortedDictionaryKeys:data],
                         @"n/a");
                serverAction = [PPNovaChatViewController pp_novaBrainActionFromResponseData:data];
                // Prefer the new canonical `assistantText` field; fall back to
                // legacy `text` so older Cloud Function builds still work.
                id assistantTextValue = data[@"assistantText"];
                id textValue = data[@"text"];
                if ([assistantTextValue isKindOfClass:NSString.class] &&
                    [(NSString *)assistantTextValue length] > 0) {
                    replyText = (NSString *)assistantTextValue;
                } else if ([textValue isKindOfClass:NSString.class]) {
                    replyText = (NSString *)textValue;
                }
                suggestionRefs = [self pp_novaSuggestionRefsFromResponseData:data replyText:replyText];
                LOG_INFO(@"[PPNovaChat][Refs] received_from_server=%lu assistantTextChars=%lu",
                         (unsigned long)suggestionRefs.count,
                         (unsigned long)replyText.length);
            } else {
                LOG_WARN(@"[PPNovaChat][Debug] branch=response_not_dictionary responseType=%@ httpStatus=%@",
                         result.data ? NSStringFromClass([result.data class]) : @"nil",
                         @"n/a");
                suggestionRefs = [self pp_novaSuggestionRefsFromResponseData:nil replyText:replyText];
            }

            replyText = [replyText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            // Nova Brain clarification/response actions are terminal: render the
            // reply and skip the local showcase fallback so unclear text never
            // triggers product cards.
            if ([serverAction isEqualToString:@"ASK_CLARIFICATION"] ||
                [serverAction isEqualToString:@"RESPOND"]) {
                [self hideNovaTyping];
                NSString *sanitizedReply = [self pp_sanitizeNovaReply:replyText hideStructuredSuggestions:YES];
                if (sanitizedReply.length > 0) {
                    [self addNovaMessage:sanitizedReply];
                }
                return;
            }
            if (replyText.length == 0 && suggestionRefs.count == 0) {
                [self hideNovaTyping];
                LOG_WARN(@"[PPNovaChat][Debug] branch=empty_text_and_empty_products responseKeys=%@",
                         [result.data isKindOfClass:NSDictionary.class]
                            ? [PPNovaChatViewController pp_sortedDictionaryKeys:(NSDictionary *)result.data]
                            : @[]);
                LOG_WARN(@"[PPNovaChat] geminiProxy returned empty reply and no products; trying local showcase silently.");
                // Don't synthesize a Nova reply on emptiness — try local
                // products silently. If the AI returned nothing meaningful,
                // injecting a scripted line on its behalf would impersonate it.
                [self pp_fetchAndShowLocalNovaShowcaseForUserText:trimmedText
                                                        completion:^(BOOL didShow) {
                    if (!didShow && hasCatalogIntent) {
                        [self pp_addNovaProductResultTextForRenderedCount:0
                                                             proposedText:nil
                                                                 userText:trimmedText
                                                                   source:@"local_empty_after_empty_response"];
                    }
                }];
                return;
            }

            NSString *suggestionFallbackText = nil;
            NSString *deferredNoProductReply = nil;
            NSString *deferredModelReplyIfNoLocalProducts = nil;
            NSString *localShowcaseIntroText = nil;
            NSString *pendingResolvedProductText = nil;
            if (replyText.length > 0) {
                NSString *sanitizedReply = [self pp_sanitizeNovaReply:replyText hideStructuredSuggestions:(suggestionRefs.count > 0)];
                if (sanitizedReply.length > 0) {
                    if ([self pp_novaReplyContainsNoProductClaim:sanitizedReply]) {
                        if (suggestionRefs.count > 0) {
                            pendingResolvedProductText = nil;
                        } else {
                            deferredNoProductReply = sanitizedReply;
                            localShowcaseIntroText = nil;
                        }
                    } else if (suggestionRefs.count > 0) {
                        // Always use the server's AI reply alongside product cells.
                        // The behavior layer already crafted a natural assistant message;
                        // replacing it with a template silences the AI personality.
                        pendingResolvedProductText = sanitizedReply;
                    } else if (hasCatalogIntent) {
                        deferredModelReplyIfNoLocalProducts = sanitizedReply;
                        localShowcaseIntroText = sanitizedReply;
                    } else {
                        [self addNovaMessage:sanitizedReply];
                    }
                } else if (suggestionRefs.count == 0) {
                    // Structured-strip emptied a reply that has no product refs.
                    // Try the lighter strip (only [PRODUCT_ID:] tags) so the
                    // model's actual answer survives. If even that is empty,
                    // stay silent — never inject a templated apology on the
                    // AI's behalf.
                    NSString *unstrippedReply = [self pp_sanitizeNovaReply:replyText hideStructuredSuggestions:NO];
                    if (unstrippedReply.length > 0) {
                        if ([self pp_novaReplyContainsNoProductClaim:unstrippedReply]) {
                            deferredNoProductReply = unstrippedReply;
                            localShowcaseIntroText = nil;
                        } else if (hasCatalogIntent) {
                            deferredModelReplyIfNoLocalProducts = unstrippedReply;
                            localShowcaseIntroText = unstrippedReply;
                        } else {
                            [self addNovaMessage:unstrippedReply];
                        }
                    } else {
                        [self hideNovaTyping];
                        [self pp_fetchAndShowLocalNovaShowcaseForUserText:trimmedText completion:nil];
                        return;
                    }
                } else {
                    suggestionFallbackText = pendingResolvedProductText ?: [self pp_sanitizeNovaReply:replyText hideStructuredSuggestions:NO];
                }
            }

            if (suggestionRefs.count > 0) {
                // No scripted fallback text — pass nil so the resolver only
                // shows the AI's own reply (already added above) plus whatever
                // products it can resolve. Templated apologies on resolution
                // failure are gone.
                [self pp_fetchAndShowNovaSuggestionRefs:suggestionRefs
                                           fallbackText:pendingResolvedProductText ?: suggestionFallbackText
                                               userText:trimmedText];
            } else {
                [self hideNovaTyping];
                if (deferredNoProductReply.length > 0 || deferredModelReplyIfNoLocalProducts.length > 0) {
                    __weak typeof(self) localWeakSelf = self;
                    [self pp_fetchAndShowLocalNovaShowcaseForUserText:trimmedText
                                                            introText:localShowcaseIntroText
                                                           completion:^(BOOL didShow) {
                        __strong typeof(localWeakSelf) strongSelf = localWeakSelf;
                        if (!strongSelf || strongSelf.dismissed || didShow) return;
                        NSString *modelReply = deferredModelReplyIfNoLocalProducts ?: deferredNoProductReply;
                        if (modelReply.length > 0) {
                            [strongSelf addNovaMessage:modelReply];
                        } else {
                            [strongSelf pp_addNovaProductResultTextForRenderedCount:0
                                                                       proposedText:nil
                                                                           userText:trimmedText
                                                                             source:@"local_empty_after_model_text"];
                        }
                    }];
                } else {
                    [self pp_fetchAndShowLocalNovaShowcaseForUserText:trimmedText
                                                            completion:^(BOOL didShow) {
                        if (!didShow && hasCatalogIntent) {
                            [self pp_addNovaProductResultTextForRenderedCount:0
                                                                 proposedText:nil
                                                                     userText:trimmedText
                                                                       source:@"local_empty_after_response"];
                        }
                    }];
                }
            }
        });
    }];
}

- (void)pp_startNovaRequestWatchdogForGeneration:(NSUInteger)generation userText:(NSString *)userText {
    NSString *query = [userText copy] ?: @"";
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(35.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.dismissed || generation != self.novaRequestGeneration) {
            return;
        }
        if (self.typingContainer.alpha <= 0.01) {
            return;
        }

        LOG_WARN(@"[PPNovaChat][Debug] branch=request_watchdog_timeout generation=%lu",
                 (unsigned long)generation);
        [self hideNovaTyping];
        if ([self pp_novaHasCatalogSearchIntentForUserText:query] &&
            ![self pp_novaIsGenericConversationText:query]) {
            [self pp_fetchAndShowLocalNovaShowcaseForUserText:query
                                                    completion:^(BOOL didShow) {
                if (!didShow) {
                    [self pp_addNovaSystemBubbleIfNew:kLang(@"nova_error_unavailable")];
                }
            }];
        } else {
            [self pp_addNovaSystemBubbleIfNew:kLang(@"nova_error_unavailable")];
        }
    });
}

+ (NSString *)pp_novaCallableDebugURL {
    return [NSString stringWithFormat:@"https://%@-%@.cloudfunctions.net/%@",
            PPNovaCallableRegion,
            PPNovaFirebaseProjectID,
            PPNovaCallableName];
}

+ (NSArray<NSString *> *)pp_sortedDictionaryKeys:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:NSDictionary.class] || dictionary.count == 0) {
        return @[];
    }

    NSMutableArray<NSString *> *keys = [NSMutableArray arrayWithCapacity:dictionary.count];
    for (id key in dictionary.allKeys) {
        NSString *keyString = [key isKindOfClass:NSString.class] ? key : [key description];
        if (keyString.length > 0) {
            [keys addObject:keyString];
        }
    }
    [keys sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return keys.copy;
}

+ (nullable NSString *)pp_novaBrainActionFromResponseData:(NSDictionary *)data {
    if (![data isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    id action = data[@"action"];
    if ([action isKindOfClass:NSString.class] && [(NSString *)action length] > 0) {
        return (NSString *)action;
    }
    id brain = data[@"novaBrain"];
    if ([brain isKindOfClass:NSDictionary.class]) {
        id nestedAction = ((NSDictionary *)brain)[@"action"];
        if ([nestedAction isKindOfClass:NSString.class] && [(NSString *)nestedAction length] > 0) {
            return (NSString *)nestedAction;
        }
    }
    return nil;
}

+ (NSString *)pp_httpStatusDebugStringFromError:(NSError *)error {
    if (!error) {
        return @"n/a";
    }

    id directStatus = error.userInfo[@"status"] ?: error.userInfo[@"httpStatus"] ?: error.userInfo[@"HTTPStatus"];
    if ([directStatus respondsToSelector:@selector(stringValue)]) {
        return [directStatus stringValue];
    }

    for (id key in error.userInfo.allKeys) {
        NSString *keyString = [[key description] lowercaseString];
        if (![keyString containsString:@"status"] && ![keyString containsString:@"http"]) {
            continue;
        }
        id value = error.userInfo[key];
        if ([value isKindOfClass:NSHTTPURLResponse.class]) {
            return [NSString stringWithFormat:@"%ld", (long)[(NSHTTPURLResponse *)value statusCode]];
        }
        if ([value respondsToSelector:@selector(stringValue)]) {
            return [value stringValue];
        }
        if ([value isKindOfClass:NSString.class] && [(NSString *)value length] > 0) {
            return value;
        }
    }

    return @"n/a";
}

+ (BOOL)pp_isRetryableNovaError:(NSError *)error {
    // Retry on transient gRPC codes (Unknown=2, DeadlineExceeded=4, ResourceExhausted=8,
    // Internal=13, Unavailable=14) and on raw network errors.
    NSInteger code = error.code;
    if (code == 2 || code == 4 || code == 8 || code == 13 || code == 14) return YES;
    if ([error.domain isEqualToString:NSURLErrorDomain]) return YES;
    return NO;
}

+ (nullable NSString *)pp_userFacingErrorForNovaError:(NSError *)error {
    // Map specific error classes to localized user-facing strings. Returning nil means
    // "fall through to the generic local fallback" — used for unknown / handled-elsewhere cases.
    NSInteger code = error.code;
    // Unauthenticated=16, PermissionDenied=7 — surface as session-expired.
    if (code == 16 || code == 7) {
        return kLang(@"nova_error_auth");
    }
    // Unavailable=14 / ResourceExhausted=8 after retry exhausted — be honest, don't pretend.
    if (code == 14 || code == 8) {
        return kLang(@"nova_error_unavailable");
    }
    return nil;
}

// Reads geminiProxy's `details.reason` ({"no_auth","no_profile","blocked"}) so the
// client can route auth-side failures to the right UX. The Functions iOS SDK
// stores the HttpsError details under userInfo[@"details"].
+ (nullable NSString *)pp_novaServerReasonFromError:(NSError *)error {
    if (error.code != 7 && error.code != 16) {
        return nil;
    }
    id details = error.userInfo[@"details"];
    if (![details isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    id reason = ((NSDictionary *)details)[@"reason"];
    return [reason isKindOfClass:NSString.class] ? (NSString *)reason : nil;
}

// Dismiss Nova and re-trigger the standard sign-in flow. Used when the server
// reports the caller is not authenticated (or has no UsersCol profile yet).
- (void)pp_dismissNovaForSignInRequired {
    UIViewController *presenter = self.presentingViewController;
    NSString *signInMessage = kLang(@"nova_error_signin_required");
    [self dismissViewControllerAnimated:YES completion:^{
        UIViewController *target = presenter ?: [UIApplication sharedApplication].delegate.window.rootViewController;
        if (!target) return;
        [PPUserSigningManager requireSignInFrom:target
                                    withMessage:signInMessage
                                        success:^(UserModel * _Nonnull user) {
                                            if (user) {
                                                [PPNovaChatViewController presentNovaFromViewController:target];
                                            }
                                        }
                                      cancelled:nil];
    }];
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)pp_novaSuggestionRefsFromResponseData:(NSDictionary *)data
                                                                                 replyText:(NSString *)replyText
{
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *refs = [NSMutableArray array];

    if ([data isKindOfClass:NSDictionary.class]) {
        NSDictionary<NSString *, NSString *> *keyKinds = @{
            @"productIDs": @"product", @"productIds": @"product", @"product_ids": @"product",
            @"accessoryIDs": @"product", @"accessoryIds": @"product", @"itemIDs": @"product",
            @"medicineIDs": @"medicine", @"medicineIds": @"medicine", @"medicine_ids": @"medicine",
            @"serviceIDs": @"service", @"serviceIds": @"service", @"service_ids": @"service",
            @"petAdIDs": @"pet_ad", @"petAdIds": @"pet_ad", @"pet_ad_ids": @"pet_ad",
            @"adIDs": @"pet_ad", @"adIds": @"pet_ad", @"ad_ids": @"pet_ad",
            @"adoptPetIDs": @"adoption", @"adoptPetIds": @"adoption", @"adopt_pet_ids": @"adoption",
            @"adoptionIDs": @"adoption", @"adoptionIds": @"adoption", @"adoption_ids": @"adoption",
            @"vetIDs": @"vet", @"vetIds": @"vet", @"vet_ids": @"vet",
            @"veterinarianIDs": @"vet", @"veterinarianIds": @"vet", @"veterinarian_ids": @"vet"
        };
        [keyKinds enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *kind, BOOL *stop) {
            [self pp_appendNovaSuggestionRefsFromIDs:data[key] kind:kind toRefs:refs];
        }];

        NSDictionary<NSString *, NSString *> *arrayKeyKinds = @{
            @"suggestions": @"", @"recommendations": @"", @"results": @"",
            @"resultRefs": @"", @"result_refs": @"",
            @"products": @"product", @"items": @"product",
            @"services": @"service", @"medicines": @"medicine",
            @"petAds": @"pet_ad", @"pet_ads": @"pet_ad",
            @"adoptions": @"adoption", @"adoptPets": @"adoption", @"adopt_pets": @"adoption",
            @"vets": @"vet", @"veterinarians": @"vet"
        };
        [arrayKeyKinds enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *kind, BOOL *stop) {
            [self pp_appendNovaSuggestionRefsFromValue:data[key]
                                                toRefs:refs
                                         preferredKind:(kind.length > 0 ? kind : nil)];
        }];
    }

    [self pp_appendNovaSuggestionRefsFromText:replyText toRefs:refs];
    return [self pp_uniqueNovaSuggestionRefs:refs];
}

- (void)pp_appendNovaSuggestionRefsFromIDs:(id)value
                                      kind:(NSString *)kind
                                    toRefs:(NSMutableArray<NSDictionary<NSString *, NSString *> *> *)refs
{
    if (kind.length == 0) {
        return;
    }
    if ([value isKindOfClass:NSArray.class]) {
        for (id entry in (NSArray *)value) {
            NSString *identifier = [self pp_novaStringFromValue:entry];
            if (identifier.length > 0) {
                [refs addObject:@{@"kind": kind, @"id": identifier}];
            }
        }
        return;
    }
    NSString *identifier = [self pp_novaStringFromValue:value];
    if (identifier.length > 0) {
        [refs addObject:@{@"kind": kind, @"id": identifier}];
    }
}

- (void)pp_appendNovaSuggestionRefsFromValue:(id)value
                                      toRefs:(NSMutableArray<NSDictionary<NSString *, NSString *> *> *)refs
                               preferredKind:(NSString *)preferredKind
{
    if (!value) {
        return;
    }
    if ([value isKindOfClass:NSArray.class]) {
        for (id entry in (NSArray *)value) {
            [self pp_appendNovaSuggestionRefsFromValue:entry toRefs:refs preferredKind:preferredKind];
        }
        return;
    }
    if ([value isKindOfClass:NSDictionary.class]) {
        NSDictionary *dict = (NSDictionary *)value;
        NSString *kind = [self pp_novaSuggestionKindFromDictionary:dict preferredKind:preferredKind];
        NSString *identifier = [self pp_novaSuggestionIdentifierFromDictionary:dict kind:kind];
        if (kind.length > 0 && identifier.length > 0) {
            [refs addObject:@{@"kind": kind, @"id": identifier}];
        }
        return;
    }
    if (preferredKind.length > 0) {
        NSString *identifier = [self pp_novaStringFromValue:value];
        if (identifier.length > 0) {
            [refs addObject:@{@"kind": preferredKind, @"id": identifier}];
        }
    }
}

- (NSString *)pp_novaSuggestionKindFromDictionary:(NSDictionary *)dict preferredKind:(NSString *)preferredKind {
    if ([self pp_novaStringFromDictionary:dict keys:@[@"petAdID", @"petAdId", @"pet_ad_id", @"adID", @"adId", @"ad_id"]].length > 0) {
        return @"pet_ad";
    }
    if ([self pp_novaStringFromDictionary:dict keys:@[@"adoptPetID", @"adoptPetId", @"adopt_pet_id", @"adoptionID", @"adoptionId", @"adoption_id"]].length > 0) {
        return @"adoption";
    }
    if ([self pp_novaStringFromDictionary:dict keys:@[@"serviceID", @"serviceId", @"service_id"]].length > 0) {
        return @"service";
    }
    if ([self pp_novaStringFromDictionary:dict keys:@[@"vetID", @"vetId", @"vet_id", @"veterinarianID", @"veterinarianId", @"veterinarian_id"]].length > 0) {
        return @"vet";
    }
    if ([self pp_novaStringFromDictionary:dict keys:@[@"medicineID", @"medicineId", @"medicine_id"]].length > 0) {
        return @"medicine";
    }
    if ([self pp_novaStringFromDictionary:dict keys:@[@"productID", @"productId", @"product_id", @"accessoryID", @"accessoryId", @"accessory_id"]].length > 0) {
        return @"product";
    }

    id rawKindValue = dict[@"kind"] ?: dict[@"itemType"] ?: dict[@"collection"] ?: dict[@"collectionName"] ?: dict[@"type"];
    NSString *rawKind = [[self pp_novaStringFromValue:rawKindValue] lowercaseString];
    if ([rawKind containsString:@"pet_ad"] || [rawKind containsString:@"pet ad"] ||
        [rawKind containsString:@"pet_ads"] || [rawKind isEqualToString:@"ads"]) {
        return @"pet_ad";
    }
    if ([rawKind containsString:@"adoption"] || [rawKind containsString:@"adopt"] ||
        [rawKind containsString:@"adopt_pets"]) {
        return @"adoption";
    }
    if ([rawKind containsString:@"service"]) {
        return @"service";
    }
    if ([rawKind containsString:@"vet"] || [rawKind containsString:@"veterinarian"]) {
        return @"vet";
    }
    if ([rawKind containsString:@"medicine"] || [rawKind containsString:@"medic"] || [rawKind containsString:@"pharmacy"]) {
        return @"medicine";
    }
    if ([rawKind containsString:@"product"] || [rawKind containsString:@"accessory"] || [rawKind containsString:@"petaccessor"]) {
        return @"product";
    }

    id accessKindValue = dict[@"accessKindType"] ?: dict[@"access_kind_type"] ?: dict[@"type"];
    if ([accessKindValue respondsToSelector:@selector(integerValue)] &&
        [accessKindValue integerValue] == AccessTypePetMedicine) {
        return @"medicine";
    }
    return preferredKind.length > 0 ? preferredKind : @"product";
}

- (NSString *)pp_novaSuggestionIdentifierFromDictionary:(NSDictionary *)dict kind:(NSString *)kind {
    NSArray<NSString *> *primaryKeys = @[@"productID", @"productId", @"product_id", @"accessoryID", @"accessoryId", @"accessory_id"];
    if ([kind isEqualToString:@"service"]) {
        primaryKeys = @[@"serviceID", @"serviceId", @"service_id"];
    } else if ([kind isEqualToString:@"vet"]) {
        primaryKeys = @[@"vetID", @"vetId", @"vet_id", @"veterinarianID", @"veterinarianId", @"veterinarian_id"];
    } else if ([kind isEqualToString:@"pet_ad"]) {
        primaryKeys = @[@"petAdID", @"petAdId", @"pet_ad_id", @"adID", @"adId", @"ad_id", @"productID", @"productId", @"product_id"];
    } else if ([kind isEqualToString:@"adoption"]) {
        primaryKeys = @[@"adoptPetID", @"adoptPetId", @"adopt_pet_id", @"adoptionID", @"adoptionId", @"adoption_id", @"productID", @"productId", @"product_id"];
    } else if ([kind isEqualToString:@"medicine"]) {
        primaryKeys = @[@"medicineID", @"medicineId", @"medicine_id", @"productID", @"productId", @"product_id", @"accessoryID", @"accessoryId", @"accessory_id"];
    }
    NSString *identifier = [self pp_novaStringFromDictionary:dict keys:primaryKeys];
    if (identifier.length > 0) {
        return identifier;
    }
    return [self pp_novaStringFromDictionary:dict keys:@[@"id", @"documentID", @"documentId", @"docID", @"docId", @"itemID", @"itemId"]];
}

- (NSString *)pp_novaStringFromDictionary:(NSDictionary *)dict keys:(NSArray<NSString *> *)keys {
    for (NSString *key in keys) {
        NSString *value = [self pp_novaStringFromValue:dict[key]];
        if (value.length > 0) {
            return value;
        }
    }
    return @"";
}

- (NSString *)pp_novaStringFromValue:(id)value {
    if ([value isKindOfClass:NSString.class]) {
        return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        return [[value stringValue] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    return @"";
}

- (void)pp_appendNovaSuggestionRefsFromText:(NSString *)text
                                     toRefs:(NSMutableArray<NSDictionary<NSString *, NSString *> *> *)refs
{
    if (text.length == 0) {
        return;
    }
    NSArray<NSDictionary<NSString *, NSString *> *> *patterns = @[
        @{@"kind": @"product", @"pattern": @"\\[PRODUCT_ID:\\s*([^\\]]+)\\]"},
        @{@"kind": @"service", @"pattern": @"\\[SERVICE_ID:\\s*([^\\]]+)\\]"},
        @{@"kind": @"medicine", @"pattern": @"\\[MEDICINE_ID:\\s*([^\\]]+)\\]"},
        @{@"kind": @"pet_ad", @"pattern": @"\\[PET_AD_ID:\\s*([^\\]]+)\\]"},
        @{@"kind": @"pet_ad", @"pattern": @"\\[AD_ID:\\s*([^\\]]+)\\]"},
        @{@"kind": @"adoption", @"pattern": @"\\[ADOPTION_ID:\\s*([^\\]]+)\\]"},
        @{@"kind": @"adoption", @"pattern": @"\\[ADOPT_PET_ID:\\s*([^\\]]+)\\]"},
        @{@"kind": @"vet", @"pattern": @"\\[VET_ID:\\s*([^\\]]+)\\]"},
        @{@"kind": @"vet", @"pattern": @"\\[VETERINARIAN_ID:\\s*([^\\]]+)\\]"}
    ];
    for (NSDictionary<NSString *, NSString *> *entry in patterns) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:entry[@"pattern"]
                                                                               options:NSRegularExpressionCaseInsensitive
                                                                                 error:nil];
        if (!regex) {
            continue;
        }
        NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:text options:0 range:NSMakeRange(0, text.length)];
        for (NSTextCheckingResult *match in matches) {
            if (match.numberOfRanges < 2) {
                continue;
            }
            NSString *identifier = [[text substringWithRange:[match rangeAtIndex:1]]
                stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (identifier.length > 0) {
                [refs addObject:@{@"kind": entry[@"kind"], @"id": identifier}];
            }
        }
    }
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)pp_uniqueNovaSuggestionRefs:(NSArray<NSDictionary<NSString *, NSString *> *> *)refs {
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *ordered = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (NSDictionary<NSString *, NSString *> *ref in refs) {
        NSString *kind = ref[@"kind"];
        NSString *identifier = [self pp_normalizedNovaSuggestionIdentifier:ref[@"id"]];
        if (kind.length == 0 || identifier.length == 0) {
            continue;
        }
        NSString *key = [NSString stringWithFormat:@"%@:%@", kind, identifier];
        if ([seen containsObject:key]) {
            continue;
        }
        [seen addObject:key];
        [ordered addObject:@{@"kind": kind, @"id": identifier}];
    }
    return ordered.copy;
}

- (NSString *)pp_normalizedNovaSuggestionIdentifier:(NSString *)identifier {
    NSString *normalized = [identifier isKindOfClass:NSString.class]
        ? [identifier stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        : @"";
    if (normalized.length == 0) {
        return @"";
    }

    NSString *pathless = normalized.lastPathComponent;
    if (pathless.length > 0 &&
        ([normalized containsString:@"/petAccessories/"] ||
         [normalized containsString:@"/serviceOffers/"] ||
         [normalized containsString:@"/veterinarians/"] ||
         [normalized containsString:@"/pet_ads/"] ||
         [normalized containsString:@"/adopt_pets/"] ||
         [normalized hasPrefix:@"petAccessories/"] ||
         [normalized hasPrefix:@"serviceOffers/"] ||
         [normalized hasPrefix:@"veterinarians/"] ||
         [normalized hasPrefix:@"pet_ads/"] ||
         [normalized hasPrefix:@"adopt_pets/"])) {
        normalized = pathless;
    }

    return [normalized stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (void)pp_fetchAndShowNovaSuggestionRefs:(NSArray<NSDictionary<NSString *, NSString *> *> *)refs
                             fallbackText:(NSString *)fallbackText
                                 userText:(NSString *)userText {
    if (refs.count == 0) {
        return;
    }

    NSMutableArray<NSString *> *accessoryIDs = [NSMutableArray array];
    NSMutableArray<NSString *> *serviceIDs = [NSMutableArray array];
    NSMutableArray<NSString *> *petAdIDs = [NSMutableArray array];
    NSMutableArray<NSString *> *adoptionIDs = [NSMutableArray array];
    NSMutableArray<NSString *> *vetIDs = [NSMutableArray array];
    for (NSDictionary<NSString *, NSString *> *ref in refs) {
        NSString *kind = ref[@"kind"];
        NSString *identifier = ref[@"id"];
        if (identifier.length == 0) {
            continue;
        }
        if ([kind isEqualToString:@"service"]) {
            [serviceIDs addObject:identifier];
        } else if ([kind isEqualToString:@"vet"]) {
            [vetIDs addObject:identifier];
        } else if ([kind isEqualToString:@"pet_ad"]) {
            [petAdIDs addObject:identifier];
        } else if ([kind isEqualToString:@"adoption"]) {
            [adoptionIDs addObject:identifier];
        } else {
            [accessoryIDs addObject:identifier];
        }
    }

    dispatch_group_t group = dispatch_group_create();
    __block NSArray<PetAccessory *> *resolvedAccessories = @[];
    __block NSArray<ServiceModel *> *resolvedServices = @[];
    __block NSArray<PetAd *> *resolvedPetAds = @[];
    __block NSArray<AdoptPetModel *> *resolvedAdoptions = @[];
    __block NSArray<VetModel *> *resolvedVets = @[];
    __block BOOL didFinish = NO;

    if (accessoryIDs.count > 0) {
        dispatch_group_enter(group);
        [PetAccessoryManager fetchAccessoriesWithIDs:accessoryIDs completion:^(NSArray<PetAccessory *> * _Nonnull accessories) {
            resolvedAccessories = accessories ?: @[];
            dispatch_group_leave(group);
        }];
    }

    if (serviceIDs.count > 0) {
        dispatch_group_enter(group);
        [self pp_fetchNovaServicesWithIDs:serviceIDs completion:^(NSArray<ServiceModel *> *services) {
            resolvedServices = services ?: @[];
            dispatch_group_leave(group);
        }];
    }

    if (vetIDs.count > 0) {
        dispatch_group_enter(group);
        [self pp_fetchNovaVetsWithIDs:vetIDs completion:^(NSArray<VetModel *> *vets) {
            resolvedVets = vets ?: @[];
            dispatch_group_leave(group);
        }];
    }

    if (petAdIDs.count > 0) {
        dispatch_group_enter(group);
        [PetAdManager fetchAdsWithIDs:petAdIDs completion:^(NSArray<PetAd *> *ads) {
            resolvedPetAds = ads ?: @[];
            dispatch_group_leave(group);
        }];
    }

    if (adoptionIDs.count > 0) {
        dispatch_group_enter(group);
        [AdoptPetManager.shared fetchPetsWithIDs:adoptionIDs completion:^(NSArray<AdoptPetModel *> * _Nullable pets, NSError * _Nullable error) {
            if (error) {
                LOG_WARN(@"[PPNovaChat][Refs] adoption resolution error=%@", error.localizedDescription);
            }
            resolvedAdoptions = pets ?: @[];
            dispatch_group_leave(group);
        }];
    }

    __weak typeof(self) weakSelf = self;
    void (^finish)(BOOL timedOut) = ^(BOOL timedOut) {
        __strong typeof(weakSelf) self = weakSelf;
        if (didFinish || !self || self.dismissed) {
            return;
        }
        didFinish = YES;

        if (timedOut) {
            LOG_WARN(@"[PPNovaChat] Nova suggestion resolution timed out: %@", refs);
        }

        [self hideNovaTyping];

        NSDictionary<NSString *, PetAccessory *> *accessoriesByID = [self pp_novaAccessoriesByID:resolvedAccessories];
        NSDictionary<NSString *, ServiceModel *> *servicesByID = [self pp_novaServicesByID:resolvedServices];
        NSDictionary<NSString *, PetAd *> *petAdsByID = [self pp_novaPetAdsByID:resolvedPetAds];
        NSDictionary<NSString *, AdoptPetModel *> *adoptionsByID = [self pp_novaAdoptionsByID:resolvedAdoptions];
        NSDictionary<NSString *, VetModel *> *vetsByID = [self pp_novaVetsByID:resolvedVets];
        NSMutableArray *objects = [NSMutableArray array];
        for (NSDictionary<NSString *, NSString *> *ref in refs) {
            NSString *identifier = ref[@"id"];
            NSString *kind = ref[@"kind"];
            id object = nil;
            if ([kind isEqualToString:@"service"]) {
                object = servicesByID[identifier];
            } else if ([kind isEqualToString:@"vet"]) {
                object = vetsByID[identifier];
            } else if ([kind isEqualToString:@"pet_ad"]) {
                object = petAdsByID[identifier];
            } else if ([kind isEqualToString:@"adoption"]) {
                object = adoptionsByID[identifier];
            } else {
                object = accessoriesByID[identifier];
            }
            if (object) {
                [objects addObject:object];
            }
        }

        // Per Nova architecture rules: card-resolution failure must NEVER
        // swallow the assistant's natural text. If Nova said something and we
        // simply can't resolve the IDs, the customer still gets her words.
        // Telemetry counts what we received vs. resolved so we can see
        // unresolved IDs in production logs.
        NSUInteger requestedCount = refs.count;
        NSUInteger resolvedCount = objects.count;
        NSUInteger unresolvedCount = (requestedCount > resolvedCount) ? (requestedCount - resolvedCount) : 0;
        BOOL hasAssistantText = fallbackText.length > 0;
        LOG_INFO(@"[PPNovaChat][Refs] received=%lu resolved=%lu unresolved=%lu assistantTextChars=%lu",
                 (unsigned long)requestedCount,
                 (unsigned long)resolvedCount,
                 (unsigned long)unresolvedCount,
                 (unsigned long)fallbackText.length);

        if (objects.count == 0) {
            LOG_WARN(@"[PPNovaChat] Nova returned %lu suggestion ref(s) but none resolved: %@",
                     (unsigned long)refs.count, refs);

            [PPAnalytics logNovaShowcaseResolutionFailedWithRequestedCount:refs.count
                                                              resolvedCount:0
                                                                  sessionID:self.novaSessionId];

            // Resolution failed. Try a local product showcase silently. If it
            // also produces nothing, fall back to Nova's own assistantText so
            // her message is never lost to a card-resolve failure. The AI text
            // is the source of truth for what Nova said; cards are only the
            // visual layer.
            [self pp_fetchAndShowLocalNovaShowcaseForUserText:userText
                                                    completion:^(BOOL didShow) {
                if (!didShow) {
                    if (hasAssistantText) {
                        [self pp_addNovaProductResultTextForRenderedCount:0
                                                             proposedText:fallbackText
                                                                 userText:userText
                                                                   source:@"server_resolution_empty_assistantText_preserved"];
                    } else if ([self pp_novaHasCatalogSearchIntentForUserText:userText]) {
                        [self pp_addNovaProductResultTextForRenderedCount:0
                                                             proposedText:nil
                                                                 userText:userText
                                                                   source:@"server_resolution_empty"];
                    }
                }
            }];
            return;
        }

        // Resolved-IDs telemetry per spec — every server-resolution turn logs
        // received vs. resolved vs. unresolved IDs and the source/type used,
        // plus whether assistantText was shown alongside the cards.
        NSMutableDictionary<NSString *, NSNumber *> *typeCounts = [NSMutableDictionary dictionary];
        for (NSDictionary<NSString *, NSString *> *ref in refs) {
            NSString *typeKey = ref[@"kind"].length > 0 ? ref[@"kind"] : @"product";
            typeCounts[typeKey] = @(typeCounts[typeKey].integerValue + 1);
        }
        LOG_INFO(@"[PPNovaChat][Refs] success received=%lu resolved=%lu unresolved=%lu typeCounts=%@ assistantTextRendered=%@",
                 (unsigned long)refs.count,
                 (unsigned long)objects.count,
                 (unsigned long)((refs.count > objects.count) ? (refs.count - objects.count) : 0),
                 typeCounts,
                 fallbackText.length > 0 ? @"YES" : @"NO");

        [self pp_addNovaProductResultTextForRenderedCount:objects.count
                                             proposedText:fallbackText
                                                 userText:userText
                                                   source:@"server"];
        [self pp_showNovaSuggestionObjects:objects];

        // Save the synthetic product marker to local memory so context is retained
        NSInteger n = (NSInteger)objects.count;
        NSMutableArray *names = [NSMutableArray array];
        for (NSInteger pidx = 0; pidx < MIN(n, 4); pidx++) {
            NSString *name = [self pp_novaDisplayNameForSuggestionObject:objects[pidx]];
            if (name.length > 0) [names addObject:name];
        }
        if (names.count > 0) {
            NSString *marker = [NSString stringWithFormat:@"[Nova showed %ld product%@: %@]",
                                (long)n, n == 1 ? @"" : @"s",
                                [names componentsJoinedByString:@", "]];
            [[PPNovaLocalChatMemory sharedMemory] addMessageWithRole:@"nova" text:marker];
        }
    };

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        finish(YES);
    });

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        finish(NO);
    });
}

- (void)pp_fetchNovaServicesWithIDs:(NSArray<NSString *> *)serviceIDs
                         completion:(void (^)(NSArray<ServiceModel *> *services))completion
{
    if (serviceIDs.count == 0) {
        if (completion) completion(@[]);
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    NSMutableArray<ServiceModel *> *results = [NSMutableArray array];
    dispatch_group_t group = dispatch_group_create();
    for (NSString *serviceID in serviceIDs) {
        if (serviceID.length == 0) {
            continue;
        }
        dispatch_group_enter(group);
        [[[db collectionWithPath:@"serviceOffers"] documentWithPath:serviceID]
         getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable doc, NSError * _Nullable error) {
            if (doc.exists && doc.data) {
                ServiceModel *model = [[ServiceModel alloc] initWithDictionary:doc.data documentID:doc.documentID];
                if (model.isLive) {
                    @synchronized (results) {
                        [results addObject:model];
                    }
                }
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (completion) completion(results.copy);
    });
}

- (void)pp_fetchNovaVetsWithIDs:(NSArray<NSString *> *)vetIDs
                     completion:(void (^)(NSArray<VetModel *> *vets))completion
{
    if (vetIDs.count == 0) {
        if (completion) completion(@[]);
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    NSMutableArray<VetModel *> *results = [NSMutableArray array];
    dispatch_group_t group = dispatch_group_create();
    for (NSString *vetID in vetIDs) {
        if (vetID.length == 0) {
            continue;
        }
        dispatch_group_enter(group);
        [[[db collectionWithPath:@"veterinarians"] documentWithPath:vetID]
         getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable doc, NSError * _Nullable error) {
            if (doc.exists && doc.data) {
                VetModel *model = [VetModel fromDictionary:doc.data withID:doc.documentID];
                if ([self pp_novaVetIsListable:model]) {
                    @synchronized (results) {
                        [results addObject:model];
                    }
                }
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (completion) completion(results.copy);
    });
}

- (BOOL)pp_novaVetIsListable:(VetModel *)vet
{
    if (![vet isKindOfClass:VetModel.class] || vet.isDisabled) {
        return NO;
    }
    NSString *status = [vet.verificationStatus.lowercaseString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (status.length == 0) {
        return YES;
    }
    return [@[@"approved", @"active", @"verified"] containsObject:status];
}

- (NSDictionary<NSString *, PetAccessory *> *)pp_novaAccessoriesByID:(NSArray<PetAccessory *> *)accessories {
    NSMutableDictionary<NSString *, PetAccessory *> *map = [NSMutableDictionary dictionary];
    for (PetAccessory *item in accessories) {
        if (![item isKindOfClass:PetAccessory.class] || item.accessoryID.length == 0) {
            continue;
        }
        map[item.accessoryID] = item;
    }
    return map.copy;
}

- (NSDictionary<NSString *, ServiceModel *> *)pp_novaServicesByID:(NSArray<ServiceModel *> *)services {
    NSMutableDictionary<NSString *, ServiceModel *> *map = [NSMutableDictionary dictionary];
    for (ServiceModel *service in services) {
        if (![service isKindOfClass:ServiceModel.class] || service.serviceID.length == 0) {
            continue;
        }
        map[service.serviceID] = service;
    }
    return map.copy;
}

- (NSDictionary<NSString *, VetModel *> *)pp_novaVetsByID:(NSArray<VetModel *> *)vets {
    NSMutableDictionary<NSString *, VetModel *> *map = [NSMutableDictionary dictionary];
    for (VetModel *vet in vets) {
        if (![vet isKindOfClass:VetModel.class] || vet.vetID.length == 0) {
            continue;
        }
        map[vet.vetID] = vet;
    }
    return map.copy;
}

- (NSDictionary<NSString *, PetAd *> *)pp_novaPetAdsByID:(NSArray<PetAd *> *)ads {
    NSMutableDictionary<NSString *, PetAd *> *map = [NSMutableDictionary dictionary];
    for (PetAd *ad in ads) {
        if (![ad isKindOfClass:PetAd.class] || ad.adID.length == 0) {
            continue;
        }
        map[ad.adID] = ad;
    }
    return map.copy;
}

- (NSDictionary<NSString *, AdoptPetModel *> *)pp_novaAdoptionsByID:(NSArray<AdoptPetModel *> *)pets {
    NSMutableDictionary<NSString *, AdoptPetModel *> *map = [NSMutableDictionary dictionary];
    for (AdoptPetModel *pet in pets) {
        if (![pet isKindOfClass:AdoptPetModel.class] || pet.documentID.length == 0) {
            continue;
        }
        map[pet.documentID] = pet;
    }
    return map.copy;
}

- (void)pp_showNovaSuggestionObjects:(NSArray *)objects {
    [self pp_showNovaSuggestionObjects:objects source:@"server"];
}

- (void)pp_showNovaSuggestionObjects:(NSArray *)objects source:(NSString *)source {
    if (objects.count == 0) {
        return;
    }

    NSArray<PetAccessory *> *cartableProducts = [self pp_cartableNovaProductsFromObjects:objects];
    self.lastShownProducts = cartableProducts;
    if (objects.count == 1 && [objects.firstObject isKindOfClass:PetAccessory.class]) {
        self.lastSuggestedProduct = (PetAccessory *)objects.firstObject;
        self.pendingCartProduct = (PetAccessory *)objects.firstObject;
    } else {
        self.lastSuggestedProduct = nil;
        self.pendingCartProduct = nil;
    }

    ChatMessageModel *msg = [[ChatMessageModel alloc] init];
    msg.ID = [[NSUUID UUID] UUIDString];
    msg.messageType = objects.count > 1 ? ChatMessageTypeNovaProductList : ChatMessageTypeNovaProduct;
    msg.novaProducts = (NSArray<PetAccessory *> *)objects;
    msg.timestamp = [NSDate date];
    msg.senderID = @"nova_bot_id";

    [self.messages addObject:msg];
    [self pp_trimMessageHistoryIfNeeded];
    [self updateNovaEmptyStateAnimated:YES];
    [self animateInsertedRowAtIndexPath:[NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0]];

    LOG_INFO(@"NOVA_RENDERED_CELL_COUNT rendered=%lu source=%@",
             (unsigned long)objects.count,
             source ?: @"unknown");

    [PPAnalytics logNovaShowcaseShownWithItemCount:objects.count
                                          sessionID:self.novaSessionId
                                             source:source];
}

- (void)pp_fetchAndShowLocalNovaShowcaseForUserText:(NSString *)userText
                                         completion:(void (^)(BOOL didShow))completion
{
    [self pp_fetchAndShowLocalNovaShowcaseForUserText:userText
                                            introText:nil
                                           completion:completion];
}

- (void)pp_fetchAndShowLocalNovaShowcaseForUserText:(NSString *)userText
                                          introText:(nullable NSString *)introText
                                        completion:(void (^)(BOOL didShow))completion
{
    NSString *trimmedText = [userText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    [self pp_updateMemoryFromUserText:trimmedText];
    [self pp_logNovaIntentForUserText:trimmedText stage:@"local_search_start"];

    if (![self pp_shouldAttemptLocalNovaShowcaseForUserText:trimmedText] || [self pp_lastMessageIsNovaShowcase]) {
        LOG_INFO(@"NOVA_PRODUCTS_COUNT count=0 source=local reason=not_attempted");
        if (completion) completion(NO);
        return;
    }

    NSString *currentNeed = [self pp_localNovaNeedLabelFromUserText:trimmedText];
    NSString *currentPetType = [self pp_localNovaPetTypeFromUserText:trimmedText];
    NSString *need = currentNeed ?: (currentPetType.length > 0 ? nil : self.novaMemoryNeed);
    BOOL canCarryMemoryPetType = currentNeed.length > 0 || [self pp_novaTextHasShowcaseDisplayIntent:trimmedText];
    NSString *petType = currentPetType ?: (canCarryMemoryPetType ? (self.novaMemoryPetType ?: @"") : @"");
    AccessKindType kind = [self pp_localNovaShowcaseKindForNeed:need petType:petType];
    LOG_INFO(@"NOVA_SEARCH_QUERY raw=%@ normalized=%@ kind=%ld need=%@ petType=%@",
             trimmedText ?: @"",
             [self pp_normalizedNovaIntentText:trimmedText],
             (long)kind,
             need ?: @"",
             petType ?: @"");
    __weak typeof(self) weakSelf = self;
    [[PetAccessoryManager sharedManager] fetchAccessoriesOfKind:kind completion:^(NSArray<PetAccessory *> *accessories) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.dismissed) {
            if (completion) completion(NO);
            return;
        }
        if ([self pp_lastMessageIsNovaShowcase]) {
            if (completion) completion(NO);
            return;
        }

        NSArray<PetAccessory *> *ranked = [self pp_rankedLocalNovaAccessories:accessories
                                                                     userText:trimmedText
                                                                         need:need
                                                                      petType:petType
                                                                        limit:6];
        LOG_INFO(@"NOVA_PRODUCTS_COUNT count=%lu source=local kind=%ld need=%@ petType=%@",
                 (unsigned long)ranked.count,
                 (long)kind,
                 need ?: @"",
                 petType ?: @"");
        if (ranked.count == 0) {
            if (completion) completion(NO);
            return;
        }

        [self pp_addNovaProductResultTextForRenderedCount:ranked.count
                                             proposedText:introText
                                                 userText:trimmedText
                                                   source:@"local"];
        [self pp_showNovaSuggestionObjects:ranked source:@"local"];
        if (completion) completion(YES);
    }];
}

- (NSString *)pp_normalizedNovaIntentText:(NSString *)text {
    NSString *value = (text ?: @"").lowercaseString;
    NSDictionary<NSString *, NSString *> *replacements = @{
        @"إ": @"ا", @"أ": @"ا", @"آ": @"ا",
        @"ى": @"ي", @"ة": @"ه", @"ؤ": @"و", @"ئ": @"ي"
    };
    for (NSString *key in replacements) {
        value = [value stringByReplacingOccurrencesOfString:key withString:replacements[key]];
    }
    NSCharacterSet *punctuation = [NSCharacterSet characterSetWithCharactersInString:@"-_/.,;:!?()[]{}\"'`~|<>،؟؛"];
    NSArray<NSString *> *parts = [value componentsSeparatedByCharactersInSet:punctuation];
    value = [parts componentsJoinedByString:@" "];
    while ([value containsString:@"  "]) {
        value = [value stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    }
    return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (NSArray<NSString *> *)pp_novaShowcaseDisplayAliases {
    return @[
        @"show", @"show me", @"display", @"recommend", @"recommendation", @"recommendations",
        @"suggest", @"suggestion", @"suggestions", @"ads", @"ad",
        @"اعرض", @"عرض", @"وريني", @"ارني", @"رشح", @"رشحلي", @"رشح لي",
        @"اقتراحات", @"اقتراح", @"توصيات", @"اعلانات", @"إعلانات"
    ];
}

- (BOOL)pp_normalizedNovaText:(NSString *)text containsAlias:(NSString *)alias {
    NSString *normalized = [self pp_normalizedNovaIntentText:text];
    NSString *needle = [self pp_normalizedNovaIntentText:alias];
    if (normalized.length == 0 || needle.length == 0) {
        return NO;
    }
    if ([needle containsString:@" "]) {
        return [normalized containsString:needle];
    }
    NSArray<NSString *> *tokens = [normalized componentsSeparatedByString:@" "];
    return [tokens containsObject:needle];
}

- (BOOL)pp_novaTextHasShowcaseDisplayIntent:(NSString *)text {
    for (NSString *alias in [self pp_novaShowcaseDisplayAliases]) {
        if ([self pp_normalizedNovaText:text containsAlias:alias]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)pp_novaIsGenericConversationText:(NSString *)text {
    NSString *normalized = [self pp_normalizedNovaIntentText:text];
    if (normalized.length == 0) {
        return YES;
    }
    NSSet<NSString *> *exact = [NSSet setWithArray:@[
        @"hi", @"hello", @"hey", @"salam", @"ok", @"okay",
        @"thanks", @"thank you", @"how are you", @"nova",
        @"هاي", @"هاى", @"هلا", @"اهلا", @"اهلين", @"مرحبا",
        @"السلام عليكم", @"نوفا", @"نوڤا", @"شكرا", @"تمام", @"اوكي"
    ]];
    if ([exact containsObject:normalized]) {
        return YES;
    }
    NSSet<NSString *> *tokensAllowed = [NSSet setWithArray:@[
        @"hi", @"hello", @"hey", @"ok", @"okay", @"thanks", @"thank", @"you", @"how", @"are",
        @"nova",
        @"هاي", @"هاى", @"هلا", @"اهلا", @"اهلين", @"مرحبا", @"نوفا", @"نوڤا", @"السلام", @"عليكم", @"شكرا", @"تمام", @"اوكي"
    ]];
    NSArray<NSString *> *tokens = [normalized componentsSeparatedByString:@" "];
    if (tokens.count > 0 && tokens.count <= 4) {
        for (NSString *token in tokens) {
            if (![tokensAllowed containsObject:token]) {
                return NO;
            }
        }
        return YES;
    }
    return NO;
}

- (NSString *)pp_novaSearchTextByRemovingDisplayIntent:(NSString *)text {
    NSString *normalized = [self pp_normalizedNovaIntentText:text];
    for (NSString *alias in [self pp_novaShowcaseDisplayAliases]) {
        NSString *needle = [self pp_normalizedNovaIntentText:alias];
        if (needle.length == 0) {
            continue;
        }
        NSString *pattern = [NSString stringWithFormat:@"(^| )%@( ?)", [NSRegularExpression escapedPatternForString:needle]];
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
        normalized = [regex stringByReplacingMatchesInString:normalized
                                                     options:0
                                                       range:NSMakeRange(0, normalized.length)
                                                withTemplate:@" "];
        while ([normalized containsString:@"  "]) {
            normalized = [normalized stringByReplacingOccurrencesOfString:@"  " withString:@" "];
        }
        normalized = [normalized stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    return normalized;
}

- (BOOL)pp_novaHasCatalogSearchIntentForUserText:(NSString *)userText {
    if ([self pp_novaIsGenericConversationText:userText]) {
        return NO;
    }
    NSString *need = [self pp_localNovaNeedLabelFromUserText:userText];
    NSString *petType = [self pp_localNovaPetTypeFromUserText:userText];
    if (need.length > 0 || petType.length > 0 || [self pp_novaTextHasShowcaseDisplayIntent:userText]) {
        return YES;
    }
    return [self pp_novaSearchTextByRemovingDisplayIntent:userText].length > 0;
}

- (BOOL)pp_novaDisplayIntentIsMissingTargetForUserText:(NSString *)userText {
    if (![self pp_novaTextHasShowcaseDisplayIntent:userText]) {
        return NO;
    }
    NSString *need = [self pp_localNovaNeedLabelFromUserText:userText];
    NSString *petType = [self pp_localNovaPetTypeFromUserText:userText];
    NSString *remainingQuery = [self pp_novaSearchTextByRemovingDisplayIntent:userText];
    BOOL hasMemoryTarget = self.novaMemoryNeed.length > 0 || self.novaMemoryPetType.length > 0;
    return need.length == 0 && petType.length == 0 && remainingQuery.length == 0 && !hasMemoryTarget;
}

- (void)pp_logNovaIntentForUserText:(NSString *)userText stage:(NSString *)stage {
    NSString *need = [self pp_localNovaNeedLabelFromUserText:userText] ?: self.novaMemoryNeed ?: @"";
    NSString *petType = [self pp_localNovaPetTypeFromUserText:userText] ?: self.novaMemoryPetType ?: @"";
    BOOL showcaseIntent = [self pp_novaTextHasShowcaseDisplayIntent:userText];
    BOOL displayOnly = [self pp_novaDisplayIntentIsMissingTargetForUserText:userText];
    LOG_INFO(@"NOVA_INTENT stage=%@ showcase=%@ displayOnly=%@ need=%@ petType=%@",
             stage ?: @"",
             showcaseIntent ? @"YES" : @"NO",
             displayOnly ? @"YES" : @"NO",
             need,
             petType);
}

- (BOOL)pp_lastNovaTextMessageEquals:(NSString *)text {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) {
        return NO;
    }
    for (NSInteger i = (NSInteger)self.messages.count - 1; i >= 0; i--) {
        ChatMessageModel *msg = self.messages[i];
        if (![msg.senderID isEqualToString:@"nova_bot_id"]) {
            continue;
        }
        if (msg.messageType != ChatMessageTypeText) {
            return NO;
        }
        return [[msg.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] isEqualToString:trimmed];
    }
    return NO;
}

- (void)pp_addNovaProductResultTextForRenderedCount:(NSUInteger)renderedCount
                                       proposedText:(NSString *)proposedText
                                           userText:(NSString *)userText
                                             source:(NSString *)source {
    NSString *cleanProposed = [proposedText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *decision = @"no_products";
    NSString *textToShow = nil;

    if (renderedCount > 0) {
        if (cleanProposed.length > 0 && ![self pp_novaReplyContainsNoProductClaim:cleanProposed]) {
            textToShow = cleanProposed;
            decision = @"proposed_text_with_rendered_products";
        } else {
            decision = cleanProposed.length == 0 ? @"cards_only_no_ai_text" : @"cards_only_suppressed_no_product_text";
        }
    } else {
        if (cleanProposed.length > 0) {
            textToShow = cleanProposed;
            decision = @"proposed_text_without_products";
        } else {
            decision = @"no_products_no_ai_text";
        }
    }

    LOG_INFO(@"NOVA_PRODUCTS_COUNT count=%lu source=%@",
             (unsigned long)renderedCount,
             source ?: @"unknown");
    LOG_INFO(@"NOVA_RENDERED_CELL_COUNT rendered=%lu source=%@",
             (unsigned long)renderedCount,
             source ?: @"unknown");
    LOG_INFO(@"NOVA_TEXT_DECISION decision=%@ rendered=%lu source=%@ text=%@",
             decision,
             (unsigned long)renderedCount,
             source ?: @"unknown",
             textToShow ?: @"");

    if (textToShow.length > 0 && ![self pp_lastNovaTextMessageEquals:textToShow]) {
        [self addNovaMessage:textToShow];
    }
}

- (BOOL)pp_shouldAttemptLocalNovaShowcaseForUserText:(NSString *)userText {
    NSString *lower = [userText.lowercaseString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (lower.length == 0 || [self pp_novaIsGenericConversationText:lower]) {
        return NO;
    }
    NSString *need = [self pp_localNovaNeedLabelFromUserText:lower];
    NSString *petType = [self pp_localNovaPetTypeFromUserText:lower];
    if ([self pp_localNovaPetTypeIsLivePet:petType]) {
        return YES;
    }
    if (need.length > 0) {
        return petType.length > 0 || self.novaMemoryPetType.length > 0;
    }
    if ([self pp_novaTextHasShowcaseDisplayIntent:lower]) {
        return self.novaMemoryNeed.length > 0 || self.novaMemoryPetType.length > 0;
    }
    return NO;
}

- (AccessKindType)pp_localNovaShowcaseKindForNeed:(NSString *)needLabel petType:(NSString *)petType {
    NSString *need = needLabel.lowercaseString ?: @"";
    if ([need isEqualToString:@"food"]) {
        return AccessTypeFood;
    }
    if ([need isEqualToString:@"medicine"]) {
        return AccessTypePetMedicine;
    }
    if ([self pp_localNovaPetTypeIsLivePet:petType]) {
        return AccessTypeLivePet;
    }
    return AccessTypeAccessory;
}

- (NSArray<PetAccessory *> *)pp_rankedLocalNovaAccessories:(NSArray<PetAccessory *> *)accessories
                                                  userText:(NSString *)userText
                                                      need:(NSString *)need
                                                   petType:(NSString *)petType
                                                     limit:(NSUInteger)limit
{
    // Minimum *semantic* relevance score (need-match, pet-match, or token-match —
    // bare in-stock + has-image bonuses don't count). Off-topic queries score
    // below this and produce an empty result, so we never showcase random items.
    static const NSInteger kMinNovaRelevance = 3;

    NSMutableArray<PetAccessory *> *eligible = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSNumber *> *scoresByID = [NSMutableDictionary dictionary];
    for (PetAccessory *item in accessories) {
        if (![item isKindOfClass:PetAccessory.class] || item.accessoryID.length == 0) {
            continue;
        }
        if (petType.length > 0 && ![self pp_localNovaAccessory:item matchesPetType:petType]) {
            continue;
        }
        NSInteger relevance = [self pp_localNovaAccessoryRelevanceScore:item
                                                                userText:userText
                                                                    need:need
                                                                 petType:petType];
        if (relevance < kMinNovaRelevance) {
            continue;
        }
        scoresByID[item.accessoryID] = @(relevance + [self pp_localNovaAccessoryQualityScore:item]);
        [eligible addObject:item];
    }
    if (eligible.count == 0) {
        return @[];
    }

    NSArray<PetAccessory *> *sorted = [eligible sortedArrayUsingComparator:^NSComparisonResult(PetAccessory *left, PetAccessory *right) {
        NSInteger leftScore = scoresByID[left.accessoryID].integerValue;
        NSInteger rightScore = scoresByID[right.accessoryID].integerValue;
        if (leftScore > rightScore) return NSOrderedAscending;
        if (leftScore < rightScore) return NSOrderedDescending;

        NSDate *leftDate = [left.createdAt isKindOfClass:NSDate.class] ? left.createdAt : NSDate.distantPast;
        NSDate *rightDate = [right.createdAt isKindOfClass:NSDate.class] ? right.createdAt : NSDate.distantPast;
        return [rightDate compare:leftDate];
    }];

    NSUInteger count = MIN(limit, sorted.count);
    return [sorted subarrayWithRange:NSMakeRange(0, count)];
}

// Pure semantic signal — does the item match the user's stated need / pet /
// keywords? Used as the gate for inclusion (bare popularity bonuses don't
// qualify an item).
- (NSInteger)pp_localNovaAccessoryRelevanceScore:(PetAccessory *)item
                                         userText:(NSString *)userText
                                             need:(NSString *)needLabel
                                          petType:(NSString *)petTypeLabel {
    NSString *haystack = [[NSString stringWithFormat:@"%@ %@",
                           item.name ?: @"",
                           item.desc ?: @""] lowercaseString];
    NSString *need = needLabel.lowercaseString ?: @"";
    NSString *petType = petTypeLabel.lowercaseString ?: @"";
    NSInteger score = 0;
    if ([self pp_string:haystack containsAnyNovaKeyword:[self pp_localNovaKeywordsForNeed:need]]) score += 8;
    if ([self pp_string:haystack containsAnyNovaKeyword:[self pp_localNovaKeywordsForPetType:petType]]) score += 5;
    if ([self pp_string:haystack containsAnyNovaKeyword:[self pp_tokenKeywordsFromUserText:userText]]) score += 3;
    return score;
}

// Tie-breaker bonuses — applied only after relevance passes the gate.
- (NSInteger)pp_localNovaAccessoryQualityScore:(PetAccessory *)item {
    NSInteger score = 0;
    if (item.quantity > 0) score += 2;
    if (item.imageURLsArray.count > 0) score += 1;
    return score;
}

- (nullable NSString *)pp_localNovaNeedLabelFromUserText:(NSString *)userText {
    NSString *lower = userText.lowercaseString ?: @"";
    NSArray<NSDictionary<NSString *, id> *> *needKeywords = @[
        @{@"label": @"food", @"keys": @[@"food", @"feed", @"meal", @"kibble", @"treat", @"snack", @"أكل", @"اكل", @"طعام", @"غذاء", @"دراي"]},
        @{@"label": @"medicine", @"keys": @[@"medicine", @"medication", @"vitamin", @"supplement", @"treatment", @"دواء", @"أدوية", @"ادوية", @"فيتامين", @"علاج"]},
        @{@"label": @"cage", @"keys": @[@"cage", @"carrier", @"crate", @"kennel", @"bed", @"aquarium", @"tank", @"قفص", @"حاملة", @"حقيبة", @"حقيبه", @"بيت", @"حوض"]},
        @{@"label": @"toy", @"keys": @[@"toy", @"toys", @"play", @"ball", @"chew", @"لعبة", @"لعبه", @"ألعاب", @"العاب", @"كرة"]},
        @{@"label": @"care", @"keys": @[@"care", @"grooming", @"shampoo", @"brush", @"clean", @"عناية", @"عنايه", @"شامبو", @"تنظيف", @"نظافة"]},
        @{@"label": @"litter", @"keys": @[@"litter", @"sand", @"رمل", @"فضلات", @"ليتر"]}
    ];

    for (NSDictionary<NSString *, id> *entry in needKeywords) {
        NSArray<NSString *> *keys = entry[@"keys"];
        if ([self pp_string:lower containsAnyNovaKeyword:keys]) {
            return entry[@"label"];
        }
    }
    return nil;
}

- (nullable NSString *)pp_localNovaPetTypeFromUserText:(NSString *)userText {
    NSString *lower = userText.lowercaseString ?: @"";
    NSArray<NSDictionary<NSString *, id> *> *petKeywords = @[
        @{@"label": @"cat", @"keys": @[@"cat", @"cats", @"kitten", @"kitty", @"قط", @"قطة", @"قطه", @"قطط", @"بسه", @"بسة"]},
        @{@"label": @"dog", @"keys": @[@"dog", @"dogs", @"puppy", @"pup", @"كلب", @"كلبة", @"كلبه", @"كلاب", @"جرو"]},
        @{@"label": @"bird", @"keys": @[@"bird", @"birds", @"طير", @"طائر", @"طيور", @"عصفور", @"عصافير"]},
        @{@"label": @"parrot", @"keys": @[@"parrot", @"parrots", @"cockatiel", @"cockatoo", @"budgie", @"ببغاء", @"كروان", @"كاسكو"]},
        @{@"label": @"fish", @"keys": @[@"fish", @"fishes", @"aquarium", @"سمك", @"سمكة", @"سمكه", @"أسماك", @"اسماك"]},
        @{@"label": @"rabbit", @"keys": @[@"rabbit", @"rabbits", @"bunny", @"أرنب", @"ارنب", @"أرانب", @"ارانب"]},
        @{@"label": @"hamster", @"keys": @[@"hamster", @"hamsters", @"هامستر", @"هامستار"]},
        @{@"label": @"turtle", @"keys": @[@"turtle", @"turtles", @"tortoise", @"سلحفاة", @"سلحفاه", @"سلاحف"]}
    ];
    for (NSDictionary<NSString *, id> *entry in petKeywords) {
        if ([self pp_string:lower containsAnyNovaKeyword:entry[@"keys"]]) {
            return entry[@"label"];
        }
    }
    return nil;
}

- (BOOL)pp_localNovaPetTypeIsLivePet:(NSString *)petType {
    NSString *value = petType.lowercaseString ?: @"";
    return [@[@"bird", @"parrot", @"fish", @"rabbit", @"hamster", @"turtle"] containsObject:value];
}

- (BOOL)pp_localNovaAccessory:(PetAccessory *)item matchesPetType:(NSString *)petType {
    NSString *value = petType.lowercaseString ?: @"";
    if (value.length == 0) {
        return YES;
    }
    NSString *haystack = [[NSString stringWithFormat:@"%@ %@",
                           item.name ?: @"",
                           item.desc ?: @""] lowercaseString];
    if ([self pp_string:haystack containsAnyNovaKeyword:[self pp_localNovaKeywordsForPetType:value]]) {
        return YES;
    }
    if ([value isEqualToString:@"cat"] && item.petMainCategoryID == 5) return YES;
    if ([value isEqualToString:@"dog"] && item.petMainCategoryID == 6) return YES;
    if (([value isEqualToString:@"bird"] || [value isEqualToString:@"parrot"]) && item.petMainCategoryID == 0) return YES;
    if ([value isEqualToString:@"fish"] && item.petMainCategoryID == 1) return YES;
    if (([value isEqualToString:@"hamster"] || [value isEqualToString:@"rabbit"]) && item.petMainCategoryID == 2) return YES;
    return NO;
}

- (NSArray<NSString *> *)pp_localNovaKeywordsForNeed:(NSString *)need {
    if ([need isEqualToString:@"food"]) return @[@"food", @"kibble", @"treat", @"snack", @"أكل", @"اكل", @"طعام", @"دراي"];
    if ([need isEqualToString:@"medicine"]) return @[@"medicine", @"vitamin", @"supplement", @"treatment", @"دواء", @"فيتامين", @"علاج"];
    if ([need isEqualToString:@"cage"]) return @[@"cage", @"carrier", @"crate", @"bed", @"قفص", @"حقيبة", @"حقيبه", @"بيت"];
    if ([need isEqualToString:@"toy"]) return @[@"toy", @"ball", @"chew", @"لعبة", @"لعبه", @"كرة"];
    if ([need isEqualToString:@"care"]) return @[@"grooming", @"shampoo", @"brush", @"clean", @"شامبو", @"تنظيف", @"عناية", @"عنايه"];
    if ([need isEqualToString:@"litter"]) return @[@"litter", @"sand", @"رمل", @"ليتر"];
    return @[];
}

- (NSArray<NSString *> *)pp_localNovaKeywordsForPetType:(NSString *)petType {
    if ([petType isEqualToString:@"cat"]) return @[@"cat", @"kitten", @"قط", @"قطة", @"قطه", @"قطط"];
    if ([petType isEqualToString:@"dog"]) return @[@"dog", @"puppy", @"كلب", @"كلبة", @"كلبه", @"جرو"];
    if ([petType isEqualToString:@"bird"]) return @[@"bird", @"طير", @"طائر", @"طيور", @"عصفور"];
    if ([petType isEqualToString:@"parrot"]) return @[@"parrot", @"cockatiel", @"budgie", @"ببغاء", @"كروان"];
    if ([petType isEqualToString:@"fish"]) return @[@"fish", @"aquarium", @"سمك", @"سمكة", @"سمكه", @"حوض"];
    if ([petType isEqualToString:@"rabbit"]) return @[@"rabbit", @"bunny", @"أرنب", @"ارنب"];
    if ([petType isEqualToString:@"hamster"]) return @[@"hamster", @"هامستر"];
    if ([petType isEqualToString:@"turtle"]) return @[@"turtle", @"tortoise", @"سلحفاة", @"سلحفاه"];
    return @[];
}

- (NSArray<NSString *> *)pp_tokenKeywordsFromUserText:(NSString *)userText {
    NSArray<NSString *> *parts = [userText.lowercaseString componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableArray<NSString *> *tokens = [NSMutableArray array];
    for (NSString *part in parts) {
        NSString *trimmed = [part stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]];
        if (trimmed.length >= 3) {
            [tokens addObject:trimmed];
        }
    }
    return tokens.copy;
}

- (BOOL)pp_string:(NSString *)text containsAnyNovaKeyword:(NSArray<NSString *> *)keywords {
    if (text.length == 0 || keywords.count == 0) {
        return NO;
    }
    for (NSString *keyword in keywords) {
        NSString *normalized = keyword.lowercaseString;
        if (normalized.length > 0 && [text containsString:normalized]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)pp_lastMessageIsNovaShowcase {
    ChatMessageModel *last = self.messages.lastObject;
    return last.messageType == ChatMessageTypeNovaProduct ||
           last.messageType == ChatMessageTypeNovaProductList;
}

- (NSArray<PetAccessory *> *)pp_cartableNovaProductsFromObjects:(NSArray *)objects {
    NSMutableArray<PetAccessory *> *products = [NSMutableArray array];
    for (id object in objects) {
        if ([object isKindOfClass:PetAccessory.class]) {
            [products addObject:(PetAccessory *)object];
        }
    }
    return products.copy;
}

- (NSString *)pp_novaDisplayNameForSuggestionObject:(id)object {
    if ([object isKindOfClass:PetAccessory.class]) {
        PetAccessory *acc = (PetAccessory *)object;
        NSString *name = acc.name ?: @"";
        NSString *priceStr = acc.price ? [NSString stringWithFormat:@" (%.2f QAR)", [acc.price doubleValue]] : @"";
        return [name stringByAppendingString:priceStr];
    }
    if ([object isKindOfClass:ServiceModel.class]) {
        ServiceModel *srv = (ServiceModel *)object;
        NSString *name = srv.title ?: @"";
        NSString *priceStr = srv.price ? [NSString stringWithFormat:@" (%.2f QAR)", srv.price] : @"";
        return [name stringByAppendingString:priceStr];
    }
    if ([object isKindOfClass:VetModel.class]) {
        VetModel *vet = (VetModel *)object;
        return vet.title ?: @"";
    }
    if ([object isKindOfClass:PetAd.class]) {
        PetAd *ad = (PetAd *)object;
        NSString *name = ad.adTitle ?: @"";
        NSString *priceStr = ad.price ? [NSString stringWithFormat:@" (%.2f QAR)", [ad.price doubleValue]] : @"";
        return [name stringByAppendingString:priceStr];
    }
    if ([object isKindOfClass:AdoptPetModel.class]) {
        AdoptPetModel *pet = (AdoptPetModel *)object;
        return pet.name ?: @"";
    }
    return @"";
}

#pragma mark - Initial Data

- (void)insertNovaGreeting {
    if (self.novaHasShownGreeting) return;

    if ([[PPNovaLocalChatMemory sharedMemory] hasPreviousHistory]) {
        self.novaHasShownGreeting = YES;
        self.novaMemoryLanguage = Language.isRTL ? @"ar" : @"en";
        return;
    }

    NSString *greeting = kLang(@"nova_greeting");

    [self addMessageWithText:greeting isIncoming:YES];

    // The greeting bubble is the only welcome the user should ever see in this session.
    // From now on, the backend is told isFirstAssistantMessage=false so it does not re-greet.
    self.novaHasShownGreeting = YES;
    self.novaMemoryLanguage = Language.isRTL ? @"ar" : @"en";
}

// Templated local-fallback reply was removed in the behavioral refactor: it
// was the source of the "rigid handler text overrides AI" complaint. When the
// model is unreachable or returns nothing, we now stay silent and let the
// product-showcase path speak instead. The Arabic word maps below are still
// used by `pp_buildPreviousUserFactsString` to seed the agent's context.

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

    // Personalization signals — keep optional, never block on missing values.
    NSString *firstName = [PPCurrentUser.FirstName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (firstName.length > 0) {
        ctx[@"firstName"] = firstName;
    }
    NSInteger hour = [[NSCalendar currentCalendar] component:NSCalendarUnitHour fromDate:[NSDate date]];
    if (hour >= 0 && hour < 24) {
        ctx[@"localHour"] = @(hour);
    }

    NSString *facts = [self pp_buildPreviousUserFactsString];
    if (facts.length > 0) {
        ctx[@"previousUserFacts"] = facts;
    }
    return [ctx copy];
}

- (NSDictionary *)pp_currentNovaBrainStateDictionary {
    NSMutableDictionary *state = [NSMutableDictionary dictionary];
    if (self.novaMemoryPetType.length > 0) {
        state[@"animal"] = self.novaMemoryPetType;
    }
    if (self.novaMemoryNeed.length > 0) {
        state[@"category"] = self.novaMemoryNeed;
    }
    if (self.novaMemoryLanguage.length > 0) {
        state[@"user_language"] = self.novaMemoryLanguage;
    }
    NSMutableArray<NSString *> *shownProductIDs = [NSMutableArray array];
    for (PetAccessory *product in self.lastShownProducts) {
        if ([product isKindOfClass:PetAccessory.class] && product.accessoryID.length > 0) {
            [shownProductIDs addObject:product.accessoryID];
        }
    }
    if (shownProductIDs.count > 0) {
        state[@"last_products_shown"] = shownProductIDs.copy;
    }
    return state.copy;
}

- (NSArray *)pp_currentHistoryArray {
    // We used to synthesize history here, but we now rely on PPNovaLocalChatMemory
    // which accurately preserves history across sessions. We return up to 12
    // recent items to give the backend proxy a rich contextual window.

    NSArray *localHistory = [[PPNovaLocalChatMemory sharedMemory] recentHistoryLimit:12];
    NSMutableArray *history = [NSMutableArray array];

    // The geminiProxy.js expects objects in the shape:
    // { "role": "user"|"model", "text": "..." } OR { "role": "user"|"model", "parts": [{ "text": "..." }] }
    // We convert the PPNovaLocalChatMemory dict to match what the proxy currently parses smoothly.

    for (NSDictionary *dict in localHistory) {
        [history addObject:@{
            @"role": dict[@"role"],
            @"parts": @[@{ @"text": dict[@"text"] }]
        }];
    }

    // Do not include the very last user message in the history block since it is
    // passed as the "prompt" argument to the Cloud Function.
    if (history.count > 0) {
        NSDictionary *last = history.lastObject;
        if ([last[@"role"] isEqualToString:@"user"]) {
            [history removeLastObject];
        }
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

    UIView *bottomGlowView = [[UIView alloc] init];
    bottomGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    bottomGlowView.userInteractionEnabled = NO;
    bottomGlowView.layer.cornerRadius = 170.0;
    bottomGlowView.layer.shadowOpacity = 0.22;
    bottomGlowView.layer.shadowRadius = 42.0;
    bottomGlowView.layer.shadowOffset = CGSizeZero;
    bottomGlowView.alpha = 0.0;
    if (@available(iOS 13.0, *)) {
        bottomGlowView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [backgroundView addSubview:bottomGlowView];
    self.novaChatBottomGlowView = bottomGlowView;

    [NSLayoutConstraint activateConstraints:@[
        [backgroundView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [backgroundView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [backgroundView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [backgroundView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [bottomGlowView.widthAnchor constraintEqualToConstant:340.0],
        [bottomGlowView.heightAnchor constraintEqualToConstant:340.0],
        [bottomGlowView.leadingAnchor constraintEqualToAnchor:backgroundView.leadingAnchor constant:-96.0],
        [bottomGlowView.bottomAnchor constraintEqualToAnchor:backgroundView.bottomAnchor constant:128.0]
    ]];

    [self pp_applyNovaSurfaceColors];
}

- (void)pp_applyNovaSurfaceColors {
    UIColor *brand = [self pp_novaHeaderAccentColor];
    UIColor *baseBackground = [self pp_novaHeaderCanvasColor];
    UIColor *surface = [self pp_novaHeaderSurfaceColor];
    UIColor *primaryText = [self pp_novaHeaderPrimaryTextColor];
    UIColor *secondaryText = [self pp_novaHeaderSecondaryTextColor];
    self.ambientBackgroundView.backgroundColor = baseBackground;
    self.novaChatBottomGlowView.backgroundColor = PPNovaDynamicColor([brand colorWithAlphaComponent:0.13],
                                                                     [brand colorWithAlphaComponent:0.22]);
    self.novaChatBottomGlowView.layer.shadowColor = brand.CGColor;
    self.emptyStatePulseView.backgroundColor = [brand colorWithAlphaComponent:0.10];
    [self pp_applyNovaSmartSuggestionColorsWithBrand:brand
                                             surface:surface
                                         primaryText:primaryText
                                       secondaryText:secondaryText];
    if ([self.novaHeaderChromeView isKindOfClass:UIVisualEffectView.class]) {
        ((UIVisualEffectView *)self.novaHeaderChromeView).effect = [UIBlurEffect effectWithStyle:[self pp_novaHeaderGlassBlurStyle]];
    }
    self.novaHeaderChromeView.backgroundColor = PPNovaDynamicColor([surface colorWithAlphaComponent:0.42],
                                                                   [surface colorWithAlphaComponent:0.28]);
    self.novaHeaderChromeView.layer.borderColor = [brand colorWithAlphaComponent:0.16].CGColor;
    self.novaHeaderTopGlowView.backgroundColor = PPNovaDynamicColor([brand colorWithAlphaComponent:0.16],
                                                                    [brand colorWithAlphaComponent:0.26]);
    self.novaHeaderTopGlowView.layer.shadowColor = brand.CGColor;
    self.novaHeaderBottomGlowView.backgroundColor = PPNovaDynamicColor([UIColor.whiteColor colorWithAlphaComponent:0.18],
                                                                       [UIColor.whiteColor colorWithAlphaComponent:0.045]);
    self.novaHeaderSheenView.backgroundColor = PPNovaDynamicColor([brand colorWithAlphaComponent:0.045],
                                                                  [brand colorWithAlphaComponent:0.085]);
    [self pp_installNovaHeaderLiquidBorderIfNeeded];
    UIColor *liquidBorder = PPNovaDynamicColor([brand colorWithAlphaComponent:0.14],
                                               [UIColor.whiteColor colorWithAlphaComponent:0.12]);
    UIColor *liquidHighlight = PPNovaDynamicColor([brand colorWithAlphaComponent:0.42],
                                                  [UIColor.whiteColor colorWithAlphaComponent:0.34]);
    if (@available(iOS 13.0, *)) {
        liquidBorder = [liquidBorder resolvedColorWithTraitCollection:self.traitCollection];
        liquidHighlight = [liquidHighlight resolvedColorWithTraitCollection:self.traitCollection];
    }
    self.novaHeaderLiquidBorderLayer.strokeColor = liquidBorder.CGColor;
    self.novaHeaderLiquidHighlightLayer.strokeColor = liquidHighlight.CGColor;
    self.novaHeaderLiquidHighlightLayer.shadowColor = liquidHighlight.CGColor;
    self.headerHairlineHost.backgroundColor = [secondaryText colorWithAlphaComponent:0.10];
    self.headerBrandHaloView.backgroundColor = PPNovaDynamicColor([AppBackgroundClr colorWithAlphaComponent:0.10],
                                                                  [AppForgroundColr colorWithAlphaComponent:0.18]);
    self.headerBrandHaloView.layer.shadowColor = brand.CGColor;
    self.statusDot.backgroundColor = AppBageColor();
    self.statusDot.layer.shadowColor = brand.CGColor;
    self.headerLiveCapsule.backgroundColor = [brand colorWithAlphaComponent:0.10];
    self.headerLiveCapsule.layer.borderColor = [brand colorWithAlphaComponent:0.18].CGColor;
    self.headerBrandRingView.backgroundColor = [brand colorWithAlphaComponent:0.10];
    self.headerBrandRingView.layer.borderColor = [brand colorWithAlphaComponent:0.24].CGColor;
    self.headerBrandMarkView.backgroundColor = surface;
    self.headerBrandMarkView.layer.borderColor = [brand colorWithAlphaComponent:0.14].CGColor;
    self.headerNameLabel.textColor = primaryText;
    self.headerSubtitleLabel.textColor = [secondaryText colorWithAlphaComponent:0.92];
    self.statusLabel.textColor = [primaryText colorWithAlphaComponent:0.78];
    self.closeButton.backgroundColor = PPNovaDynamicColor([surface colorWithAlphaComponent:0.82],
                                                          [surface colorWithAlphaComponent:0.58]);
    self.closeButton.layer.borderColor = [brand colorWithAlphaComponent:0.08].CGColor;
    self.closeButton.tintColor = [primaryText colorWithAlphaComponent:0.62];

    [self.novaHeaderMotionDots enumerateObjectsUsingBlock:^(UIView *dot, NSUInteger idx, __unused BOOL *stop) {
        dot.backgroundColor = idx % 2 == 0 ? brand : PPNovaDynamicColor([UIColor.whiteColor colorWithAlphaComponent:0.92],
                                                                        [UIColor.whiteColor colorWithAlphaComponent:0.68]);
        dot.layer.shadowColor = brand.CGColor;
    }];
}

- (void)pp_applyNovaSmartSuggestionColorsWithBrand:(UIColor *)brand
                                           surface:(UIColor *)surface
                                       primaryText:(UIColor *)primaryText
                                     secondaryText:(UIColor *)secondaryText {
    if (!self.smartSuggestionSurfaceView) {
        return;
    }

    self.smartSuggestionSurfaceView.effect = [UIBlurEffect effectWithStyle:[self pp_novaHeaderGlassBlurStyle]];
    self.smartSuggestionSurfaceView.backgroundColor = PPNovaDynamicColor([surface colorWithAlphaComponent:0.42],
                                                                         [surface colorWithAlphaComponent:0.30]);
    self.smartSuggestionSurfaceView.layer.borderColor = [brand colorWithAlphaComponent:0.13].CGColor;
    self.smartSuggestionSurfaceView.layer.shadowColor = brand.CGColor;
    self.smartSuggestionTitleLabel.textColor = [secondaryText colorWithAlphaComponent:0.72];

    [self.smartSuggestionButtons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger idx, __unused BOOL *stop) {
        BOOL primary = idx == 0;
        UIColor *fillColor = primary
            ? [brand colorWithAlphaComponent:0.13]
            : PPNovaDynamicColor([surface colorWithAlphaComponent:0.46],
                                 [UIColor.whiteColor colorWithAlphaComponent:0.07]);
        UIColor *strokeColor = primary ? [brand colorWithAlphaComponent:0.18] : [secondaryText colorWithAlphaComponent:0.12];
        UIColor *titleColor = primary ? brand : [primaryText colorWithAlphaComponent:0.84];

        button.backgroundColor = fillColor;
        button.layer.borderColor = strokeColor.CGColor;
        button.tintColor = titleColor;
        [button setTitleColor:titleColor forState:UIControlStateNormal];
        [button setTitleColor:[titleColor colorWithAlphaComponent:0.72] forState:UIControlStateHighlighted];
    }];
}

- (void)pp_startAmbientBackgroundAnimations {
    [self.emptyStatePulseView.layer removeAllAnimations];
    [self.novaChatBottomGlowView.layer removeAllAnimations];
    [self.novaHeaderTopGlowView.layer removeAllAnimations];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.emptyStatePulseView.transform = CGAffineTransformIdentity;
        self.novaChatBottomGlowView.transform = CGAffineTransformIdentity;
        self.novaHeaderTopGlowView.transform = CGAffineTransformIdentity;
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

    // Top halo (just below the header) — slow inhale, gentle vertical drift, soft breath.
    CABasicAnimation *topHaloScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    topHaloScale.fromValue = @0.94;
    topHaloScale.toValue = @1.06;
    topHaloScale.duration = 6.8;
    topHaloScale.autoreverses = YES;
    topHaloScale.repeatCount = HUGE_VALF;
    topHaloScale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.novaHeaderTopGlowView.layer addAnimation:topHaloScale forKey:@"pp_novaHeaderTopHaloScale"];

    CABasicAnimation *topHaloDrift = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    topHaloDrift.fromValue = @(-12.0);
    topHaloDrift.toValue = @(8.0);
    topHaloDrift.duration = 7.6;
    topHaloDrift.autoreverses = YES;
    topHaloDrift.repeatCount = HUGE_VALF;
    topHaloDrift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.novaHeaderTopGlowView.layer addAnimation:topHaloDrift forKey:@"pp_novaHeaderTopHaloDrift"];

    CABasicAnimation *topHaloBreath = [CABasicAnimation animationWithKeyPath:@"opacity"];
    topHaloBreath.fromValue = @0.78;
    topHaloBreath.toValue = @1.0;
    topHaloBreath.duration = 5.4;
    topHaloBreath.autoreverses = YES;
    topHaloBreath.repeatCount = HUGE_VALF;
    topHaloBreath.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.novaHeaderTopGlowView.layer addAnimation:topHaloBreath forKey:@"pp_novaHeaderTopHaloBreath"];

    // Bottom halo (opposite corner) — counter-phase scale, drift, breath.
    CABasicAnimation *bottomGlowScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    bottomGlowScale.fromValue = @0.965;
    bottomGlowScale.toValue = @1.045;
    bottomGlowScale.duration = 7.4;
    bottomGlowScale.autoreverses = YES;
    bottomGlowScale.repeatCount = HUGE_VALF;
    bottomGlowScale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.novaChatBottomGlowView.layer addAnimation:bottomGlowScale forKey:@"pp_novaBottomGlowScale"];

    CABasicAnimation *bottomGlowDrift = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    bottomGlowDrift.fromValue = @(10.0);
    bottomGlowDrift.toValue = @(-14.0);
    bottomGlowDrift.duration = 8.2;
    bottomGlowDrift.autoreverses = YES;
    bottomGlowDrift.repeatCount = HUGE_VALF;
    bottomGlowDrift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.novaChatBottomGlowView.layer addAnimation:bottomGlowDrift forKey:@"pp_novaBottomGlowDrift"];

    CABasicAnimation *bottomGlowBreath = [CABasicAnimation animationWithKeyPath:@"opacity"];
    bottomGlowBreath.fromValue = @1.0;
    bottomGlowBreath.toValue = @0.74;
    bottomGlowBreath.duration = 6.2;
    bottomGlowBreath.autoreverses = YES;
    bottomGlowBreath.repeatCount = HUGE_VALF;
    bottomGlowBreath.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.novaChatBottomGlowView.layer addAnimation:bottomGlowBreath forKey:@"pp_novaBottomGlowBreath"];
}

- (void)pp_stopAmbientBackgroundAnimations {
    [self.emptyStatePulseView.layer removeAllAnimations];
    [self.novaChatBottomGlowView.layer removeAllAnimations];
    [self.novaHeaderTopGlowView.layer removeAllAnimations];
}

- (UIColor *)pp_novaHeaderAccentColor {
    return AppPrimaryClr ?: UIColor.systemTealColor;
}

- (UIColor *)pp_novaHeaderCanvasColor {
    return AppBackgroundClr ?: UIColor.secondarySystemBackgroundColor;
}

- (UIColor *)pp_novaHeaderSurfaceColor {
    return AppForgroundColr ?: UIColor.systemBackgroundColor;
}

- (UIBlurEffectStyle)pp_novaHeaderGlassBlurStyle {
    if (@available(iOS 13.0, *)) {
        return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
            ? UIBlurEffectStyleSystemThinMaterialDark
            : UIBlurEffectStyleSystemUltraThinMaterialLight;
    }
    return UIBlurEffectStyleExtraLight;
}

- (UIColor *)pp_novaHeaderPrimaryTextColor {
    return AppPrimaryTextClr ?: UIColor.labelColor;
}

- (UIColor *)pp_novaHeaderSecondaryTextColor {
    return AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
}

- (CGFloat)pp_novaHeaderBackgroundAlphaForCurrentState {
    return self.novaHeaderCollapsed ? 0.35 : 0.65;
}

- (CGFloat)pp_novaHeaderSheenAlphaForCurrentState {
    return self.novaHeaderCollapsed ? 0.42 : 0.72;
}

- (void)pp_loadNovaIdentityAnimationIntoView:(LOTAnimationView *)animationView {
    if (!animationView) {
        return;
    }

    NSArray<NSDictionary<NSString *, NSString *> *> *localCandidates = @[
        @{@"name": @"Ncolored", @"type": @"json"}
    ];
    for (NSDictionary<NSString *, NSString *> *candidate in localCandidates) {
        NSString *path = [[NSBundle mainBundle] pathForResource:candidate[@"name"] ofType:candidate[@"type"]];
        if (path.length == 0) {
            continue;
        }

        NSData *data = [NSData dataWithContentsOfFile:path];
        if (data.length == 0) {
            continue;
        }

        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
        LOTComposition *composition = [json isKindOfClass:NSDictionary.class] ? [LOTComposition animationFromJSON:json] : nil;
        if (composition) {
            animationView.animationSpeed = 0.86;
            [animationView setSceneModel:composition];
            [self pp_revealNovaIdentityAnimationView:animationView];
            return;
        }
    }

    NSArray<NSString *> *paths = @[
        @"LottieAnimations/Ncolored.json"
    ];
    [self pp_loadNovaIdentityAnimationPaths:paths index:0 intoView:animationView];
}

- (void)pp_loadNovaIdentityAnimationPaths:(NSArray<NSString *> *)paths
                                    index:(NSUInteger)index
                                 intoView:(LOTAnimationView *)animationView
{
    if (!animationView) {
        return;
    }

    if (index >= paths.count) {
        __weak typeof(self) weakSelf = self;
        __weak LOTAnimationView *weakAnimationView = animationView;
        [AppClasses setAnimationNamed:@"nova-ring-bg"
                               ToView:animationView
                            withSpeed:0.86
                           completion:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                LOTAnimationView *strongAnimationView = weakAnimationView;
                if (!self || self.dismissed || !strongAnimationView || !success) {
                    return;
                }
                [self pp_revealNovaIdentityAnimationView:strongAnimationView];
            });
        }];
        return;
    }

    NSString *path = paths[index];
    __weak typeof(self) weakSelf = self;
    __weak LOTAnimationView *weakAnimationView = animationView;
    [AppClasses fetchLottieJSONFromFirebasePath:path completion:^(NSDictionary *jsonDict, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            LOTAnimationView *strongAnimationView = weakAnimationView;
            if (!self || self.dismissed || !strongAnimationView) {
                return;
            }

            if (error || ![jsonDict isKindOfClass:NSDictionary.class]) {
                [self pp_loadNovaIdentityAnimationPaths:paths index:index + 1 intoView:strongAnimationView];
                return;
            }

            LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
            if (!composition) {
                [self pp_loadNovaIdentityAnimationPaths:paths index:index + 1 intoView:strongAnimationView];
                return;
            }

            strongAnimationView.animationSpeed = 0.86;
            [strongAnimationView setSceneModel:composition];
            [self pp_revealNovaIdentityAnimationView:strongAnimationView];
        });
    }];
}

- (void)pp_revealNovaIdentityAnimationView:(LOTAnimationView *)animationView {
    if (!animationView) {
        return;
    }

    if (UIAccessibilityIsReduceMotionEnabled()) {
        [animationView stop];
        animationView.alpha = 1.0;
        return;
    }

    [animationView play];
    [UIView animateWithDuration:0.44
                          delay:0.08
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        animationView.alpha = 1.0;
        animationView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)setupNovaHeader {
    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.backgroundColor = UIColor.clearColor;
    header.clipsToBounds = NO;
    header.layer.shadowColor = UIColor.blackColor.CGColor;
    header.layer.shadowOpacity = 0.07;
    header.layer.shadowRadius = 30.0;
    header.layer.shadowOffset = CGSizeMake(0.0, 18.0);
    [self.view addSubview:header];
    self.novaHeaderView = header;

    UIVisualEffectView *chromeView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:[self pp_novaHeaderGlassBlurStyle]]];
    chromeView.translatesAutoresizingMaskIntoConstraints = NO;
    chromeView.clipsToBounds = YES;
    chromeView.backgroundColor = [[self pp_novaHeaderSurfaceColor] colorWithAlphaComponent:0.50];
    chromeView.layer.cornerRadius = 32.0;
    chromeView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    chromeView.layer.borderColor = [[self pp_novaHeaderAccentColor] colorWithAlphaComponent:0.12].CGColor;
    chromeView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    chromeView.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    if (@available(iOS 13.0, *)) {
        chromeView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [header addSubview:chromeView];
    self.novaHeaderChromeView = chromeView;

    UIView *contentView = chromeView.contentView;
    contentView.clipsToBounds = YES;

    [NSLayoutConstraint activateConstraints:@[
        [chromeView.topAnchor constraintEqualToAnchor:header.topAnchor constant:14.0],
        [chromeView.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16.0],
        [chromeView.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16.0],
        [chromeView.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-8.0]
    ]];

    UIView *topGlowView = [[UIView alloc] init];
    topGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    topGlowView.userInteractionEnabled = NO;
    topGlowView.backgroundColor = [[self pp_novaHeaderAccentColor] colorWithAlphaComponent:0.16];
    topGlowView.layer.cornerRadius = 150.0;
    topGlowView.layer.shadowColor = [self pp_novaHeaderAccentColor].CGColor;
    topGlowView.layer.shadowOpacity = 0.22;
    topGlowView.layer.shadowRadius = 36.0;
    topGlowView.layer.shadowOffset = CGSizeZero;
    topGlowView.alpha = 0.0;
    if (@available(iOS 13.0, *)) {
        topGlowView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.ambientBackgroundView addSubview:topGlowView];
    self.novaHeaderTopGlowView = topGlowView;

    UIView *bottomGlowView = [[UIView alloc] init];
    bottomGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    bottomGlowView.userInteractionEnabled = NO;
    bottomGlowView.backgroundColor = PPNovaDynamicColor([UIColor.whiteColor colorWithAlphaComponent:0.28],
                                                       [UIColor.whiteColor colorWithAlphaComponent:0.05]);
    bottomGlowView.layer.cornerRadius = 76.0;
    bottomGlowView.layer.shadowColor = UIColor.whiteColor.CGColor;
    bottomGlowView.layer.shadowOpacity = 0.12;
    bottomGlowView.layer.shadowRadius = 18.0;
    bottomGlowView.layer.shadowOffset = CGSizeZero;
    if (@available(iOS 13.0, *)) {
        bottomGlowView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [contentView addSubview:bottomGlowView];
    self.novaHeaderBottomGlowView = bottomGlowView;

    LOTAnimationView *backgroundLottie = [LOTAnimationView new];
    backgroundLottie.translatesAutoresizingMaskIntoConstraints = NO;
    backgroundLottie.userInteractionEnabled = NO;
    backgroundLottie.contentMode = UIViewContentModeScaleAspectFill;
    backgroundLottie.loopAnimation = YES;
    backgroundLottie.animationSpeed = 0.92;
    backgroundLottie.alpha = 0.0;
    [contentView addSubview:backgroundLottie];
    self.novaHeaderBackgroundLottie = backgroundLottie;
    //self.currentHeaderBgAnimationName = @"novawave";

    [NSLayoutConstraint activateConstraints:@[
        [topGlowView.widthAnchor constraintEqualToConstant:300.0],
        [topGlowView.heightAnchor constraintEqualToConstant:300.0],
        [topGlowView.centerYAnchor constraintEqualToAnchor:header.bottomAnchor constant:-32.0],
        [topGlowView.centerXAnchor constraintEqualToAnchor:header.centerXAnchor constant:104.0],

        [bottomGlowView.widthAnchor constraintEqualToConstant:152.0],
        [bottomGlowView.heightAnchor constraintEqualToConstant:152.0],
        [bottomGlowView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:46.0],
        [bottomGlowView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:18.0],

        [backgroundLottie.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [backgroundLottie.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [backgroundLottie.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [backgroundLottie.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor]
    ]];

    UIView *sheenView = [[UIView alloc] init];
    sheenView.translatesAutoresizingMaskIntoConstraints = NO;
    sheenView.userInteractionEnabled = NO;
    sheenView.alpha = [self pp_novaHeaderSheenAlphaForCurrentState];
    sheenView.backgroundColor = [[self pp_novaHeaderAccentColor] colorWithAlphaComponent:0.045];
    sheenView.layer.cornerRadius = 56.0;
    if (@available(iOS 13.0, *)) {
        sheenView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [contentView addSubview:sheenView];
    self.novaHeaderSheenView = sheenView;

    [NSLayoutConstraint activateConstraints:@[
        [sheenView.widthAnchor constraintEqualToConstant:112.0],
        [sheenView.heightAnchor constraintEqualToConstant:112.0],
        [sheenView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:-28.0],
        [sheenView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:28.0]
    ]];

    NSArray<NSDictionary<NSString *, NSNumber *> *> *dotSpecs = @[
        @{@"x": @22.0,  @"y": @20.0, @"s": @5.0},
        @{@"x": @70.0,  @"y": @72.0, @"s": @4.0},
        @{@"x": @126.0, @"y": @34.0, @"s": @5.0},
        @{@"x": @202.0, @"y": @112.0, @"s": @4.0},
        @{@"x": @248.0, @"y": @62.0, @"s": @5.0}
    ];
    NSMutableArray<UIView *> *motionDots = [NSMutableArray arrayWithCapacity:dotSpecs.count];
    for (NSDictionary<NSString *, NSNumber *> *spec in dotSpecs) {
        UIView *dot = [[UIView alloc] init];
        dot.translatesAutoresizingMaskIntoConstraints = NO;
        dot.userInteractionEnabled = NO;
        dot.alpha = 0.22;
        CGFloat size = spec[@"s"].doubleValue;
        dot.layer.cornerRadius = size / 2.0;
        dot.layer.shadowOpacity = 0.10;
        dot.layer.shadowRadius = 5.0;
        dot.layer.shadowOffset = CGSizeZero;
        [contentView addSubview:dot];
        [NSLayoutConstraint activateConstraints:@[
            [dot.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:spec[@"x"].doubleValue],
            [dot.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:spec[@"y"].doubleValue],
            [dot.widthAnchor constraintEqualToConstant:size],
            [dot.heightAnchor constraintEqualToConstant:size]
        ]];
        [motionDots addObject:dot];
    }
    self.novaHeaderMotionDots = motionDots.copy;

    UIColor *accentColor = [self pp_novaHeaderAccentColor];

    UIView *brandHalo = [[UIView alloc] init];
    brandHalo.translatesAutoresizingMaskIntoConstraints = NO;
    brandHalo.userInteractionEnabled = NO;
    brandHalo.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.10];
    brandHalo.layer.cornerRadius = 42.0;
    brandHalo.layer.shadowColor = accentColor.CGColor;
    brandHalo.layer.shadowOpacity = 0.16;
    brandHalo.layer.shadowRadius = 18.0;
    brandHalo.layer.shadowOffset = CGSizeZero;
    if (@available(iOS 13.0, *)) {
        brandHalo.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [contentView addSubview:brandHalo];
    self.headerBrandHaloView = brandHalo;

    LOTAnimationView *loadingLottie = [LOTAnimationView animationNamed:@"nova_loading"];
    loadingLottie.translatesAutoresizingMaskIntoConstraints = NO;
    loadingLottie.userInteractionEnabled = NO;
    loadingLottie.contentMode = UIViewContentModeScaleAspectFit;
    loadingLottie.loopAnimation = YES;
    loadingLottie.animationSpeed = 1.0;
    loadingLottie.alpha = 0.0;
    [brandHalo addSubview:loadingLottie];
    self.novaLoadingLottie = loadingLottie;

    UIView *brandRing = [[UIView alloc] init];
    brandRing.translatesAutoresizingMaskIntoConstraints = NO;
    brandRing.backgroundColor = [accentColor colorWithAlphaComponent:0.10];
    brandRing.layer.cornerRadius = 34.0;
    brandRing.layer.borderWidth = 1.2 / UIScreen.mainScreen.scale;
    brandRing.layer.borderColor = [accentColor colorWithAlphaComponent:0.24].CGColor;
    brandRing.layer.shadowColor = UIColor.blackColor.CGColor;
    brandRing.layer.shadowOpacity = 0.07;
    brandRing.layer.shadowRadius = 17.0;
    brandRing.layer.shadowOffset = CGSizeMake(0.0, 9.0);
    if (@available(iOS 13.0, *)) {
        brandRing.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [contentView addSubview:brandRing];
    self.headerBrandRingView = brandRing;

    UIView *brandMark = [[UIView alloc] init];
    brandMark.translatesAutoresizingMaskIntoConstraints = NO;
    brandMark.backgroundColor = AppClearClr;
    brandMark.layer.cornerRadius = 22.0;
    brandMark.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    brandMark.layer.borderColor = [accentColor colorWithAlphaComponent:0.14].CGColor;
    brandMark.layer.shadowColor = UIColor.blackColor.CGColor;
    brandMark.layer.shadowOpacity = 0.08;
    brandMark.layer.shadowRadius = 12.0;
    brandMark.layer.shadowOffset = CGSizeMake(0.0, 7.0);
    if (@available(iOS 13.0, *)) {
        brandMark.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [contentView addSubview:brandMark];
    self.headerBrandMarkView = brandMark;

    LOTAnimationView *identityLottie = [[LOTAnimationView alloc] init];
    identityLottie.translatesAutoresizingMaskIntoConstraints = NO;
    identityLottie.userInteractionEnabled = NO;
    identityLottie.contentMode = UIViewContentModeScaleAspectFit;
    identityLottie.loopAnimation = YES;
    identityLottie.animationSpeed = 0.86;
    identityLottie.alpha = 0.0;
    identityLottie.transform = CGAffineTransformMakeScale(0.94, 0.94);
    identityLottie.clipsToBounds = YES;
    [brandMark addSubview:identityLottie];
    self.novaRingBackgroundLottie = identityLottie;
    [self pp_loadNovaIdentityAnimationIntoView:identityLottie];

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.font = [GM boldFontWithSize:PPFontTitle1] ?: [UIFont systemFontOfSize:28.0 weight:UIFontWeightBold];
    nameLabel.textColor = UIColor.whiteColor;
    nameLabel.text = kLang(@"nova_title");
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.adjustsFontSizeToFitWidth = YES;
    nameLabel.minimumScaleFactor = 0.82;
    if (!Language.isRTL) {
        // Subtle premium tracking on the wordmark.
        NSAttributedString *attr = [[NSAttributedString alloc]
                                    initWithString:nameLabel.text
                                    attributes:@{ NSKernAttributeName: @1.4 }];
        nameLabel.attributedText = attr;
    }
    [contentView addSubview:nameLabel];
    self.headerNameLabel = nameLabel;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:PPFontCaption1 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.82]; // Off-white
    subtitleLabel.text = kLang(@"nova_subtitle");
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.adjustsFontSizeToFitWidth = YES;
    subtitleLabel.minimumScaleFactor = 0.86;
    [contentView addSubview:subtitleLabel];
    self.headerSubtitleLabel = subtitleLabel;

    UIView *liveCapsule = [[UIView alloc] init];
    liveCapsule.translatesAutoresizingMaskIntoConstraints = NO;
    liveCapsule.backgroundColor = [accentColor colorWithAlphaComponent:0.10];
    liveCapsule.layer.cornerRadius = 13.0;
    liveCapsule.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        liveCapsule.layer.cornerCurve = kCACornerCurveContinuous;
    }
    liveCapsule.layer.borderWidth = 0.5 / UIScreen.mainScreen.scale;
    liveCapsule.layer.borderColor = [[UIColor separatorColor] colorWithAlphaComponent:0.55].CGColor;
    [contentView addSubview:liveCapsule];
    self.headerLiveCapsule = liveCapsule;

    UIView *liveContent = liveCapsule;

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

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:14.0
                                                                                          weight:UIImageSymbolWeightSemibold];
        UIImage *xmark = [UIImage systemImageNamed:@"xmark" withConfiguration:cfg];
        [closeButton setImage:xmark forState:UIControlStateNormal];
    } else {
        [closeButton setTitle:@"✕" forState:UIControlStateNormal];
    }
    closeButton.tintColor = [AppPrimaryTextClr colorWithAlphaComponent:0.62];
    closeButton.layer.cornerRadius = 18.0;
    closeButton.layer.borderWidth = 0.5 / UIScreen.mainScreen.scale;
    closeButton.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.18].CGColor;
    closeButton.layer.shadowColor = UIColor.blackColor.CGColor;
    closeButton.layer.shadowOpacity = 0.035;
    closeButton.layer.shadowRadius = 10.0;
    closeButton.layer.shadowOffset = CGSizeMake(0.0, 5.0);
    if (@available(iOS 13.0, *)) {
        closeButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    closeButton.accessibilityLabel = kLang(@"nova_close_accessibility");
    closeButton.accessibilityTraits = UIAccessibilityTraitButton;
    [closeButton addTarget:self
                    action:@selector(pp_handleNovaHeaderControlPressDown:)
          forControlEvents:UIControlEventTouchDown];
    [closeButton addTarget:self
                    action:@selector(pp_handleNovaHeaderControlPressUp:)
          forControlEvents:UIControlEventTouchCancel | UIControlEventTouchDragExit | UIControlEventTouchUpOutside];
    [closeButton addTarget:self
                    action:@selector(pp_handleNovaCloseTapped:)
          forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:closeButton];
    self.closeButton = closeButton;

    UIView *hairlineHost = [[UIView alloc] init];
    hairlineHost.translatesAutoresizingMaskIntoConstraints = NO;
    hairlineHost.userInteractionEnabled = NO;
    hairlineHost.backgroundColor = [UIColor.separatorColor colorWithAlphaComponent:0.28];
    [contentView addSubview:hairlineHost];
    self.headerHairlineHost = hairlineHost;

    header.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", nameLabel.text, statusLabel.text];

    CGFloat topOffset = 20.0; // Sheet grabber clearance inside the Pro-login style host.

    // Expanded bottom constraint (online status capsule)
    self.novaHeaderExpandedBottomConstraint = [liveCapsule.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-14.0];

    // Collapsed bottom constraint (avatar ring)
    self.novaHeaderCollapsedBottomConstraint = [brandRing.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-12.0];
    self.novaHeaderCollapsedBottomConstraint.active = NO;

    // Brand Ring (Avatar) Constraints
    self.brandRingCenterXConstraint = [brandRing.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor];
    self.brandRingLeadingConstraint = [brandRing.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16.0];

    // Name Label (Title) Constraints
    self.nameLabelCenterXConstraint = [nameLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor];
    self.nameLabelLeadingConstraint = [nameLabel.leadingAnchor constraintEqualToAnchor:brandRing.trailingAnchor constant:14.0];
    self.nameLabelTopConstraint = [nameLabel.topAnchor constraintEqualToAnchor:brandRing.bottomAnchor constant:3.0]; // Moved up (8.0 -> 3.0)
    self.nameLabelCenterYConstraint = [nameLabel.centerYAnchor constraintEqualToAnchor:brandRing.centerYAnchor constant:-5.0]; // Requested offset

    // Subtitle Label Constraints
    self.subtitleLabelCenterXConstraint = [subtitleLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor];
    self.subtitleLabelLeadingConstraint = [subtitleLabel.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor];
    self.subtitleLabelTopConstraint = [subtitleLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:2.0];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [brandHalo.centerXAnchor constraintEqualToAnchor:brandRing.centerXAnchor],
        [brandHalo.centerYAnchor constraintEqualToAnchor:brandRing.centerYAnchor],
        [brandHalo.widthAnchor constraintEqualToConstant:60.0],
        [brandHalo.heightAnchor constraintEqualToConstant:60.0],

        [loadingLottie.centerXAnchor constraintEqualToAnchor:brandHalo.centerXAnchor],
        [loadingLottie.centerYAnchor constraintEqualToAnchor:brandHalo.centerYAnchor],
        [loadingLottie.widthAnchor constraintEqualToAnchor:brandHalo.widthAnchor constant:0.0],
        [loadingLottie.heightAnchor constraintEqualToAnchor:brandHalo.heightAnchor constant:0.0],

        [brandRing.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:topOffset],
        self.brandRingCenterXConstraint,
        [brandRing.widthAnchor constraintEqualToConstant:58.0],
        [brandRing.heightAnchor constraintEqualToConstant:58.0],

        [brandMark.centerXAnchor constraintEqualToAnchor:brandRing.centerXAnchor],
        [brandMark.centerYAnchor constraintEqualToAnchor:brandRing.centerYAnchor],
        [brandMark.widthAnchor constraintEqualToConstant:62.0],
        [brandMark.heightAnchor constraintEqualToConstant:62.0],

        [identityLottie.topAnchor constraintEqualToAnchor:brandMark.topAnchor constant:10.0],
        [identityLottie.leadingAnchor constraintEqualToAnchor:brandMark.leadingAnchor constant:10.0],
        [identityLottie.trailingAnchor constraintEqualToAnchor:brandMark.trailingAnchor constant:-10.0],
        [identityLottie.bottomAnchor constraintEqualToAnchor:brandMark.bottomAnchor constant:-10.0],

        self.nameLabelCenterXConstraint,
        self.nameLabelTopConstraint,
        [nameLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:contentView.leadingAnchor constant:16.0],
        [nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:closeButton.leadingAnchor constant:-12.0],

        self.subtitleLabelCenterXConstraint,
        self.subtitleLabelTopConstraint,
        [subtitleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:contentView.leadingAnchor constant:16.0],
        [subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:closeButton.leadingAnchor constant:-12.0],

        [liveCapsule.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:8.0],
        [liveCapsule.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [liveCapsule.heightAnchor constraintEqualToConstant:26.0],
        self.novaHeaderExpandedBottomConstraint,

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
        [hairlineHost.heightAnchor constraintEqualToConstant:1.0],

        // Close button: top-trailing of header, auto-flips for RTL via semantic attribute.
        [closeButton.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:topOffset],
        [closeButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-12.0],
        [closeButton.widthAnchor constraintEqualToConstant:36.0],
        [closeButton.heightAnchor constraintEqualToConstant:36.0]
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_handleNovaHeaderTap:)];
    tap.cancelsTouchesInView = NO;
    [header addGestureRecognizer:tap];

    [self pp_applyNovaSurfaceColors];
}

- (CALayer *)pp_novaHeaderLiquidBorderHostLayer {
    if ([self.novaHeaderChromeView isKindOfClass:UIVisualEffectView.class]) {
        return ((UIVisualEffectView *)self.novaHeaderChromeView).contentView.layer;
    }
    return self.novaHeaderChromeView.layer;
}

- (void)pp_installNovaHeaderLiquidBorderIfNeeded {
    if (!self.novaHeaderChromeView || self.novaHeaderLiquidBorderLayer) {
        return;
    }

    CALayer *host = [self pp_novaHeaderLiquidBorderHostLayer];

    CAShapeLayer *borderLayer = [CAShapeLayer layer];
    borderLayer.fillColor = UIColor.clearColor.CGColor;
    borderLayer.lineCap = kCALineCapRound;
    borderLayer.lineJoin = kCALineJoinRound;
    borderLayer.lineWidth = 1.0 / UIScreen.mainScreen.scale;
    borderLayer.opacity = 0.72;
    borderLayer.zPosition = 60.0;
    [host addSublayer:borderLayer];
    self.novaHeaderLiquidBorderLayer = borderLayer;

    CAShapeLayer *highlightLayer = [CAShapeLayer layer];
    highlightLayer.fillColor = UIColor.clearColor.CGColor;
    highlightLayer.lineCap = kCALineCapRound;
    highlightLayer.lineJoin = kCALineJoinRound;
    highlightLayer.lineWidth = 1.55 / UIScreen.mainScreen.scale;
    highlightLayer.opacity = 0.36;
    highlightLayer.shadowOpacity = 0.32;
    highlightLayer.shadowRadius = 6.0;
    highlightLayer.shadowOffset = CGSizeZero;
    highlightLayer.zPosition = 61.0;
    [host addSublayer:highlightLayer];
    self.novaHeaderLiquidHighlightLayer = highlightLayer;

    [self pp_updateNovaHeaderLiquidBorderPath];
}

- (void)pp_updateNovaHeaderLiquidBorderPath {
    if (!self.novaHeaderChromeView || !self.novaHeaderLiquidBorderLayer || !self.novaHeaderLiquidHighlightLayer) {
        return;
    }

    CGRect bounds = self.novaHeaderChromeView.bounds;
    if (CGRectIsEmpty(bounds)) {
        return;
    }

    CGFloat scale = UIScreen.mainScreen.scale;
    CGFloat inset = MAX(1.0 / scale, 0.5);
    CGRect pathRect = CGRectInset(bounds, inset, inset);
    CGFloat radius = MIN(32.0, MAX(18.0, CGRectGetHeight(pathRect) * 0.24));
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:pathRect cornerRadius:radius];
    CGFloat perimeter = MAX(1.0, ((CGRectGetWidth(pathRect) + CGRectGetHeight(pathRect)) * 2.0) - (8.0 * radius) + ((CGFloat)M_PI * 2.0 * radius));
    CGFloat dashLength = MAX(44.0, MIN(86.0, perimeter * 0.13));
    CGFloat gapLength = MAX(120.0, perimeter - dashLength);

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.novaHeaderLiquidBorderLayer.frame = bounds;
    self.novaHeaderLiquidHighlightLayer.frame = bounds;
    self.novaHeaderLiquidBorderLayer.path = path.CGPath;
    self.novaHeaderLiquidHighlightLayer.path = path.CGPath;
    self.novaHeaderLiquidHighlightLayer.shadowPath = path.CGPath;
    self.novaHeaderLiquidHighlightLayer.lineDashPattern = @[@(dashLength), @(gapLength)];
    [CATransaction commit];
}

- (void)pp_handleNovaHeaderTap:(UITapGestureRecognizer *)tap {
    CGPoint point = [tap locationInView:self.closeButton];
    if (!self.closeButton.hidden && CGRectContainsPoint(self.closeButton.bounds, point)) {
        return;
    }
    if (self.novaHeaderCollapsed) {
        [self pp_setNovaHeaderCollapsed:NO animated:YES];
    }
}

- (void)pp_setNovaHeaderCollapsed:(BOOL)collapsed animated:(BOOL)animated {
    if (!self.novaHeaderView || self.novaHeaderCollapsed == collapsed) {
        return;
    }

    self.novaHeaderCollapsed = collapsed;
    self.novaHeaderExpandedBottomConstraint.active = !collapsed;
    self.novaHeaderCollapsedBottomConstraint.active = collapsed;

    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    NSTimeInterval duration = (animated && !reduceMotion) ? (collapsed ? 0.32 : 0.46) : 0.0;
    CGFloat textAlpha = collapsed ? 0.0 : 1.0;
    CGFloat capsuleAlpha = collapsed ? 0.0 : 1.0;
    CGAffineTransform textTransform = collapsed ? CGAffineTransformMakeTranslation(0.0, -8.0) : CGAffineTransformIdentity;
    CGAffineTransform ringTransform = collapsed ? CGAffineTransformMakeScale(0.94, 0.94) : CGAffineTransformIdentity;
    CGAffineTransform haloTransform = collapsed ? CGAffineTransformMakeScale(0.78, 0.78) : CGAffineTransformIdentity;
    CGAffineTransform glowTransform = collapsed ? CGAffineTransformMakeTranslation(0.0, -10.0) : CGAffineTransformIdentity;

    void (^changes)(void) = ^{
        self.headerNameLabel.alpha = 1.0;
        self.headerSubtitleLabel.alpha = 1.0;
        self.headerLiveCapsule.alpha = capsuleAlpha;

        // Toggle Layout Constraints
        self.brandRingCenterXConstraint.active = !collapsed;
        self.brandRingLeadingConstraint.active = collapsed;

        self.nameLabelCenterXConstraint.active = !collapsed;
        self.nameLabelLeadingConstraint.active = collapsed;

        self.nameLabelTopConstraint.active = !collapsed;
        self.nameLabelCenterYConstraint.active = collapsed;

        self.subtitleLabelCenterXConstraint.active = !collapsed;
        self.subtitleLabelLeadingConstraint.active = collapsed;

        // Update Alignment
        self.headerNameLabel.textAlignment = collapsed ? NSTextAlignmentNatural : NSTextAlignmentCenter;
        self.headerSubtitleLabel.textAlignment = collapsed ? NSTextAlignmentNatural : NSTextAlignmentCenter;

        self.headerNameLabel.transform = collapsed ? CGAffineTransformIdentity : textTransform;
        self.headerSubtitleLabel.transform = collapsed ? CGAffineTransformIdentity : textTransform;

        self.headerLiveCapsule.transform = collapsed ? CGAffineTransformMakeTranslation(0.0, -10.0) : CGAffineTransformIdentity;
        self.headerBrandHaloView.alpha = collapsed ? 0.96 : 1.0;
        self.headerBrandHaloView.transform = haloTransform;
        self.headerBrandRingView.transform = ringTransform;
        self.headerBrandMarkView.transform = ringTransform;
        self.novaRingBackgroundLottie.transform = collapsed ? CGAffineTransformMakeScale(0.96, 0.96) : CGAffineTransformIdentity;
        self.novaHeaderBottomGlowView.alpha = collapsed ? 0.50 : 1.0;
        self.novaHeaderBottomGlowView.transform = collapsed ? CGAffineTransformMakeTranslation(0.0, 8.0) : CGAffineTransformIdentity;
        (void)glowTransform;
        self.novaHeaderSheenView.alpha = [self pp_novaHeaderSheenAlphaForCurrentState];
        self.novaHeaderBackgroundLottie.alpha = [self pp_novaHeaderBackgroundAlphaForCurrentState];
        self.novaHeaderView.layer.shadowOpacity = collapsed ? 0.045 : 0.07;
        [self.novaHeaderMotionDots enumerateObjectsUsingBlock:^(UIView *dot, NSUInteger idx, __unused BOOL *stop) {
            dot.alpha = collapsed ? 0.12 : (idx % 2 == 0 ? 0.28 : 0.20);
            dot.transform = collapsed ? CGAffineTransformMakeScale(0.82, 0.82) : CGAffineTransformIdentity;
        }];
        [self pp_applyNovaTableInsetsForCurrentHeaderState];
        [self.view layoutIfNeeded];
        [self pp_updateNovaHeaderLiquidBorderPath];
    };

    if (duration <= 0.0) {
        changes();
        [self pp_startHeaderLiveAnimations];
        return;
    }

    [UIView animateWithDuration:duration
                          delay:0.0
         usingSpringWithDamping:0.91
          initialSpringVelocity:0.12
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:changes
                     completion:^(__unused BOOL finished) {
        [self pp_startHeaderLiveAnimations];
    }];
}

- (void)pp_applyNovaTableInsetsForCurrentHeaderState {
    if (!self.tableView) {
        return;
    }

    CGFloat topInset = self.novaHeaderCollapsed ? PPNovaCollapsedTableTopInset : PPNovaExpandedTableTopInset;
    UIEdgeInsets inset = self.tableView.contentInset;
    inset.top = topInset;
    self.tableView.contentInset = inset;
    self.tableView.scrollIndicatorInsets = inset;
}

- (void)pp_handleNovaHeaderControlPressDown:(UIButton *)sender {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        sender.alpha = 0.78;
        return;
    }

    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        sender.transform = CGAffineTransformMakeScale(0.94, 0.94);
        sender.alpha = 0.82;
    } completion:nil];
}

- (void)pp_handleNovaHeaderControlPressUp:(UIButton *)sender {
    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0.0 : 0.18
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        sender.transform = CGAffineTransformIdentity;
        sender.alpha = 1.0;
    } completion:nil];
}

- (void)pp_handleNovaCloseTapped:(UIButton *)sender {
    [self pp_handleNovaHeaderControlPressUp:sender];
    [self.view endEditing:YES];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)pp_startHeaderLiveAnimations {
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();

    [self.statusDot.layer removeAllAnimations];
    [self.novaHeaderBottomGlowView.layer removeAllAnimations];
    [self.novaHeaderSheenView.layer removeAllAnimations];
    [self.headerBrandHaloView.layer removeAllAnimations];
    [self.headerBrandRingView.layer removeAllAnimations];
    [self.headerBrandMarkView.layer removeAllAnimations];
    [self.novaHeaderLiquidBorderLayer removeAllAnimations];
    [self.novaHeaderLiquidHighlightLayer removeAllAnimations];
    for (UIView *dot in self.novaHeaderMotionDots) {
        [dot.layer removeAllAnimations];
    }
    [self pp_updateNovaHeaderLiquidBorderPath];
    if (reduceMotion) {
        self.novaHeaderLiquidBorderLayer.opacity = self.novaHeaderCollapsed ? 0.52 : 0.68;
        self.novaHeaderLiquidHighlightLayer.opacity = self.novaHeaderCollapsed ? 0.18 : 0.28;
        self.statusDot.alpha = 1.0;
        self.statusDot.transform = CGAffineTransformIdentity;
        self.novaHeaderBottomGlowView.transform = CGAffineTransformIdentity;
        self.novaHeaderSheenView.transform = CGAffineTransformIdentity;
        self.headerBrandHaloView.alpha = self.novaHeaderCollapsed ? 0.56 : 1.0;
        self.headerBrandHaloView.transform = self.novaHeaderCollapsed ? CGAffineTransformMakeScale(0.78, 0.78) : CGAffineTransformIdentity;
        self.headerBrandRingView.alpha = 1.0;
        self.headerBrandRingView.transform = self.novaHeaderCollapsed ? CGAffineTransformMakeScale(0.94, 0.94) : CGAffineTransformIdentity;
        self.headerBrandMarkView.transform = self.headerBrandRingView.transform;
        [self.novaHeaderBackgroundLottie stop];
        self.novaHeaderBackgroundLottie.alpha = [self pp_novaHeaderBackgroundAlphaForCurrentState];
        [self.novaRingBackgroundLottie stop];
        [self.novaHeaderMotionDots enumerateObjectsUsingBlock:^(UIView *dot, NSUInteger idx, __unused BOOL *stop) {
            dot.alpha = self.novaHeaderCollapsed ? 0.12 : (idx % 2 == 0 ? 0.28 : 0.20);
            dot.transform = CGAffineTransformIdentity;
        }];
        return;
    }

    [self.novaHeaderBackgroundLottie play];
    self.novaHeaderBackgroundLottie.alpha = [self pp_novaHeaderBackgroundAlphaForCurrentState];
    [self.novaRingBackgroundLottie play];

    CABasicAnimation *scale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scale.fromValue = @0.88;
    scale.toValue = @1.08;
    scale.duration = 2.4;
    scale.autoreverses = YES;
    scale.repeatCount = HUGE_VALF;
    scale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.statusDot.layer addAnimation:scale forKey:@"pp_statusDotScale"];

    CABasicAnimation *opacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacity.fromValue = @0.62;
    opacity.toValue = @1.0;
    opacity.duration = 2.4;
    opacity.autoreverses = YES;
    opacity.repeatCount = HUGE_VALF;
    opacity.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.statusDot.layer addAnimation:opacity forKey:@"pp_statusDotOpacity"];

    CABasicAnimation *bottomGlowDrift = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    bottomGlowDrift.fromValue = @(10.0);
    bottomGlowDrift.toValue = @(-2.0);
    bottomGlowDrift.duration = 5.8;
    bottomGlowDrift.autoreverses = YES;
    bottomGlowDrift.repeatCount = HUGE_VALF;
    bottomGlowDrift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.novaHeaderBottomGlowView.layer addAnimation:bottomGlowDrift forKey:@"pp_novaHeaderBottomGlowDrift"];

    CABasicAnimation *sheenBreath = [CABasicAnimation animationWithKeyPath:@"opacity"];
    sheenBreath.fromValue = @([self pp_novaHeaderSheenAlphaForCurrentState] * 0.62);
    sheenBreath.toValue = @([self pp_novaHeaderSheenAlphaForCurrentState]);
    sheenBreath.duration = 5.2;
    sheenBreath.autoreverses = YES;
    sheenBreath.repeatCount = HUGE_VALF;
    sheenBreath.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.novaHeaderSheenView.layer addAnimation:sheenBreath forKey:@"pp_novaHeaderSheenBreath"];

    CFTimeInterval baseTime = CACurrentMediaTime();
    [self.novaHeaderMotionDots enumerateObjectsUsingBlock:^(UIView *dot, NSUInteger idx, __unused BOOL *stop) {
        CAKeyframeAnimation *dotScale = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
        dotScale.values = @[@0.82, @1.28, @0.92];
        dotScale.keyTimes = @[@0.0, @0.48, @1.0];
        dotScale.duration = 4.6 + (idx * 0.35);
        dotScale.repeatCount = HUGE_VALF;
        dotScale.autoreverses = YES;
        dotScale.beginTime = baseTime + (idx * 0.18);
        dotScale.timingFunctions = @[
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]
        ];
        [dot.layer addAnimation:dotScale forKey:@"pp_novaHeaderDotScale"];

        CAKeyframeAnimation *dotOpacity = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
        CGFloat baseAlpha = self.novaHeaderCollapsed ? 0.12 : (idx % 2 == 0 ? 0.28 : 0.20);
        dotOpacity.values = @[@(baseAlpha * 0.62), @(MIN(baseAlpha + 0.18, 0.48)), @(baseAlpha)];
        dotOpacity.keyTimes = @[@0.0, @0.50, @1.0];
        dotOpacity.duration = dotScale.duration;
        dotOpacity.repeatCount = HUGE_VALF;
        dotOpacity.autoreverses = YES;
        dotOpacity.beginTime = dotScale.beginTime;
        [dot.layer addAnimation:dotOpacity forKey:@"pp_novaHeaderDotOpacity"];
    }];

    CABasicAnimation *haloOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    haloOpacity.fromValue = @(self.novaHeaderCollapsed ? 0.36 : 0.58);
    haloOpacity.toValue = @(self.novaHeaderCollapsed ? 0.62 : 1.0);
    haloOpacity.duration = 6.2;
    haloOpacity.autoreverses = YES;
    haloOpacity.repeatCount = HUGE_VALF;
    haloOpacity.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.headerBrandHaloView.layer addAnimation:haloOpacity forKey:@"pp_novaBrandHaloOpacity"];

    CABasicAnimation *haloScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    haloScale.fromValue = @(self.novaHeaderCollapsed ? 0.78 : 0.96);
    haloScale.toValue = @(self.novaHeaderCollapsed ? 0.86 : 1.055);
    haloScale.duration = 6.2;
    haloScale.autoreverses = YES;
    haloScale.repeatCount = HUGE_VALF;
    haloScale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.headerBrandHaloView.layer addAnimation:haloScale forKey:@"pp_novaBrandHaloScale"];

    CABasicAnimation *ringOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    ringOpacity.fromValue = @0.62;
    ringOpacity.toValue = @1.0;
    ringOpacity.duration = 5.6;
    ringOpacity.autoreverses = YES;
    ringOpacity.repeatCount = HUGE_VALF;
    ringOpacity.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.headerBrandRingView.layer addAnimation:ringOpacity forKey:@"pp_novaBrandRingOpacity"];

    CABasicAnimation *ringScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    ringScale.fromValue = @(self.novaHeaderCollapsed ? 0.94 : 0.992);
    ringScale.toValue = @(self.novaHeaderCollapsed ? 0.98 : 1.022);
    ringScale.duration = 5.6;
    ringScale.autoreverses = YES;
    ringScale.repeatCount = HUGE_VALF;
    ringScale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.headerBrandRingView.layer addAnimation:ringScale forKey:@"pp_novaBrandRingScale"];

    self.novaHeaderLiquidBorderLayer.opacity = self.novaHeaderCollapsed ? 0.54 : 0.72;
    self.novaHeaderLiquidHighlightLayer.opacity = self.novaHeaderCollapsed ? 0.24 : 0.36;

    CABasicAnimation *borderPulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    borderPulse.fromValue = @(self.novaHeaderCollapsed ? 0.42 : 0.58);
    borderPulse.toValue = @(self.novaHeaderCollapsed ? 0.58 : 0.78);
    borderPulse.duration = 5.8;
    borderPulse.autoreverses = YES;
    borderPulse.repeatCount = HUGE_VALF;
    borderPulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.novaHeaderLiquidBorderLayer addAnimation:borderPulse forKey:@"pp_novaHeaderLiquidBorderPulse"];

    CABasicAnimation *liquidFlow = [CABasicAnimation animationWithKeyPath:@"lineDashPhase"];
    liquidFlow.fromValue = @0.0;
    liquidFlow.toValue = @(-260.0);
    liquidFlow.duration = self.novaHeaderCollapsed ? 9.6 : 7.8;
    liquidFlow.repeatCount = HUGE_VALF;
    liquidFlow.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    [self.novaHeaderLiquidHighlightLayer addAnimation:liquidFlow forKey:@"pp_novaHeaderLiquidBorderFlow"];

    CABasicAnimation *highlightPulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    highlightPulse.fromValue = @(self.novaHeaderCollapsed ? 0.16 : 0.24);
    highlightPulse.toValue = @(self.novaHeaderCollapsed ? 0.30 : 0.46);
    highlightPulse.duration = 4.9;
    highlightPulse.autoreverses = YES;
    highlightPulse.repeatCount = HUGE_VALF;
    highlightPulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.novaHeaderLiquidHighlightLayer addAnimation:highlightPulse forKey:@"pp_novaHeaderLiquidBorderGlow"];
}

- (void)pp_stopHeaderLiveAnimations {
    [self.statusDot.layer removeAllAnimations];
    [self.novaHeaderBottomGlowView.layer removeAllAnimations];
    [self.novaHeaderSheenView.layer removeAllAnimations];
    [self.headerBrandHaloView.layer removeAllAnimations];
    [self.headerBrandRingView.layer removeAllAnimations];
    [self.headerBrandMarkView.layer removeAllAnimations];
    [self.novaHeaderLiquidBorderLayer removeAllAnimations];
    [self.novaHeaderLiquidHighlightLayer removeAllAnimations];
    for (UIView *dot in self.novaHeaderMotionDots) {
        [dot.layer removeAllAnimations];
    }
    [self.novaHeaderBackgroundLottie stop];
    [self.novaRingBackgroundLottie stop];
}

- (void)pp_showThinkingHeaderLottieWithAnimation:(NSString *)animationName {
    self.novaHeaderThinkingAnimationVisible = YES;
    [self pp_transitionHeaderBackgroundToAnimation:animationName];

    [self.novaLoadingLottie play];
    [UIView animateWithDuration:0.3 animations:^{
        self.novaLoadingLottie.alpha = 1.0;
    }];
}

- (void)pp_hideThinkingHeaderLottie {
    self.novaHeaderThinkingAnimationVisible = NO;

    //[self pp_transitionHeaderBackgroundToAnimation:@"novawave"];

    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0.0 : 0.24
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.novaLoadingLottie.alpha = 0.0;
    } completion:^(__unused BOOL finished) {
        if (!self.novaHeaderThinkingAnimationVisible) {
            [self.novaLoadingLottie stop];
        }
    }];
}

- (void)pp_transitionHeaderBackgroundToAnimation:(NSString *)animationName {
    if (!self.novaHeaderBackgroundLottie) return;
    if ([self.currentHeaderBgAnimationName isEqualToString:animationName]) {
        [self.novaHeaderBackgroundLottie play];
        [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0.0 : 0.24
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            self.novaHeaderBackgroundLottie.alpha = [self pp_novaHeaderBackgroundAlphaForCurrentState];
        } completion:nil];
        return;
    }

    self.currentHeaderBgAnimationName = animationName;

    [UIView animateWithDuration:0.32
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        self.novaHeaderBackgroundLottie.alpha = 0.0;
    } completion:^(BOOL finished) {
        if (!self || self.dismissed) return;

        __weak typeof(self) wself = self;
        [AppClasses setAnimationNamed:animationName
                               ToView:self.novaHeaderBackgroundLottie
                            withSpeed:1.0
                           completion:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(wself) self = wself;
                if (!self || self.dismissed) return;

                // If it changed AGAIN while we were loading, don't show the old one.
                if (![self.currentHeaderBgAnimationName isEqualToString:animationName]) return;

                if (success) {
                    [self.novaHeaderBackgroundLottie play];
                    [UIView animateWithDuration:0.38
                                          delay:0.06
                         usingSpringWithDamping:0.84
                          initialSpringVelocity:0.3
                                        options:UIViewAnimationOptionCurveEaseOut
                                     animations:^{
                        self.novaHeaderBackgroundLottie.alpha = [self pp_novaHeaderBackgroundAlphaForCurrentState];
                    } completion:nil];
                }
            });
        }];
    }];
}

- (void)setupInputView {
    self.inputbar = [[PPNovaFloatingInputBarView alloc] init];
    self.inputbar.delegate = self;
    self.inputbar.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:self.inputbar];

    self.inputBarRestingBottomConstant = -10.0;
    self.inputBarBottomConstraint = [self.inputbar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:self.inputBarRestingBottomConstant];
    NSLayoutConstraint *compactWidth = [self.inputbar.widthAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.widthAnchor constant:-24.0];
    compactWidth.priority = 999.0;
    NSLayoutConstraint *readableWidth = [self.inputbar.widthAnchor constraintEqualToConstant:760.0];
    readableWidth.priority = 998.0;

    [NSLayoutConstraint activateConstraints:@[
        [self.inputbar.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16.0],
        [self.inputbar.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16.0],
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

- (NSArray<NSDictionary<NSString *, NSString *> *> *)pp_novaSmartSuggestionSpecs {
    return @[
        @{@"titleKey": @"nova_smart_suggestion_cat_food",
          @"promptKey": @"nova_smart_suggestion_cat_food_prompt"},
        @{@"titleKey": @"nova_smart_suggestion_bird_bundle",
          @"promptKey": @"nova_smart_suggestion_bird_bundle_prompt"},
        @{@"titleKey": @"nova_smart_suggestion_medicine",
          @"promptKey": @"nova_smart_suggestion_medicine_prompt"},
        @{@"titleKey": @"nova_smart_suggestion_care",
          @"promptKey": @"nova_smart_suggestion_care_prompt"}
    ];
}

- (UIButton *)pp_makeNovaSmartSuggestionButtonWithTitle:(NSString *)title index:(NSUInteger)index {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tag = (NSInteger)index;
    button.clipsToBounds = YES;
    button.layer.cornerRadius = 19.0;
    button.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    button.contentEdgeInsets = UIEdgeInsetsMake(0.0, 15.0, 0.0, 15.0);
    button.titleLabel.font = [GM MidFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    button.titleLabel.numberOfLines = 1;
    button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    button.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    button.accessibilityLabel = title;
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:@selector(pp_handleNovaSmartSuggestionTap:) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(pp_handleNovaSmartSuggestionPressDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(pp_handleNovaSmartSuggestionPressCancel:) forControlEvents:UIControlEventTouchCancel | UIControlEventTouchDragExit | UIControlEventTouchUpOutside];

    [NSLayoutConstraint activateConstraints:@[
        [button.heightAnchor constraintEqualToConstant:38.0],
        [button.widthAnchor constraintGreaterThanOrEqualToConstant:128.0]
    ]];
    return button;
}

- (void)setupNovaEmptyState {
    UIView *emptyView = [[UIView alloc] init];
    emptyView.translatesAutoresizingMaskIntoConstraints = NO;
    emptyView.userInteractionEnabled = YES;
    emptyView.alpha = 1.0;
    [self.view insertSubview:emptyView aboveSubview:self.tableView];
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

    UIVisualEffectView *suggestionView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:[self pp_novaHeaderGlassBlurStyle]]];
    suggestionView.translatesAutoresizingMaskIntoConstraints = NO;
    suggestionView.clipsToBounds = YES;
    suggestionView.layer.cornerRadius = 22.0;
    suggestionView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    suggestionView.layer.shadowOpacity = 0.10;
    suggestionView.layer.shadowRadius = 18.0;
    suggestionView.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    suggestionView.alpha = 0.0;
    suggestionView.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
    suggestionView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    suggestionView.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    if (@available(iOS 13.0, *)) {
        suggestionView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [emptyView addSubview:suggestionView];
    self.smartSuggestionSurfaceView = suggestionView;

    UILabel *suggestionTitleLabel = [[UILabel alloc] init];
    suggestionTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    suggestionTitleLabel.font = [GM MidFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    suggestionTitleLabel.text = kLang(@"nova_smart_suggestions_title");
    suggestionTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    suggestionTitleLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [suggestionView.contentView addSubview:suggestionTitleLabel];
    self.smartSuggestionTitleLabel = suggestionTitleLabel;

    UIScrollView *suggestionScrollView = [[UIScrollView alloc] init];
    suggestionScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    suggestionScrollView.showsHorizontalScrollIndicator = NO;
    suggestionScrollView.alwaysBounceHorizontal = YES;
    suggestionScrollView.alwaysBounceVertical = NO;
    suggestionScrollView.directionalLockEnabled = YES;
    suggestionScrollView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [suggestionView.contentView addSubview:suggestionScrollView];

    UIStackView *suggestionStack = [[UIStackView alloc] init];
    suggestionStack.translatesAutoresizingMaskIntoConstraints = NO;
    suggestionStack.axis = UILayoutConstraintAxisHorizontal;
    suggestionStack.alignment = UIStackViewAlignmentFill;
    suggestionStack.distribution = UIStackViewDistributionFill;
    suggestionStack.spacing = 8.0;
    suggestionStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [suggestionScrollView addSubview:suggestionStack];

    NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
    NSArray<NSDictionary<NSString *, NSString *> *> *suggestions = [self pp_novaSmartSuggestionSpecs];
    [suggestions enumerateObjectsUsingBlock:^(NSDictionary<NSString *,NSString *> *spec, NSUInteger idx, __unused BOOL *stop) {
        UIButton *button = [self pp_makeNovaSmartSuggestionButtonWithTitle:kLang(spec[@"titleKey"]) index:idx];
        [suggestionStack addArrangedSubview:button];
        [buttons addObject:button];
    }];
    self.smartSuggestionButtons = buttons.copy;

    self.emptyStateCenterYConstraint = [emptyView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:8.0];

    [NSLayoutConstraint activateConstraints:@[
        [emptyView.leadingAnchor constraintEqualToAnchor:self.view.layoutMarginsGuide.leadingAnchor constant:12.0],
        [emptyView.trailingAnchor constraintEqualToAnchor:self.view.layoutMarginsGuide.trailingAnchor constant:-12.0],
        self.emptyStateCenterYConstraint,

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

        [suggestionView.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:18.0],
        [suggestionView.centerXAnchor constraintEqualToAnchor:emptyView.centerXAnchor],
        [suggestionView.leadingAnchor constraintGreaterThanOrEqualToAnchor:emptyView.leadingAnchor],
        [suggestionView.trailingAnchor constraintLessThanOrEqualToAnchor:emptyView.trailingAnchor],
        [suggestionView.widthAnchor constraintLessThanOrEqualToConstant:540.0],
        [suggestionView.bottomAnchor constraintEqualToAnchor:emptyView.bottomAnchor],

        [suggestionTitleLabel.topAnchor constraintEqualToAnchor:suggestionView.contentView.topAnchor constant:12.0],
        [suggestionTitleLabel.leadingAnchor constraintEqualToAnchor:suggestionView.contentView.leadingAnchor constant:14.0],
        [suggestionTitleLabel.trailingAnchor constraintEqualToAnchor:suggestionView.contentView.trailingAnchor constant:-14.0],

        [suggestionScrollView.topAnchor constraintEqualToAnchor:suggestionTitleLabel.bottomAnchor constant:9.0],
        [suggestionScrollView.leadingAnchor constraintEqualToAnchor:suggestionView.contentView.leadingAnchor constant:10.0],
        [suggestionScrollView.trailingAnchor constraintEqualToAnchor:suggestionView.contentView.trailingAnchor constant:-10.0],
        [suggestionScrollView.bottomAnchor constraintEqualToAnchor:suggestionView.contentView.bottomAnchor constant:-10.0],
        [suggestionScrollView.heightAnchor constraintEqualToConstant:38.0],

        [suggestionStack.topAnchor constraintEqualToAnchor:suggestionScrollView.contentLayoutGuide.topAnchor],
        [suggestionStack.leadingAnchor constraintEqualToAnchor:suggestionScrollView.contentLayoutGuide.leadingAnchor],
        [suggestionStack.trailingAnchor constraintEqualToAnchor:suggestionScrollView.contentLayoutGuide.trailingAnchor],
        [suggestionStack.bottomAnchor constraintEqualToAnchor:suggestionScrollView.contentLayoutGuide.bottomAnchor],
        [suggestionStack.heightAnchor constraintEqualToAnchor:suggestionScrollView.frameLayoutGuide.heightAnchor]
    ]];

    [self pp_applyNovaSurfaceColors];
    [self updateNovaEmptyStateAnimated:NO];
}

- (void)updateNovaEmptyStateAnimated:(BOOL)animated {
    BOOL shouldShow = ![self pp_hasUserMessageInCurrentNovaSession];
    CGFloat targetAlpha = shouldShow ? 1.0 : 0.0;

    void (^changes)(void) = ^{
        self.emptyStateView.alpha = targetAlpha;
        self.emptyStateView.userInteractionEnabled = shouldShow;
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

- (BOOL)pp_hasUserMessageInCurrentNovaSession {
    for (ChatMessageModel *message in self.messages) {
        if (![message.senderID isEqualToString:@"nova_bot_id"]) {
            return YES;
        }
    }
    return NO;
}

- (void)pp_revealNovaSmartSuggestionsIfNeeded {
    if (!self.smartSuggestionSurfaceView || [self pp_hasUserMessageInCurrentNovaSession]) {
        return;
    }

    NSArray<UIButton *> *buttons = self.smartSuggestionButtons ?: @[];
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.smartSuggestionSurfaceView.alpha = 1.0;
        self.smartSuggestionSurfaceView.transform = CGAffineTransformIdentity;
        for (UIButton *button in buttons) {
            button.alpha = 1.0;
            button.transform = CGAffineTransformIdentity;
        }
        return;
    }

    self.smartSuggestionSurfaceView.alpha = 0.0;
    self.smartSuggestionSurfaceView.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
    for (UIButton *button in buttons) {
        button.alpha = 0.0;
        button.transform = CGAffineTransformMakeTranslation(Language.isRTL ? -8.0 : 8.0, 0.0);
    }

    [UIView animateWithDuration:0.38
                          delay:0.20
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.16
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.smartSuggestionSurfaceView.alpha = 1.0;
        self.smartSuggestionSurfaceView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [buttons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger idx, __unused BOOL *stop) {
        [UIView animateWithDuration:0.30
                              delay:0.28 + (idx * 0.045)
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.20
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            button.alpha = 1.0;
            button.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (void)pp_handleNovaSmartSuggestionPressDown:(UIButton *)sender {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        sender.alpha = 0.72;
        return;
    }
    [UIView animateWithDuration:0.12
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        sender.transform = CGAffineTransformMakeScale(0.97, 0.97);
    } completion:nil];
}

- (void)pp_handleNovaSmartSuggestionPressCancel:(UIButton *)sender {
    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0.0 : 0.16
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        sender.alpha = 1.0;
        sender.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_handleNovaSmartSuggestionTap:(UIButton *)sender {
    if ([self pp_hasUserMessageInCurrentNovaSession]) {
        return;
    }

    NSArray<NSDictionary<NSString *, NSString *> *> *suggestions = [self pp_novaSmartSuggestionSpecs];
    if (sender.tag < 0 || sender.tag >= (NSInteger)suggestions.count) {
        return;
    }

    NSString *promptKey = suggestions[(NSUInteger)sender.tag][@"promptKey"];
    NSString *prompt = [kLang(promptKey) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (prompt.length == 0) {
        return;
    }

    for (UIButton *button in self.smartSuggestionButtons) {
        button.userInteractionEnabled = NO;
    }
    [self pp_setNovaHeaderCollapsed:YES animated:YES];

    NSTimeInterval duration = UIAccessibilityIsReduceMotionEnabled() ? 0.0 : 0.12;
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        sender.transform = CGAffineTransformMakeScale(0.965, 0.965);
        sender.alpha = 0.84;
    } completion:^(__unused BOOL finished) {
        sender.transform = CGAffineTransformIdentity;
        sender.alpha = 1.0;
        [self pp_handleNovaSubmittedText:prompt];
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

    NSInteger roll = arc4random_uniform(5) + 1;
    NSString *thinkingAnim = [NSString stringWithFormat:@"novabg%ld", (long)roll];
    [self pp_showThinkingHeaderLottieWithAnimation:thinkingAnim];

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

    [self pp_hideThinkingHeaderLottie];

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

    [self.tableView registerClass:[ChatMessageCell class] forCellReuseIdentifier:@"ChatMessageCell"];
    [self.tableView registerClass:[PPNovaProductMessageCell class] forCellReuseIdentifier:@"PPNovaProductMessageCell"];
    [self.tableView registerClass:[PPNovaReviewMessageCell class] forCellReuseIdentifier:[PPNovaReviewMessageCell reuseIdentifier]];

    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 92;
    self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.delaysContentTouches = NO;
    self.tableView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }
    self.tableView.contentInset = UIEdgeInsetsMake(PPNovaExpandedTableTopInset, 0, PPNovaTableBottomInset, 0);
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
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:32],
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
                                             selector:@selector(keyboardWillChangeFrame:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_appDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_appWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

- (void)pp_appDidEnterBackground:(__unused NSNotification *)note {
    [self pp_stopHeaderLiveAnimations];
    [self pp_stopAmbientBackgroundAnimations];
    [self pp_stopTypingDotsAnimation];
}

- (void)pp_appWillEnterForeground:(__unused NSNotification *)note {
    if (self.dismissed || self.view.window == nil) return;
    [self pp_startHeaderLiveAnimations];
    [self pp_startAmbientBackgroundAnimations];
    if (self.typingContainer.alpha > 0.5) {
        [self pp_startTypingDotsAnimation];
    }
}

- (void)keyboardWillChangeFrame:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    CGRect keyboardFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];

    CGRect keyboardInView = [self.view convertRect:keyboardFrame fromView:nil];
    CGFloat overlap = MAX(CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(keyboardInView), 0.0);
    CGFloat keyboardOffset = MAX(overlap - self.view.safeAreaInsets.bottom, 0.0);

    self.inputBarBottomConstraint.constant = keyboardOffset > 0.0
        ? -(keyboardOffset + 8.0)
        : self.inputBarRestingBottomConstant;

    self.emptyStateCenterYConstraint.constant = 8.0 - (keyboardOffset > 0 ? keyboardOffset / 2.0 : 0);

    // We rely on the constraint between the tableView bottom and inputBar top.
    // No need to dynamically adjust bottom inset for the keyboard height here,
    // as it leads to double-accounting and scroll jumps.
    UIEdgeInsets currentInset = self.tableView.contentInset;
    currentInset.bottom = PPNovaTableBottomInset;
    self.tableView.contentInset = currentInset;
    self.tableView.scrollIndicatorInsets = currentInset;

    UIViewAnimationOptions options = ((UIViewAnimationOptions)curve << 16) |
        UIViewAnimationOptionBeginFromCurrentState |
        UIViewAnimationOptionAllowUserInteraction;

    [UIView animateWithDuration:duration delay:0.0 options:options animations:^{
        [self.view layoutIfNeeded];
        [self scrollToBottomAnimated:NO];
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
    if (indexPath.row < 0 || indexPath.row >= (NSInteger)self.messages.count) {
        return [[UITableViewCell alloc] init];
    }
    ChatMessageModel *msg = self.messages[indexPath.row];

    if (msg.messageType == ChatMessageTypeNovaProduct || msg.messageType == ChatMessageTypeNovaProductList) {
        PPNovaProductMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPNovaProductMessageCell" forIndexPath:indexPath];
        cell.delegate = self;
        [cell configureWithMessage:msg maxWidth:[self pp_novaMessageLayoutWidthForTableView:tableView]];
        return cell;
    }

    if (msg.messageType == ChatMessageTypeNovaReview) {
        PPNovaReviewMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:[PPNovaReviewMessageCell reuseIdentifier] forIndexPath:indexPath];
        [cell configureWithMessage:msg maxWidth:[self pp_novaMessageLayoutWidthForTableView:tableView]];
        return cell;
    }

    ChatMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ChatMessageCell" forIndexPath:indexPath];
    [cell configureWithMessage:msg.text
                          date:msg.timestamp
                    isIncoming:[msg.senderID isEqualToString:@"nova_bot_id"]
                      maxWidth:[self pp_novaMessageLayoutWidthForTableView:tableView]
                        status:msg.status
                  messageModel:msg groupPosition:PPChatGroupPositionSingle];

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < 0 || indexPath.row >= (NSInteger)self.messages.count) {
        return 102.0;
    }
    ChatMessageModel *msg = self.messages[indexPath.row];
    if (msg.messageType == ChatMessageTypeNovaProduct || msg.messageType == ChatMessageTypeNovaProductList) {
        return 335.0;
    }
    if (msg.messageType == ChatMessageTypeNovaReview) {
        return 130.0;
    }
    return 102.0;
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
        if ([visibleCell isKindOfClass:PPNovaProductMessageCell.class]) {
            [(PPNovaProductMessageCell *)visibleCell updateAvailableWidth:tableWidth];
            continue;
        }

        if ([visibleCell isKindOfClass:PPNovaReviewMessageCell.class]) {
            PPNovaReviewMessageCell *cell = (PPNovaReviewMessageCell *)visibleCell;
            NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
            if (indexPath.row >= 0 && indexPath.row < self.messages.count) {
                ChatMessageModel *message = self.messages[indexPath.row];
                [cell configureWithMessage:message maxWidth:tableWidth];
            }
            continue;
        }

        if (![visibleCell isKindOfClass:ChatMessageCell.class]) continue;

        ChatMessageCell *cell = (ChatMessageCell *)visibleCell;
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        if (indexPath.row < 0 || indexPath.row >= self.messages.count) continue;

        ChatMessageModel *message = self.messages[indexPath.row];

        [cell configureWithMessage:message.text
                              date:message.timestamp
                        isIncoming:[message.senderID isEqualToString:@"nova_bot_id"]
                          maxWidth:tableWidth
                            status:message.status
                      messageModel:message groupPosition:PPChatGroupPositionSingle];

    }
}

- (void)pp_refreshVisibleNovaCellLayoutForCurrentTableWidth {
    CGFloat width = [self pp_novaMessageLayoutWidthForTableView:self.tableView];
    [self pp_updateVisibleNovaMessageCellWidthsForTableWidth:width];
    [UIView performWithoutAnimation:^{
        [self.tableView beginUpdates];
        [self.tableView endUpdates];
    }];
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

- (void)novaInputBarDidBeginEditing:(PPNovaFloatingInputBarView *)bar {
    [self pp_setNovaHeaderCollapsed:YES animated:YES];
}

- (void)novaInputBar:(PPNovaFloatingInputBarView *)bar didChangeText:(NSString *)text {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length > 0) {
        [self pp_setNovaHeaderCollapsed:YES animated:YES];
    }
}

- (void)novaInputBar:(PPNovaFloatingInputBarView *)bar didSendText:(NSString *)text {
    [self pp_handleNovaSubmittedText:text];
}

- (void)novaInputBar:(PPNovaFloatingInputBarView *)bar didChangeHeight:(CGFloat)height {
    CGFloat inputBarTotalHeight = CGRectGetHeight(self.inputbar.frame);
    CGFloat keyboardOffset = -(self.inputBarBottomConstraint.constant) - 8.0;
    if (keyboardOffset < 0) keyboardOffset = 0;

    CGFloat bottomInset = keyboardOffset + height + PPNovaTableBottomInset + (keyboardOffset > 0 ? 8.0 : -self.inputBarRestingBottomConstant);
    UIEdgeInsets currentInset = self.tableView.contentInset;
    currentInset.bottom = bottomInset;
    self.tableView.contentInset = currentInset;
    self.tableView.scrollIndicatorInsets = currentInset;

    [UIView animateWithDuration:0.18 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        [self.view layoutIfNeeded];
    } completion:^(__unused BOOL finished) {
        [self scrollToBottomAnimated:NO];
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

    [self pp_updateMemoryFromUserText:trimmedText];
    [self pp_logNovaIntentForUserText:trimmedText stage:@"submitted"];

    [self showNovaTyping];
    if ([self pp_novaTextHasShowcaseDisplayIntent:trimmedText] &&
        [self pp_localNovaNeedLabelFromUserText:trimmedText].length == 0 &&
        [self pp_localNovaPetTypeFromUserText:trimmedText].length == 0 &&
        (self.novaMemoryNeed.length > 0 || self.novaMemoryPetType.length > 0)) {
        [self pp_fetchAndShowLocalNovaShowcaseForUserText:trimmedText
                                                introText:nil
                                               completion:^(BOOL didShow) {
            [self hideNovaTyping];
            if (!didShow) {
                [self pp_addNovaProductResultTextForRenderedCount:0
                                                     proposedText:nil
                                                         userText:trimmedText
                                                           source:@"display_intent_memory_target"];
            }
        }];
        return;
    }
    [self sendNovaRequestForUserText:trimmedText];
}

// Production-safe add-to-cart intent classifier.
// Adding to cart is irreversible from a trust standpoint — false positives are far worse
// than false negatives. Rules:
//   1. Cap total length (≤30 chars) — true affirmations are short.
//   2. Reject if any negation token is present (English/Arabic).
//   3. Tier 1: bare-word exact match (e.g., "اريد" alone — but not "اريد المساعدة").
//   4. Tier 2: prefix + word-boundary match with ≤15-char tail
//      (e.g., "yes please" YES; "yes I have a question" NO).
- (BOOL)pp_isAddToCartIntent:(NSString *)text {
    if (text.length == 0) return NO;
    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0 || trimmed.length > 30) return NO;
    NSString *lower = [trimmed lowercaseString];

    // -- Negations short-circuit --------------------------------------------------
    NSArray<NSString *> *englishNegations = @[
        @"don't", @"dont", @"do not", @"not", @"no", @"never", @"won't", @"wont"
    ];
    for (NSString *neg in englishNegations) {
        if ([self pp_lowercase:lower containsWord:neg]) return NO;
    }
    NSArray<NSString *> *arabicNegationsSubstr = @[
        @"لا ", @" لا", @"لست", @"ليس", @"ليست",
        @"ما ", @" ما", @"مش ", @"مو ", @"مب "
    ];
    for (NSString *neg in arabicNegationsSubstr) {
        if ([trimmed containsString:neg]) return NO;
    }
    if ([trimmed isEqualToString:@"لا"] || [trimmed isEqualToString:@"ما"]) return NO;

    // -- Tier 1: bare-word exact match. Words too generic for substring matching --
    // ("اريد" alone is fine; "اريد المساعدة" must NOT trigger.)
    NSArray<NSString *> *exactOnly = @[
        @"اريد", @"أريد", @"بدي", @"ابي", @"أبي", @"ودي",
        @"حسنا", @"حسناً", @"موافق", @"please"
    ];
    for (NSString *aff in exactOnly) {
        if ([trimmed isEqualToString:aff] || [lower isEqualToString:aff.lowercaseString]) return YES;
    }

    // -- Tier 2: prefix + boundary + short tail -----------------------------------
    NSArray<NSString *> *prefixAffirmatives = @[
        @"yes", @"yep", @"yeah", @"yup", @"sure", @"ok", @"okay",
        @"add it", @"add to cart", @"add",
        @"buy it", @"buy", @"take it", @"i want it", @"i'll take",
        @"do it", @"go ahead", @"please add",
        @"نعم", @"ايوه", @"ايوا", @"ايه",
        @"اضف", @"أضف", @"اضفه", @"أضفه", @"اضيفه", @"أضيفه", @"اضفها", @"أضفها",
        @"اشتري", @"اشتريه",
        @"تمام", @"ماشي", @"يلا", @"هيا", @"اوكي", @"أوكي"
    ];
    for (NSString *aff in prefixAffirmatives) {
        NSString *lp = aff.lowercaseString;
        if (![lower hasPrefix:lp]) continue;
        NSInteger affLen = (NSInteger)lp.length;
        if ((NSInteger)lower.length == affLen) return YES;
        unichar nextChar = [lower characterAtIndex:affLen];
        BOOL isWordBoundary = (nextChar == ' ' || nextChar == ',' || nextChar == '.' ||
                               nextChar == '!' || nextChar == '\t' || nextChar == 0x060C);
        if (!isWordBoundary) continue;
        if ((NSInteger)lower.length - affLen <= 15) return YES;
    }
    return NO;
}

- (BOOL)pp_lowercase:(NSString *)haystack containsWord:(NSString *)word {
    if (word.length == 0 || haystack.length == 0) return NO;
    NSString *escaped = [NSRegularExpression escapedPatternForString:word];
    NSString *pattern = [NSString stringWithFormat:@"(^|\\W)%@(\\W|$)", escaped];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:nil];
    if (!regex) return NO;
    return [regex numberOfMatchesInString:haystack
                                  options:0
                                    range:NSMakeRange(0, haystack.length)] > 0;
}

- (void)pp_handleAddToCartForProduct:(PetAccessory *)product {
    [PPHUD showLoading:@""];

    CartItem *item = [[CartItem alloc] initWithAccessory:product quantity:1];
    item.type = product.isPetMedicine ? @"petMedicine" : @"petAccessory";

    BOOL success = [[CartManager sharedManager] addItem:item];

    if (success) {
        NSString *category = [NSString stringWithFormat:@"acc-%ld", (long)product.petMainCategoryID];
        [PPAnalytics logAddToCartItemID:product.accessoryID
                                    name:product.name
                                category:category
                                   price:product.finalPrice.doubleValue
                                quantity:1];

        UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
        [fb prepare];
        [fb notificationOccurred:UINotificationFeedbackTypeSuccess];
    }

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

// Adds a Nova-side system bubble (connectivity status, blocked-account, etc.)
// only if the previous Nova message wasn't already this exact text. Prevents
// the "Nova is unavailable / Nova is unavailable / Nova is unavailable" loop
// when the user keeps typing during a backend outage.
- (void)pp_addNovaSystemBubbleIfNew:(NSString *)text {
    if (text.length == 0) {
        return;
    }
    for (NSInteger i = (NSInteger)self.messages.count - 1; i >= 0; i--) {
        ChatMessageModel *msg = self.messages[i];
        if (![msg.senderID isEqualToString:@"nova_bot_id"]) {
            continue;
        }
        if (msg.messageType != ChatMessageTypeText) {
            break;
        }
        if ([msg.text isEqualToString:text]) {
            return;
        }
        break;
    }
    [self addNovaMessage:text];
}

- (void)addMessageWithText:(NSString *)text isIncoming:(BOOL)isIncoming {
    ChatMessageModel *msg = [[ChatMessageModel alloc] init];
    msg.ID = [[NSUUID UUID] UUIDString];
    msg.text = text;
    msg.timestamp = [NSDate date];
    msg.status = ChatMessageStatusSent;
    msg.messageType = ChatMessageTypeText;
    msg.senderID = isIncoming ? @"nova_bot_id" : [UserManager sharedManager].currentUser.ID;

    [[PPNovaLocalChatMemory sharedMemory] addMessageWithRole:isIncoming ? @"nova" : @"user" text:text];

    [self.messages addObject:msg];
    [self pp_trimMessageHistoryIfNeeded];
    [self updateNovaEmptyStateAnimated:YES];
    [[PPChatFeedbackManager shared] playFeedbackForEvent:isIncoming ? PPChatFeedbackEventIncomingActiveChat : PPChatFeedbackEventOutgoingSend];
    [self animateInsertedRowAtIndexPath:[NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0]];
}

// Cap message history at 100; when exceeded drop oldest 20 in one batch and reload.
// A long Nova session would otherwise grow unbounded (memory + scroll perf).
- (void)pp_trimMessageHistoryIfNeeded {
    static const NSUInteger kCap = 100;
    static const NSUInteger kTrimChunk = 20;
    if (self.messages.count <= kCap) return;
    NSUInteger floor = kCap - kTrimChunk;
    if (self.messages.count <= floor) return;
    NSUInteger removeCount = self.messages.count - floor;
    [self.messages removeObjectsInRange:NSMakeRange(0, removeCount)];
    [self.tableView reloadData];
}

// Best-effort principle-based reply sanitizer. Backend `sanitize_reply` flags issues but
// does not hard-strip; this is the client-side belt-and-suspenders so users never see:
//   - re-greetings (the screen already showed one when it opened),
//   - pressure phrases that the Nova baseline explicitly removed
//     (limited stock / availability / reserve-now / pressure CTAs, EN + AR).
// If everything gets stripped, returns "" — caller (pp_dispatchNovaRequest) skips the bubble.
- (NSString *)pp_sanitizeNovaReply:(NSString *)text hideStructuredSuggestions:(BOOL)hideStructuredSuggestions {
    if (text.length == 0) return text;

    NSString *result = text;
    if (hideStructuredSuggestions) {
        result = [self pp_stripStructuredNovaSuggestionText:result];
    }
    result = [self pp_stripNovaSuggestionReferenceTags:result];

    // Collapse runs of whitespace introduced by mid-text strips.
    NSRegularExpression *ws = [NSRegularExpression regularExpressionWithPattern:@"[ \\t]{2,}"
                                                                        options:0
                                                                          error:nil];
    if (ws) {
        result = [ws stringByReplacingMatchesInString:result
                                              options:0
                                                range:NSMakeRange(0, result.length)
                                         withTemplate:@" "];
    }
    result = [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return result;
}

- (NSString *)pp_stripNovaSuggestionReferenceTags:(NSString *)text {
    if (text.length == 0) return text;

    NSString *result = text;
    NSArray<NSString *> *patterns = @[
        @"\\[PRODUCT_ID:\\s*[^\\]]+\\]",
        @"\\[SERVICE_ID:\\s*[^\\]]+\\]",
        @"\\[MEDICINE_ID:\\s*[^\\]]+\\]",
        @"\\[PET_AD_ID:\\s*[^\\]]+\\]",
        @"\\[AD_ID:\\s*[^\\]]+\\]",
        @"\\[ADOPTION_ID:\\s*[^\\]]+\\]",
        @"\\[ADOPT_PET_ID:\\s*[^\\]]+\\]",
        @"\\[VET_ID:\\s*[^\\]]+\\]",
        @"\\[VETERINARIAN_ID:\\s*[^\\]]+\\]"
    ];
    for (NSString *pattern in patterns) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                               options:NSRegularExpressionCaseInsensitive
                                                                                 error:nil];
        if (!regex) continue;
        result = [regex stringByReplacingMatchesInString:result
                                                 options:0
                                                   range:NSMakeRange(0, result.length)
                                            withTemplate:@""];
    }
    return result;
}

- (NSString *)pp_stripStructuredNovaSuggestionText:(NSString *)text {
    if (text.length == 0) return text;

    NSString *result = text;
    NSRegularExpression *tagSentenceRegex =
    [NSRegularExpression regularExpressionWithPattern:@"[^\\.\\n!؟\\?]*(?:\\[PRODUCT_ID:|\\[SERVICE_ID:|\\[MEDICINE_ID:|\\[PET_AD_ID:|\\[AD_ID:|\\[ADOPTION_ID:|\\[ADOPT_PET_ID:|\\[VET_ID:|\\[VETERINARIAN_ID:)[^\\.\\n!؟\\?]*[\\.\\n!؟\\?]?"
                                             options:NSRegularExpressionCaseInsensitive
                                               error:nil];
    if (tagSentenceRegex) {
        result = [tagSentenceRegex stringByReplacingMatchesInString:result
                                                            options:0
                                                              range:NSMakeRange(0, result.length)
                                                       withTemplate:@"\n"];
    }

    NSMutableArray<NSString *> *keptLines = [NSMutableArray array];
    NSArray<NSString *> *lines = [result componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];
    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (trimmed.length == 0) {
            continue;
        }
        if ([self pp_isNovaStructuredSuggestionLine:trimmed]) {
            continue;
        }
        [keptLines addObject:trimmed];
    }
    if (keptLines.count == 1) {
        NSString *onlyLine = keptLines.firstObject;
        if ([onlyLine hasSuffix:@":"] || [onlyLine hasSuffix:@"："] || [onlyLine hasSuffix:@"،"]) {
            return @"";
        }
    }
    return [keptLines componentsJoinedByString:@"\n"];
}

- (BOOL)pp_novaReplyContainsNoProductClaim:(NSString *)text {
    if (text.length == 0) {
        return NO;
    }
    NSArray<NSString *> *patterns = @[
        @"couldn['’]?t\\s+find",
        @"could\\s+not\\s+find",
        @"can['’]?t\\s+find",
        @"cannot\\s+find",
        @"didn['’]?t\\s+find",
        @"did\\s+not\\s+find",
        @"unable\\s+to\\s+find",
        @"no\\s+(matching\\s+)?(products?|items?|results?|matches?|inventory)",
        @"not\\s+available",
        @"current\\s+inventory",
        @"check\\s+(the\\s+)?(pure\\s+pets\\s+)?catalog",
        @"لم\\s+أجد",
        @"لا\\s*أجد",
        @"لم\\s+اجد",
        @"لا\\s*اجد",
        @"لم\\s+نجد",
        @"لا\\s*نجد",
        @"ما\\s+لقيت",
        @"ما\\s+لقينا",
        @"لا\\s+يوجد",
        @"لا\\s+توجد",
        @"غير\\s+متوفر"
    ];
    for (NSString *pattern in patterns) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                               options:NSRegularExpressionCaseInsensitive
                                                                                 error:nil];
        if (regex && [regex numberOfMatchesInString:text options:0 range:NSMakeRange(0, text.length)] > 0) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)pp_isNovaStructuredSuggestionLine:(NSString *)line {
    if (line.length == 0) {
        return YES;
    }

    NSString *lower = line.lowercaseString;
    if ([lower containsString:@"productid"] ||
        [lower containsString:@"product_ids"] ||
        [lower containsString:@"serviceid"] ||
        [lower containsString:@"service_ids"] ||
        [lower containsString:@"medicineid"] ||
        [lower containsString:@"medicine_ids"] ||
        [lower containsString:@"petadid"] ||
        [lower containsString:@"pet_ad_ids"] ||
        [lower containsString:@"adoptionid"] ||
        [lower containsString:@"adoption_ids"] ||
        [lower containsString:@"adoptpetid"] ||
        [lower containsString:@"adopt_pet_ids"] ||
        [lower containsString:@"vetid"] ||
        [lower containsString:@"vet_ids"] ||
        [lower containsString:@"veterinarianid"] ||
        [lower containsString:@"veterinarian_ids"]) {
        return YES;
    }
    NSArray<NSString *> *headers = @[
        @"curated picks", @"suggestions", @"suggestion", @"recommended products",
        @"recommended items", @"recommended services", @"products", @"services", @"medicines",
        @"pet ads", @"ads", @"adoptions", @"adoption posts", @"vets", @"veterinarians",
        @"اختيارات", @"اختيارات مناسبة", @"اقتراحات", @"الاقتراحات",
        @"منتجات", @"المنتجات", @"خدمات", @"الخدمات", @"أدوية", @"الأدوية",
        @"إعلانات", @"اعلانات", @"تبني", @"للتبني", @"أطباء", @"اطباء", @"بيطريين"
    ];
    for (NSString *header in headers) {
        if ([lower isEqualToString:header] ||
            [lower isEqualToString:[header stringByAppendingString:@":"]] ||
            [lower isEqualToString:[header stringByAppendingString:@"："]]) {
            return YES;
        }
    }
    if (([lower containsString:@"recommend"] ||
         [line containsString:@"أنصح"] ||
         [line containsString:@"أرشح"]) &&
        ([line hasSuffix:@":"] || [line hasSuffix:@"："])) {
        return YES;
    }

    unichar first = [line characterAtIndex:0];
    if (first == '-' || first == 0x2022 || first == '*') {
        return YES;
    }

    NSRegularExpression *numberedLineRegex =
    [NSRegularExpression regularExpressionWithPattern:@"^\\d+[\\).]\\s+"
                                             options:0
                                               error:nil];
    return [numberedLineRegex numberOfMatchesInString:line
                                              options:0
                                                range:NSMakeRange(0, line.length)] > 0;
}



- (void)animateInsertedRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    [self scrollToBottomAnimated:YES];
}

#pragma mark - PPNovaProductMessageCellDelegate

- (void)novaProductCell_didTapAddToCart:(id)item {
    if (![item isKindOfClass:PetAccessory.class]) {
        return;
    }
    [self pp_handleAddToCartForProduct:(PetAccessory *)item];
}

- (void)novaProductCell_didTapProduct:(id)item {
    if ([item isKindOfClass:PetAd.class]) {
        PetAd *ad = (PetAd *)item;
        [PPAnalytics logNovaPreviewOpenedWithItemKind:@"pet_ad"
                                               itemID:ad.adID
                                            sessionID:self.novaSessionId];
        ViewerVC *viewer = [[ViewerVC alloc] init];
        viewer.ad = ad;
        [self pp_openNovaStackViewer:viewer];
        return;
    }

    if ([item isKindOfClass:AdoptPetModel.class]) {
        AdoptPetModel *pet = (AdoptPetModel *)item;
        [PPAnalytics logNovaPreviewOpenedWithItemKind:@"adoption"
                                               itemID:pet.documentID
                                            sessionID:self.novaSessionId];
        AdoptPetDetailsViewController *viewer = [[AdoptPetDetailsViewController alloc] initWithModel:pet];
        [self pp_openNovaStackViewer:viewer];
        return;
    }

    if ([item isKindOfClass:ServiceModel.class]) {
        ServiceModel *service = (ServiceModel *)item;
        [PPAnalytics logNovaPreviewOpenedWithItemKind:@"service"
                                               itemID:service.serviceID
                                            sessionID:self.novaSessionId];
        ServiceViewerViewController *viewer = [ServiceViewerViewController new];
        viewer.service = service;
        [PPFunc presentSheetFrom:self sheetVC:viewer detentStyle:PPSheetDetentStyleLargeOnly];
        return;
    }

    if ([item isKindOfClass:VetModel.class]) {
        VetModel *vet = (VetModel *)item;
        [PPAnalytics logNovaPreviewOpenedWithItemKind:@"vet"
                                               itemID:vet.vetID
                                            sessionID:self.novaSessionId];
        PPPetCareVetViewrVC *viewer = [[PPPetCareVetViewrVC alloc] initWithVet:vet
                                                                  mainKindName:nil];
        [PPFunc presentSheetFrom:self sheetVC:viewer detentStyle:PPSheetDetentStyleLargeOnly];
        return;
    }

    if (![item isKindOfClass:PetAccessory.class]) {
        return;
    }

    PetAccessory *product = (PetAccessory *)item;
    [PPAnalytics logNovaPreviewOpenedWithItemKind:(product.isPetMedicine ? @"medicine" : @"product")
                                           itemID:product.accessoryID
                                        sessionID:self.novaSessionId];
    NSString *category = [NSString stringWithFormat:@"acc-%ld", (long)product.petMainCategoryID];
    [PPAnalytics logSelectItemWithItemID:product.accessoryID
                                     name:product.name
                                 category:category
                                    price:product.finalPrice.doubleValue
                                 listName:@"nova_chat"];

    if (product.isPetMedicine) {
        VetMedicineModel *medicine = [self pp_novaMedicineModelFromAccessory:product];
        PPPetCareViewerVC *viewer = [[PPPetCareViewerVC alloc] initWithMedicine:medicine
                                                                   mainKindName:kLang(@"pet_care_all_pets")];
        [self pp_openNovaStackViewer:viewer];
        return;
    }

    AccessViewerVC *viewer = [[AccessViewerVC alloc] init];
    viewer.accessAds = product;
    [self pp_openNovaStackViewer:viewer];
}

- (VetMedicineModel *)pp_novaMedicineModelFromAccessory:(PetAccessory *)accessory {
    NSMutableDictionary *data = [[accessory toFirestoreDictionary] mutableCopy] ?: [NSMutableDictionary dictionary];
    data[@"accessKindType"] = @(AccessTypePetMedicine);
    data[@"type"] = @(AccessTypePetMedicine);
    if (accessory.name.length > 0) {
        data[@"title"] = accessory.name;
        data[@"name"] = accessory.name;
        data[@"nameEn"] = accessory.name;
    }
    if (accessory.desc.length > 0) {
        data[@"description"] = accessory.desc;
        data[@"desc"] = accessory.desc;
        data[@"descEn"] = accessory.desc;
    }
    NSString *firstImage = [accessory.imageURLsArray.firstObject isKindOfClass:NSString.class]
        ? accessory.imageURLsArray.firstObject
        : @"";
    if (firstImage.length > 0) {
        data[@"imageUrl"] = firstImage;
    }
    data[@"stockQuantity"] = @(MAX(accessory.quantity, 0));
    data[@"quantity"] = @(MAX(accessory.quantity, 0));
    data[@"isAvailable"] = @(accessory.quantity > 0);
    data[@"isPublished"] = @YES;
    if (!data[@"currency"]) {
        data[@"currency"] = @"QAR";
    }
    return [VetMedicineModel fromDictionary:data withID:accessory.accessoryID ?: @""];
}

- (void)pp_openNovaStackViewer:(UIViewController *)viewer {
    if (!viewer) {
        return;
    }
    viewer.hidesBottomBarWhenPushed = YES;
    if (self.navigationController) {
        [self.navigationController pushViewController:viewer animated:YES];
    } else {
        PPNavigationController *nav = [[PPNavigationController alloc] initWithRootViewController:viewer];
        [self presentViewController:nav animated:YES completion:nil];
    }
}

@end
