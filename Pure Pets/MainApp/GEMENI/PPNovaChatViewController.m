//
//  PPNovaChatViewController.m
//  Pure Pets
//

#import "PPNovaChatViewController.h"
#import "ChatMessageModel.h"
#import "PPNovaMessageBubbleCell.h"
#import "PPNovaProductMessageCell.h"
#import "PPNovaReviewMessageCell.h"
#import "PPNovaFloatingInputBarView.h"
#import "AppManager.h"
#import "PPNavigationController.h"
#import "PetAccessoryManager.h"
#import "CartManager.h"
#import "CartItem.h"
#import "PPHUD.h"
#import "AccessViewerVC.h"
#import "ServiceViewerViewController.h"
#import "PPPetCareViewerVC.h"
#import "PPOverlayCoordinator.h"
#import "PPAnalytics.h"
#import <IQKeyboardManager/IQKeyboardManager.h>

static UIColor *PPNovaDynamicColor(UIColor *lightColor, UIColor *darkColor) {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
        }];
    }
    return lightColor;
}

static const CGFloat PPNovaExpandedTableTopInset = 174.0;
static const CGFloat PPNovaCollapsedTableTopInset = 96.0;
static const CGFloat PPNovaTableBottomInset = 12.0;

@interface PPNovaChatViewController () <UITableViewDelegate, UITableViewDataSource, PPNovaFloatingInputBarViewDelegate, PPNovaProductMessageCellDelegate>

@property (nonatomic, strong) UIView *ambientBackgroundView;
@property (nonatomic, strong) UIView *novaHeaderView;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIView *headerBrandRingView;
@property (nonatomic, strong) UIView *headerBrandMarkView;
@property (nonatomic, strong) UIView *headerHairlineHost;
@property (nonatomic, strong) UIView *headerLiveCapsule;
@property (nonatomic, strong) UIView *statusDot;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *headerNameLabel;
@property (nonatomic, strong) UILabel *headerSubtitleLabel;
@property (nonatomic, strong) NSLayoutConstraint *novaHeaderExpandedBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *novaHeaderCollapsedBottomConstraint;
@property (nonatomic, assign) BOOL novaHeaderCollapsed;
@property (nonatomic, strong) UIVisualEffectView *typingContainer;
@property (nonatomic, strong) UILabel *typingLabel;
@property (nonatomic, copy)   NSArray<UIView *> *typingDots;
@property (nonatomic, strong) UIView *emptyStateView;
@property (nonatomic, strong) UIView *emptyStatePulseView;

@property (nonatomic, strong) LOTAnimationView *novaHeaderBackgroundLottie;
@property (nonatomic, copy) NSString *currentHeaderBgAnimationName;
@property (nonatomic, strong) LOTAnimationView *novaRingBackgroundLottie;

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

    // Update local session memory BEFORE we build the context payload. Idempotent across retries.
    [self pp_updateMemoryFromUserText:trimmedText];

    [PPAnalytics logNovaMessageSentWithCharCount:trimmedText.length
                                         isArabic:[self textContainsArabic:trimmedText]
                                       sessionID:self.novaSessionId];

    [self pp_dispatchNovaRequest:trimmedText attempt:0];
}

- (void)pp_dispatchNovaRequest:(NSString *)trimmedText attempt:(NSInteger)attempt {
    if (self.dismissed) return;

    if (!self.novaCallable) {
        [self hideNovaTyping];
        [self insertNovaReplyForUserText:trimmedText];
        [self pp_fetchAndShowLocalNovaShowcaseForUserText:trimmedText completion:nil];
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
            if (!self || self.dismissed) return;

            if (error) {
                if (attempt == 0 && [PPNovaChatViewController pp_isRetryableNovaError:error]) {
                    LOG_WARN(@"[PPNovaChat] geminiProxy transient error (will retry once): %@", error.localizedDescription);
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        __strong typeof(weakSelf) inner = weakSelf;
                        if (!inner || inner.dismissed) return;
                        [inner pp_dispatchNovaRequest:trimmedText attempt:1];
                    });
                    return;
                }
                [self hideNovaTyping];
                LOG_ERROR(@"[PPNovaChat] geminiProxy failed (attempt %ld, code=%ld): %@",
                          (long)attempt, (long)error.code, error.localizedDescription);
                [PPAnalytics logNovaErrorWithCode:error.code
                                            domain:error.domain
                                           attempt:attempt
                                         sessionID:self.novaSessionId];

                // Surface specific error classes instead of the misleading "Got it..." fallback.
                NSString *userFacing = [PPNovaChatViewController pp_userFacingErrorForNovaError:error];
                if (userFacing.length > 0) {
                    [self addNovaMessage:userFacing];
                    return;
                }
                [self insertNovaReplyForUserText:trimmedText];
                [self pp_fetchAndShowLocalNovaShowcaseForUserText:trimmedText completion:nil];
                return;
            }

            NSString *replyText = nil;
            NSArray<NSDictionary<NSString *, NSString *> *> *suggestionRefs = @[];
            if ([result.data isKindOfClass:NSDictionary.class]) {
                NSDictionary *data = (NSDictionary *)result.data;
                id textValue = data[@"text"];
                if ([textValue isKindOfClass:NSString.class]) {
                    replyText = (NSString *)textValue;
                }
                suggestionRefs = [self pp_novaSuggestionRefsFromResponseData:data replyText:replyText];
            } else {
                suggestionRefs = [self pp_novaSuggestionRefsFromResponseData:nil replyText:replyText];
            }

            replyText = [replyText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (replyText.length == 0 && suggestionRefs.count == 0) {
                [self hideNovaTyping];
                LOG_WARN(@"[PPNovaChat] geminiProxy returned empty reply and no products; using local fallback.");
                [self insertNovaReplyForUserText:trimmedText];
                [self pp_fetchAndShowLocalNovaShowcaseForUserText:trimmedText completion:nil];
                return;
            }

            NSString *suggestionFallbackText = nil;
            if (replyText.length > 0) {
                NSString *sanitizedReply = [self pp_sanitizeNovaReply:replyText hideStructuredSuggestions:(suggestionRefs.count > 0)];
                if (sanitizedReply.length > 0) {
                    [self addNovaMessage:sanitizedReply];
                } else if (suggestionRefs.count == 0) {
                    [self hideNovaTyping];
                    [self insertNovaReplyForUserText:trimmedText];
                    [self pp_fetchAndShowLocalNovaShowcaseForUserText:trimmedText completion:nil];
                    return;
                } else {
                    suggestionFallbackText = [self pp_sanitizeNovaReply:replyText hideStructuredSuggestions:NO];
                }
            }

            if (suggestionRefs.count > 0) {
                if (suggestionFallbackText.length == 0) {
                    suggestionFallbackText = kLang(@"nova_suggestions_unavailable");
                }
                [self pp_fetchAndShowNovaSuggestionRefs:suggestionRefs
                                           fallbackText:suggestionFallbackText
                                               userText:trimmedText];
            } else {
                [self hideNovaTyping];
                [self pp_fetchAndShowLocalNovaShowcaseForUserText:trimmedText completion:nil];
            }
        });
    }];
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

- (NSArray<NSDictionary<NSString *, NSString *> *> *)pp_novaSuggestionRefsFromResponseData:(NSDictionary *)data
                                                                                 replyText:(NSString *)replyText
{
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *refs = [NSMutableArray array];

    if ([data isKindOfClass:NSDictionary.class]) {
        NSDictionary<NSString *, NSString *> *keyKinds = @{
            @"productIDs": @"product", @"productIds": @"product", @"product_ids": @"product",
            @"accessoryIDs": @"product", @"accessoryIds": @"product", @"itemIDs": @"product",
            @"medicineIDs": @"medicine", @"medicineIds": @"medicine", @"medicine_ids": @"medicine",
            @"serviceIDs": @"service", @"serviceIds": @"service", @"service_ids": @"service"
        };
        [keyKinds enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *kind, BOOL *stop) {
            [self pp_appendNovaSuggestionRefsFromIDs:data[key] kind:kind toRefs:refs];
        }];

        NSDictionary<NSString *, NSString *> *arrayKeyKinds = @{
            @"suggestions": @"", @"recommendations": @"", @"results": @"",
            @"products": @"product", @"items": @"product",
            @"services": @"service", @"medicines": @"medicine"
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
    if ([self pp_novaStringFromDictionary:dict keys:@[@"serviceID", @"serviceId", @"service_id"]].length > 0) {
        return @"service";
    }
    if ([self pp_novaStringFromDictionary:dict keys:@[@"medicineID", @"medicineId", @"medicine_id"]].length > 0) {
        return @"medicine";
    }
    if ([self pp_novaStringFromDictionary:dict keys:@[@"productID", @"productId", @"product_id", @"accessoryID", @"accessoryId", @"accessory_id"]].length > 0) {
        return @"product";
    }

    id rawKindValue = dict[@"kind"] ?: dict[@"itemType"] ?: dict[@"collection"] ?: dict[@"collectionName"] ?: dict[@"type"];
    NSString *rawKind = [[self pp_novaStringFromValue:rawKindValue] lowercaseString];
    if ([rawKind containsString:@"service"]) {
        return @"service";
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
    NSArray<NSString *> *primaryKeys = [kind isEqualToString:@"service"]
        ? @[@"serviceID", @"serviceId", @"service_id"]
        : ([kind isEqualToString:@"medicine"]
           ? @[@"medicineID", @"medicineId", @"medicine_id", @"productID", @"productId", @"product_id", @"accessoryID", @"accessoryId", @"accessory_id"]
           : @[@"productID", @"productId", @"product_id", @"accessoryID", @"accessoryId", @"accessory_id"]);
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
        @{@"kind": @"medicine", @"pattern": @"\\[MEDICINE_ID:\\s*([^\\]]+)\\]"}
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
         [normalized hasPrefix:@"petAccessories/"] ||
         [normalized hasPrefix:@"serviceOffers/"])) {
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
    for (NSDictionary<NSString *, NSString *> *ref in refs) {
        NSString *kind = ref[@"kind"];
        NSString *identifier = ref[@"id"];
        if (identifier.length == 0) {
            continue;
        }
        if ([kind isEqualToString:@"service"]) {
            [serviceIDs addObject:identifier];
        } else {
            [accessoryIDs addObject:identifier];
        }
    }

    dispatch_group_t group = dispatch_group_create();
    __block NSArray<PetAccessory *> *resolvedAccessories = @[];
    __block NSArray<ServiceModel *> *resolvedServices = @[];
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
        NSMutableArray *objects = [NSMutableArray array];
        for (NSDictionary<NSString *, NSString *> *ref in refs) {
            NSString *identifier = ref[@"id"];
            id object = [ref[@"kind"] isEqualToString:@"service"] ? servicesByID[identifier] : accessoriesByID[identifier];
            if (object) {
                [objects addObject:object];
            }
        }

        if (objects.count == 0) {
            LOG_WARN(@"[PPNovaChat] Nova returned %lu suggestion ref(s) but none resolved: %@",
                     (unsigned long)refs.count, refs);

            [PPAnalytics logNovaShowcaseResolutionFailedWithRequestedCount:refs.count
                                                              resolvedCount:0
                                                                  sessionID:self.novaSessionId];

            [self pp_fetchAndShowLocalNovaShowcaseForUserText:userText completion:^(BOOL didShow) {
                if (didShow) {
                    return;
                }

                NSString *message = fallbackText.length > 0 ? fallbackText : kLang(@"nova_suggestions_unavailable");
                if (message.length == 0) {
                    return;
                }

                BOOL previousWasSameRecovery = NO;
                if (self.messages.count > 0) {
                    ChatMessageModel *lastMsg = self.messages.lastObject;
                    if ([lastMsg.senderID isEqualToString:@"nova_bot_id"] &&
                        lastMsg.messageType == ChatMessageTypeText &&
                        [lastMsg.text isEqualToString:message]) {
                        previousWasSameRecovery = YES;
                    }
                }

                if (!previousWasSameRecovery) {
                    [self addNovaMessage:message];
                }
            }];
            return;
        }

        [self pp_showNovaSuggestionObjects:objects];
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

    [PPAnalytics logNovaShowcaseShownWithItemCount:objects.count
                                          sessionID:self.novaSessionId
                                             source:source];
}

- (void)pp_fetchAndShowLocalNovaShowcaseForUserText:(NSString *)userText
                                         completion:(void (^)(BOOL didShow))completion
{
    NSString *trimmedText = [userText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    [self pp_updateMemoryFromUserText:trimmedText];

    if (![self pp_shouldAttemptLocalNovaShowcaseForUserText:trimmedText] || [self pp_lastMessageIsNovaShowcase]) {
        if (completion) completion(NO);
        return;
    }

    NSString *need = [self pp_localNovaNeedLabelFromUserText:trimmedText] ?: self.novaMemoryNeed;
    AccessKindType kind = [self pp_localNovaShowcaseKindForNeed:need];
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
                                                                        limit:6];
        if (ranked.count == 0) {
            if (completion) completion(NO);
            return;
        }

        [self pp_showNovaSuggestionObjects:ranked source:@"local"];
        if (completion) completion(YES);
    }];
}

- (BOOL)pp_shouldAttemptLocalNovaShowcaseForUserText:(NSString *)userText {
    NSString *lower = [userText.lowercaseString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (lower.length == 0) {
        return NO;
    }

    NSArray<NSString *> *productKeywords = @[
        @"product", @"products", @"item", @"items", @"accessory", @"accessories",
        @"food", @"medicine", @"vitamin", @"toy", @"cage", @"carrier", @"litter",
        @"buy", @"shop", @"recommend", @"suggest", @"show me",
        @"منتج", @"منتجات", @"اكسسوار", @"إكسسوار", @"أكل", @"اكل", @"طعام",
        @"دواء", @"أدوية", @"ادوية", @"فيتامين", @"لعبة", @"لعبه", @"قفص",
        @"رمل", @"اشتري", @"شراء", @"رشح", @"اقترح", @"اعرض"
    ];
    if ([self pp_string:lower containsAnyNovaKeyword:productKeywords]) {
        return YES;
    }

    NSArray<NSString *> *continuationKeywords = @[
        @"yes", @"yeah", @"ok", @"okay", @"sure", @"show", @"recommend", @"suggest",
        @"نعم", @"تمام", @"اوكي", @"أوكي", @"اعرض", @"رشح", @"اقترح"
    ];
    if (self.novaMemoryNeed.length > 0 && [self pp_string:lower containsAnyNovaKeyword:continuationKeywords]) {
        return YES;
    }

    NSArray<NSString *> *shoppingIntentKeywords = @[
        @"need", @"want", @"looking for", @"find", @"أحتاج", @"احتاج", @"أريد",
        @"اريد", @"ابي", @"أبي", @"ابغى", @"عايز"
    ];
    return self.novaMemoryPetType.length > 0 && [self pp_string:lower containsAnyNovaKeyword:shoppingIntentKeywords];
}

- (AccessKindType)pp_localNovaShowcaseKindForNeed:(NSString *)needLabel {
    NSString *need = needLabel.lowercaseString ?: @"";
    if ([need isEqualToString:@"food"]) {
        return AccessTypeFood;
    }
    if ([need isEqualToString:@"medicine"]) {
        return AccessTypePetMedicine;
    }
    return AccessTypeAccessory;
}

- (NSArray<PetAccessory *> *)pp_rankedLocalNovaAccessories:(NSArray<PetAccessory *> *)accessories
                                                  userText:(NSString *)userText
                                                      need:(NSString *)need
                                                     limit:(NSUInteger)limit
{
    NSMutableArray<PetAccessory *> *candidates = [NSMutableArray array];
    for (PetAccessory *item in accessories) {
        if (![item isKindOfClass:PetAccessory.class] || item.accessoryID.length == 0) {
            continue;
        }
        [candidates addObject:item];
    }
    if (candidates.count == 0) {
        return @[];
    }

    NSArray<PetAccessory *> *sorted = [candidates sortedArrayUsingComparator:^NSComparisonResult(PetAccessory *left, PetAccessory *right) {
        NSInteger leftScore = [self pp_localNovaAccessoryScore:left userText:userText need:need];
        NSInteger rightScore = [self pp_localNovaAccessoryScore:right userText:userText need:need];
        if (leftScore > rightScore) return NSOrderedAscending;
        if (leftScore < rightScore) return NSOrderedDescending;

        NSDate *leftDate = [left.createdAt isKindOfClass:NSDate.class] ? left.createdAt : NSDate.distantPast;
        NSDate *rightDate = [right.createdAt isKindOfClass:NSDate.class] ? right.createdAt : NSDate.distantPast;
        return [rightDate compare:leftDate];
    }];

    NSUInteger count = MIN(limit, sorted.count);
    return [sorted subarrayWithRange:NSMakeRange(0, count)];
}

- (NSInteger)pp_localNovaAccessoryScore:(PetAccessory *)item userText:(NSString *)userText need:(NSString *)needLabel {
    NSString *haystack = [[NSString stringWithFormat:@"%@ %@",
                           item.name ?: @"",
                           item.desc ?: @""] lowercaseString];
    NSString *need = needLabel.lowercaseString ?: @"";
    NSString *petType = self.novaMemoryPetType.lowercaseString ?: @"";
    NSInteger score = 0;

    if (item.quantity > 0) score += 2;
    if (item.imageURLsArray.count > 0) score += 1;
    if ([self pp_string:haystack containsAnyNovaKeyword:[self pp_localNovaKeywordsForNeed:need]]) score += 8;
    if ([self pp_string:haystack containsAnyNovaKeyword:[self pp_localNovaKeywordsForPetType:petType]]) score += 5;
    if ([self pp_string:haystack containsAnyNovaKeyword:[self pp_tokenKeywordsFromUserText:userText]]) score += 3;
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
    return @"";
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
            if (self.novaMemoryPetType.length == 0) {
                self.novaMemoryPetType = p[@"label"];
            }
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
            if (self.novaMemoryNeed.length == 0) {
                self.novaMemoryNeed = n[@"label"];
            }
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
    // The current prompt is passed in the 'prompt' field, so we skip the very last message here.
    NSInteger total = self.messages.count;
    NSInteger start = MAX(0, total - 7);
    for (NSInteger i = start; i < total; i++) {
        if (i == total - 1) continue;
        ChatMessageModel *msg = self.messages[i];

        // Product turns are not text — replace with a synthetic model-side marker so the
        // LLM retains the context that it just showed the user N products. Without this,
        // a "yes"/"the second one" follow-up loses its referent.
        if (msg.messageType == ChatMessageTypeNovaProduct ||
            msg.messageType == ChatMessageTypeNovaProductList) {
            NSInteger n = (NSInteger)msg.novaProducts.count;
            NSMutableArray *names = [NSMutableArray array];
            for (NSInteger pidx = 0; pidx < MIN(n, 4); pidx++) {
                id object = msg.novaProducts[pidx];
                NSString *name = [self pp_novaDisplayNameForSuggestionObject:object];
                if (name.length > 0) [names addObject:name];
            }
            NSString *marker;
            if (names.count > 0) {
                marker = [NSString stringWithFormat:@"[Nova showed %ld product%@: %@]",
                          (long)n, n == 1 ? @"" : @"s",
                          [names componentsJoinedByString:@", "]];
            } else {
                marker = [NSString stringWithFormat:@"[Nova showed %ld product%@]",
                          (long)n, n == 1 ? @"" : @"s"];
            }
            [history addObject:@{
                @"role": @"model",
                @"parts": @[@{ @"text": marker }]
            }];
            continue;
        }

        if (msg.messageType != ChatMessageTypeText) continue;

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
    header.clipsToBounds = YES;
    header.layer.shadowColor = UIColor.blackColor.CGColor;
    header.layer.shadowOpacity = 0.04;
    header.layer.shadowRadius = 18.0;
    header.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    [self.view addSubview:header];
    self.novaHeaderView = header;

    UIView *contentView = header.contentView;
    contentView.clipsToBounds = YES;

    LOTAnimationView *backgroundLottie = [[LOTAnimationView alloc] init];
    backgroundLottie.translatesAutoresizingMaskIntoConstraints = NO;
    backgroundLottie.userInteractionEnabled = NO;
    backgroundLottie.contentMode = UIViewContentModeScaleAspectFill;
    backgroundLottie.loopAnimation = YES;
    backgroundLottie.animationSpeed = 1.0;
    backgroundLottie.alpha = 0.0;
    [contentView addSubview:backgroundLottie];
    [contentView sendSubviewToBack:backgroundLottie];
    self.novaHeaderBackgroundLottie = backgroundLottie;

    [NSLayoutConstraint activateConstraints:@[
        [backgroundLottie.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [backgroundLottie.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [backgroundLottie.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [backgroundLottie.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor]
    ]];

    __weak typeof(self) wself = self;
    [AppClasses setAnimationNamed:@"novabg3"
                           ToView:backgroundLottie
                        withSpeed:1.0
                       completion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wself) self = wself;
            if (!self || self.dismissed) return;
            if (success) {
                self.currentHeaderBgAnimationName = @"novabg3";
                [self.novaHeaderBackgroundLottie play];
                [UIView animateWithDuration:0.55
                                      delay:0.08
                     usingSpringWithDamping:0.88
                      initialSpringVelocity:0.2
                                    options:UIViewAnimationOptionCurveEaseOut
                                 animations:^{
                    self.novaHeaderBackgroundLottie.alpha = self.novaHeaderCollapsed ? 0.58 : 1.0;
                } completion:nil];
            }
        });
    }];

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

    LOTAnimationView *ringLottie = [[LOTAnimationView alloc] init];
    ringLottie.translatesAutoresizingMaskIntoConstraints = NO;
    ringLottie.userInteractionEnabled = NO;
    ringLottie.contentMode = UIViewContentModeScaleAspectFill;
    ringLottie.loopAnimation = YES;
    ringLottie.animationSpeed = 1.0;
    ringLottie.alpha = 0.0;
    ringLottie.layer.cornerRadius = 25.0;
    ringLottie.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        ringLottie.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [brandRing addSubview:ringLottie];
    self.novaRingBackgroundLottie = ringLottie;

    [NSLayoutConstraint activateConstraints:@[
        [ringLottie.topAnchor constraintEqualToAnchor:brandRing.topAnchor],
        [ringLottie.leadingAnchor constraintEqualToAnchor:brandRing.leadingAnchor],
        [ringLottie.trailingAnchor constraintEqualToAnchor:brandRing.trailingAnchor],
        [ringLottie.bottomAnchor constraintEqualToAnchor:brandRing.bottomAnchor]
    ]];

    [AppClasses setAnimationNamed:@"nova-ring-bg"
                           ToView:ringLottie
                        withSpeed:1.0
                       completion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wself) self = wself;
            if (!self || self.dismissed) return;
            if (success) {
                [self.novaRingBackgroundLottie play];
                [UIView animateWithDuration:0.42
                                      delay:0.12
                     usingSpringWithDamping:0.86
                      initialSpringVelocity:0.3
                                    options:UIViewAnimationOptionCurveEaseOut
                                 animations:^{
                    self.novaRingBackgroundLottie.alpha = 1.0;
                } completion:nil];
            }
        });
    }];

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
    self.headerNameLabel = nameLabel;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:PPFontCaption1 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [AppSecondaryTextClr colorWithAlphaComponent:0.92];
    subtitleLabel.text = kLang(@"nova_subtitle");
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    [contentView addSubview:subtitleLabel];
    self.headerSubtitleLabel = subtitleLabel;

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
    closeButton.accessibilityLabel = kLang(@"nova_close_accessibility");
    closeButton.accessibilityTraits = UIAccessibilityTraitButton;
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

    CGFloat topOffset = 22.0; // Sheet grabber clearance.
    self.novaHeaderExpandedBottomConstraint = [liveCapsule.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-14.0];
    self.novaHeaderCollapsedBottomConstraint = [brandRing.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-12.0];
    self.novaHeaderCollapsedBottomConstraint.active = NO;

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
    NSTimeInterval duration = (animated && !reduceMotion) ? 0.34 : 0.0;
    CGFloat textAlpha = collapsed ? 0.0 : 1.0;
    CGFloat capsuleAlpha = collapsed ? 0.0 : 1.0;
    CGAffineTransform textTransform = collapsed ? CGAffineTransformMakeTranslation(0.0, -8.0) : CGAffineTransformIdentity;

    void (^changes)(void) = ^{
        self.headerNameLabel.alpha = textAlpha;
        self.headerSubtitleLabel.alpha = textAlpha;
        self.headerLiveCapsule.alpha = capsuleAlpha;
        self.headerNameLabel.transform = textTransform;
        self.headerSubtitleLabel.transform = textTransform;
        self.headerLiveCapsule.transform = collapsed ? CGAffineTransformMakeTranslation(0.0, -10.0) : CGAffineTransformIdentity;
        self.novaHeaderBackgroundLottie.alpha = collapsed ? 0.58 : 1.0;
        [self pp_applyNovaTableInsetsForCurrentHeaderState];
        [self.view layoutIfNeeded];
        [self pp_refreshVisibleNovaCellLayoutForCurrentTableWidth];
    };

    if (duration <= 0.0) {
        changes();
        return;
    }

    [UIView animateWithDuration:duration
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:changes
                     completion:^(__unused BOOL finished) {
        [self pp_refreshVisibleNovaCellLayoutForCurrentTableWidth];
    }];
}

- (void)pp_applyNovaTableInsetsForCurrentHeaderState {
    if (!self.tableView) {
        return;
    }

    CGFloat topInset = self.novaHeaderCollapsed ? PPNovaCollapsedTableTopInset : PPNovaExpandedTableTopInset;
    UIEdgeInsets inset = self.tableView.contentInset;
    inset.top = topInset;
    inset.bottom = PPNovaTableBottomInset;
    self.tableView.contentInset = inset;
    self.tableView.scrollIndicatorInsets = inset;
}

- (void)pp_handleNovaCloseTapped:(__unused UIButton *)sender {
    [self.view endEditing:YES];
    [self dismissViewControllerAnimated:YES completion:nil];
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

- (void)pp_transitionHeaderBackgroundToAnimation:(NSString *)animationName {
    if (!self.novaHeaderBackgroundLottie) return;
    if ([self.currentHeaderBgAnimationName isEqualToString:animationName]) return;

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
                if (success) {
                    [self.novaHeaderBackgroundLottie play];
                    [UIView animateWithDuration:0.38
                                          delay:0.06
                         usingSpringWithDamping:0.84
                          initialSpringVelocity:0.3
                                        options:UIViewAnimationOptionCurveEaseOut
                                     animations:^{
                        self.novaHeaderBackgroundLottie.alpha = self.novaHeaderCollapsed ? 0.58 : 0.38;
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

    NSInteger roll = arc4random_uniform(5) + 1;
    NSString *thinkingAnim = [NSString stringWithFormat:@"novabg%ld", (long)roll];
    [self pp_transitionHeaderBackgroundToAnimation:thinkingAnim];

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

    [self pp_transitionHeaderBackgroundToAnimation:@"novabg1"];

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

    UIViewAnimationOptions options = ((UIViewAnimationOptions)curve << 16) |
        UIViewAnimationOptionBeginFromCurrentState |
        UIViewAnimationOptionAllowUserInteraction;
    [UIView animateWithDuration:duration delay:0.0 options:options animations:^{
        [self.view layoutIfNeeded];
        [self pp_refreshVisibleNovaCellLayoutForCurrentTableWidth];
    } completion:^(BOOL finished) {
        [self pp_refreshVisibleNovaCellLayoutForCurrentTableWidth];
        [self scrollToBottomAnimated:NO];
    }];
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

    PPNovaMessageBubbleCell *cell = [tableView dequeueReusableCellWithIdentifier:[PPNovaMessageBubbleCell reuseIdentifier] forIndexPath:indexPath];
    [cell configureWithMessage:msg maxWidth:[self pp_novaMessageLayoutWidthForTableView:tableView]];

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < 0 || indexPath.row >= (NSInteger)self.messages.count) {
        return 92.0;
    }
    ChatMessageModel *msg = self.messages[indexPath.row];
    if (msg.messageType == ChatMessageTypeNovaProduct || msg.messageType == ChatMessageTypeNovaProductList) {
        return 335.0;
    }
    if (msg.messageType == ChatMessageTypeNovaReview) {
        return 120.0;
    }
    return 92.0;
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

        if (![visibleCell isKindOfClass:PPNovaMessageBubbleCell.class]) continue;

        PPNovaMessageBubbleCell *cell = (PPNovaMessageBubbleCell *)visibleCell;
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        if (indexPath.row < 0 || indexPath.row >= self.messages.count) continue;

        ChatMessageModel *message = self.messages[indexPath.row];
        [cell configureWithMessage:message maxWidth:tableWidth];
    }
}

- (void)pp_refreshVisibleNovaCellLayoutForCurrentTableWidth {
    CGFloat width = [self pp_novaMessageLayoutWidthForTableView:self.tableView];
    [self pp_updateVisibleNovaMessageCellWidthsForTableWidth:width];
    [self.tableView beginUpdates];
    [self.tableView endUpdates];
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
    [UIView animateWithDuration:0.18 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        [self.view layoutIfNeeded];
        [self pp_refreshVisibleNovaCellLayoutForCurrentTableWidth];
    } completion:^(__unused BOOL finished) {
        [self pp_refreshVisibleNovaCellLayoutForCurrentTableWidth];
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

    [self showNovaTyping];
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

- (void)addMessageWithText:(NSString *)text isIncoming:(BOOL)isIncoming {
    ChatMessageModel *msg = [[ChatMessageModel alloc] init];
    msg.ID = [[NSUUID UUID] UUIDString];
    msg.text = text;
    msg.timestamp = [NSDate date];
    msg.status = ChatMessageStatusSent;
    msg.messageType = ChatMessageTypeText;
    msg.senderID = isIncoming ? @"nova_bot_id" : [UserManager sharedManager].currentUser.ID;

    [self.messages addObject:msg];
    [self pp_trimMessageHistoryIfNeeded];
    [self updateNovaEmptyStateAnimated:YES];
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
        @"\\[MEDICINE_ID:\\s*[^\\]]+\\]"
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
    [NSRegularExpression regularExpressionWithPattern:@"[^\\.\\n!؟\\?]*(?:\\[PRODUCT_ID:|\\[SERVICE_ID:|\\[MEDICINE_ID:)[^\\.\\n!؟\\?]*[\\.\\n!؟\\?]?"
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
        [lower containsString:@"medicine_ids"]) {
        return YES;
    }
    NSArray<NSString *> *headers = @[
        @"curated picks", @"suggestions", @"suggestion", @"recommended products",
        @"recommended items", @"recommended services", @"products", @"services", @"medicines",
        @"اختيارات", @"اختيارات مناسبة", @"اقتراحات", @"الاقتراحات",
        @"منتجات", @"المنتجات", @"خدمات", @"الخدمات", @"أدوية", @"الأدوية"
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
