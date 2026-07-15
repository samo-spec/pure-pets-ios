//
//  ChMessagingController 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/07/2025.
//

// ChMessagingController.m
// Pure Pets
static BOOL PPChatShowLog = NO; // ⬅️ change to YES to enable chat logs
static const NSInteger PPChatInitialMessagePageLimit = 50;
static const NSInteger PPChatMessagePageStep = 50;
static const NSTimeInterval PPChatUnsendWindow = 15.0 * 60.0;
static const NSInteger PPChatReplyIndicatorTag = 0x50505250;
static const CGFloat PPChatReplyPanCommitDistance = 72.0;
static const CGFloat PPChatReplyPanMaxDistance = 96.0;
static NSString * const PPChatReplyPanName = @"pp.chat.reply.pan";
static NSString * const PPChatDismissPanName = @"pp.chat.dismiss.pan";

#define PPChatLog(fmt, ...) \
do { \
    if (PPChatShowLog) { \
        NSLog((fmt), ##__VA_ARGS__); \
    } \
} while (0)


#import "ChMessagingController.h"
#import "ChatImageMessageCell.h"
#import "ChatVideoMessageCell.h"
#import "PPChatsFunc.h"
 
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "PPFullscreenVideoController.h"
 #import "ChTypingController.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "ChMessagingController+helper.h"
#import "WaveformGenerator.h"
#import "PPMediaPreviewController.h"
#import "PPHUD.h"
#import "PPChatFeedbackManager.h"
#import "PPStoriesManager.h"
#import "PPStoryPlayerViewController.h"
#import "PPPermissionHelper.h"
#import "PPImageLoaderManager.h"
#import "PPModernAvatarRenderer.h"
#import "PPFirebaseSessionBridge.h"
#import "FullScreenImageViewerController.h"
#import "PPHeroGlassBackgroundView.h"
#import "Pure_Pets-Swift.h"


static CGFloat ChatMediaHeight(CGFloat maxWidth,
                               CGFloat mediaWidth,
                               CGFloat mediaHeight)
{
    if (mediaWidth <= 0 || mediaHeight <= 0) {
        return 200.0;
    }

    CGFloat ratio = mediaHeight / mediaWidth;
    CGFloat height = maxWidth * ratio;

    // Clamp (WhatsApp-like)
    height = MAX(140.0, MIN(height, 420.0));
    return height;
}

static UIImage * _Nullable ChatPreparedImageForUpload(UIImage * _Nullable image,
                                                       CGFloat maxDimension)
{
    if (!image) return nil;
    if (maxDimension <= 0) return image;

    CGSize originalSize = image.size;
    CGFloat longestEdge = MAX(originalSize.width, originalSize.height);
    if (longestEdge <= 0 || longestEdge <= maxDimension) {
        return image;
    }

    CGFloat scale = maxDimension / longestEdge;
    CGSize targetSize = CGSizeMake(MAX(1, floor(originalSize.width * scale)),
                                   MAX(1, floor(originalSize.height * scale)));

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;
    format.scale = 1.0;

    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:targetSize format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        [image drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
    }];
}

static BOOL PPChatRequiresBelowIOS26StorageCredentialPreflight(void)
{
    if (@available(iOS 26.0, *)) {
        return NO;
    }
    return YES;
}

static void PPChatEnsureBelowIOS26StorageCredentialReadiness(void (^completion)(NSError * _Nullable authError))
{
    [PPFirebaseSessionBridge ensureFreshAuthSessionForcingRefresh:NO completion:completion];
}

static NSString *PPChatLocalizedStringOrFallback(NSString *key, NSString *fallbackKey)
{
    NSString *value = kLang(key);
    if (value.length > 0 && ![value isEqualToString:key]) {
        return value;
    }

    NSString *fallback = fallbackKey.length > 0 ? kLang(fallbackKey) : nil;
    if (fallback.length > 0 && ![fallback isEqualToString:fallbackKey]) {
        return fallback;
    }

    return @"";
}

static NSString * const PPChatPremiumHeaderSupportAvatarToken = @"purepets://support-logo";
static const CGFloat PPChatPremiumModalHeaderCornerRadius = 26.0;

static BOOL PPChatPremiumHeaderUsesSupportLogo(UserModel * _Nullable user)
{
    NSString *avatarURL = user.UserImageUrl.absoluteString ?: @"";
    return [avatarURL hasPrefix:PPChatPremiumHeaderSupportAvatarToken];
}

static UIImage *PPChatPremiumHeaderSupportLogoImage(void)
{
    return [UIImage imageNamed:@"PPLogo"] ?: [UIImage systemImageNamed:@"person.crop.circle.fill"];
}

static UIColor *PPChatPremiumHeaderControlSurfaceColor(void)
{
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        return dark
            ? [UIColor colorWithWhite:1.0 alpha:0.10]
            : [UIColor colorWithWhite:0.0 alpha:0.045];
    }];
}

static UIColor *PPChatPremiumHeaderBorderColor(void)
{
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        return dark
            ? [UIColor colorWithWhite:1.0 alpha:0.12]
            : [UIColor colorWithWhite:0.0 alpha:0.07];
    }];
}

static UIColor *PPChatPremiumHeaderSecondaryTextColor(void)
{
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        return dark
            ? [UIColor colorWithWhite:1.0 alpha:0.58]
            : [UIColor colorWithWhite:0.0 alpha:0.50];
    }];
}

static UIColor *PPChatPremiumHeaderSurfaceOverlayColor(void)
{
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        return dark
            ? [UIColor colorWithWhite:0.0 alpha:0.20]
            : [UIColor colorWithWhite:1.0 alpha:0.32];
    }];
}

static UIColor *PPChatEmptyStateSurfaceColor(void)
{
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        return dark
            ? [UIColor colorWithWhite:0.08 alpha:0.70]
            : [UIColor colorWithWhite:1.0 alpha:0.74];
    }];
}

static UIColor *PPChatEmptyStateIconSurfaceColor(void)
{
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        return dark
            ? [UIColor colorWithWhite:1.0 alpha:0.08]
            : [UIColor colorWithWhite:0.0 alpha:0.045];
    }];
}

static UIColor *PPChatAmbientBackgroundColor(UITraitCollection *traitCollection)
{
    return [PPChatsFunc chatCanvasBackgroundColor];
}



@interface ChMessagingController () <UITableViewDelegate, UITableViewDataSource,
                                     UITextFieldDelegate,
                                     UITextViewDelegate, AVAudioPlayerDelegate,PPChatInputBarViewDelegate, AVAudioRecorderDelegate, AVAudioPlayerDelegate,
                                     UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIGestureRecognizerDelegate,
                                     ChatMessageCellDelegate, ChatImageMessageCellDelegate, PPNovaSwiftUIChatBarViewControllerDelegate>

@property (nonatomic, strong) PPNovaSwiftUIChatBarViewController *swiftUIInputVC;
@property (nonatomic, assign) BOOL useSwiftUIInputBar;
@property (nonatomic, strong) NSLayoutConstraint *swiftUIInputBarBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *swiftUIInputBarHeightConstraint;
@property (nonatomic, assign) NSTimeInterval swiftUIRecordingDuration;

@property (nonatomic, assign) BOOL isObservingMessages;
@property (nonatomic, assign) BOOL didFinishInitialLoad;
@property (nonatomic, assign) NSInteger messagePageLimit;
@property (nonatomic, assign) BOOL isExpandingMessagePage;
@property (nonatomic, assign) CGFloat previousContentHeightBeforeExpansion;
@property (nonatomic, assign) CGFloat previousContentOffsetYBeforeExpansion;
@property (nonatomic, assign) NSInteger lastMessageCount;
@property (nonatomic, strong) NSArray<NSString *> *lastMessageIDs;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *lastKnownStatuses;
@property (nonatomic, strong) id<FIRListenerRegistration> messageListener;


@property (nonatomic, assign) CGFloat fixedMediaMaxWidth;
@property (nonatomic, strong) UIButton *navBottomBlurView;
- (BOOL)isNearBottom;
 @property (nonatomic, strong) PPAmazingBar *amazingBar;
 @property (nonatomic, assign) BOOL isViewVisible;
@property (nonatomic, assign) BOOL isKeyboardVisible;
@property (nonatomic, strong) ChTypingController *typingController;
 @property (nonatomic, strong) UserModel *threadOtherUser;
 @property (nonatomic, assign) BOOL didMarkMessagesAsRead;
@property (nonatomic, assign) CGFloat currentKeyboardHeight;
@property (nonatomic, assign) BOOL keyboardObserversAdded;
@property (nonatomic, assign) UIEdgeInsets baseTableInsets;
@property (nonatomic, assign) BOOL previousIQEnabled;
@property (nonatomic, assign) BOOL previousToolbarEnabled;
@property (nonatomic, strong) NSTimer *silenceTimer;
@property (nonatomic, strong)  UIView *bottomFill;
@property (nonatomic, strong) NSLayoutConstraint *inputBarBottomConstraint;
@property (nonatomic, strong) UIButton *scrollToBottomButton;
@property (nonatomic, strong) UIButton *bottomFillBlurView;
@property (nonatomic, strong) UIView *chatBackgroundContainer;
@property (nonatomic, strong) UIImageView *chatBackgroundImageView;

@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *cachedHeights;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> userStatusListener;
@property (nonatomic, strong) UIActivityIndicatorView *initialLoadIndicator;
@property (nonatomic, strong) UIView *chatEmptyStateView;
@property (nonatomic, strong) UIVisualEffectView *chatEmptyStateBlurView;
@property (nonatomic, strong) UIView *chatEmptyStateIconContainerView;
@property (nonatomic, strong) UIImageView *chatEmptyStateIconView;
@property (nonatomic, strong) UILabel *chatEmptyStateTitleLabel;
@property (nonatomic, strong) UILabel *chatEmptyStateSubtitleLabel;
@property (nonatomic, strong) UIButton *chatEmptyStateActionButton;
@property (nonatomic, assign) BOOL isChatEmptyStateVisible;
@property (nonatomic, assign) BOOL isPresentingFailureAlert;
@property (nonatomic, assign) BOOL isSchedulingMessageResubscribe;
@property (nonatomic, assign) NSUInteger initialLoadVisibilityToken;
@property (nonatomic, assign) BOOL pendingBottomScrollAfterLayout;
@property (nonatomic, assign) BOOL isOpeningHeaderStory;
@property (nonatomic, strong) UIView *premiumModalHeaderView;
@property (nonatomic, strong) PPHeroGlassBackgroundView *premiumModalHeaderGlassBackgroundView;
@property (nonatomic, strong) UIButton *premiumModalHeaderCloseButton;
@property (nonatomic, strong) UIButton *premiumModalHeaderMoreButton;
@property (nonatomic, strong) UIControl *premiumModalHeaderProfileControl;
@property (nonatomic, strong) UIImageView *premiumModalHeaderAvatarView;
@property (nonatomic, strong) UIView *premiumModalHeaderStatusDotView;
@property (nonatomic, strong) UILabel *premiumModalHeaderNameLabel;
@property (nonatomic, strong) UILabel *premiumModalHeaderStatusLabel;
@property (nonatomic, strong) NSLayoutConstraint *premiumModalHeaderTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *premiumModalHeaderHeightConstraint;
@property (nonatomic, assign) BOOL didCaptureNotificationHandoff;
@property (nonatomic, assign) BOOL didAnimatePremiumModalHeader;
@property (nonatomic, copy) NSString *premiumModalHeaderAvatarUserID;
@property (nonatomic, copy) NSString *premiumModalHeaderAvatarURLString;
@property (nonatomic, strong, nullable) ChatMessageModel *replyingToMessage;
@property (nonatomic, weak, nullable) UITableViewCell *activeReplyGestureCell;
@property (nonatomic, assign) BOOL replyGesturePassedThreshold;
@property (nonatomic, strong) NSMutableSet<NSString *> *unsendingMessageIDs;
- (NSString *)resolvedOtherUserID;
- (NSString *)resolvedOtherUserPresenceID;
- (CGFloat)pp_activeComposerOcclusionHeight;
- (void)pp_applyTableViewBottomInsetForActiveComposer;
- (CGFloat)pp_visibleNotificationHandoffBottomNavigationClearance;
- (CGFloat)pp_restingInputBarBottomConstant;
- (CGFloat)pp_restingSwiftUIInputBarBottomConstant;
- (void)pp_updateInputBarBottomConstraintsForCurrentState;
- (void)pp_applyNotificationHandoffBottomNavigationVisibilityAnimated:(BOOL)animated;
- (void)pp_scrollTableViewToBottomWithoutAnimation;
- (void)pp_animateComposerHeightChange;
- (CGFloat)pp_expandedSwiftUIComposerHeight;
- (void)pp_presentUnsendConfirmationForMessage:(ChatMessageModel *)message
                                     sourceCell:(nullable UITableViewCell *)sourceCell;
- (void)pp_unsendMessage:(ChatMessageModel *)message
               sourceCell:(nullable UITableViewCell *)sourceCell;
@end

@implementation ChMessagingController


- (void)setupBottomFillBlur
{
    if (self.bottomFillBlurView) return;

    self.bottomFillBlurView = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleFixed configType:PPButtonConfigrationGlass];
    self.bottomFillBlurView.hidden = YES;
    
    UIButtonConfiguration *cfg = self.bottomFillBlurView.configuration;
    cfg.background.backgroundColor = [UIColor clearColor];
    cfg.baseBackgroundColor =[UIColor clearColor];
    self.bottomFillBlurView.configuration=cfg;
    
    //self.bottomFillBlurView.backgroundColor =  AppBackgroundClrDarker;
    //self.bottomFillBlurView.configuration.background.backgroundColor =  AppBackgroundClrDarker;
    //self.bottomFillBlurView.configuration.baseBackgroundColor =  AppBackgroundClrDarker;
    UIView *bottomBarView = [self pp_activeChatInputBarViewForLayout];
    [self.view insertSubview:self.bottomFillBlurView belowSubview:bottomBarView];

    [NSLayoutConstraint activateConstraints:@[
        // Fill ONLY the area below input bar
        [self.bottomFillBlurView.topAnchor constraintEqualToAnchor:bottomBarView.topAnchor],
        [self.bottomFillBlurView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bottomFillBlurView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bottomFillBlurView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}
- (UIColor *)captureBottomVisibleBubbleColor
{
    NSArray<NSIndexPath *> *visible = [self.tableView indexPathsForVisibleRows];
    if (visible.count == 0) return [PPChatsFunc chatCanvasBackgroundColor];

    // Sort to get the bottom-most visible cell
    NSIndexPath *bottomIndexPath =
        [[visible sortedArrayUsingComparator:^NSComparisonResult(NSIndexPath *a, NSIndexPath *b) {
            return a.row < b.row ? NSOrderedDescending : NSOrderedAscending;
        }] firstObject];

    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:bottomIndexPath];

    if ([cell conformsToProtocol:@protocol(PPChatBubbleColorProviding)]) {
        UIColor *color =
            [(id<PPChatBubbleColorProviding>)cell pp_bubbleBackgroundColor];

        return color ?: [PPChatsFunc chatCanvasBackgroundColor];
    }

    return [PPChatsFunc chatCanvasBackgroundColor];
}
- (BOOL)isPresentedModally
{
    if (self.presentingViewController) {
        return YES;
    }

    if (self.navigationController.presentingViewController &&
        self.navigationController.viewControllers.firstObject == self) {
        return YES;
    }

    return NO;
}

// MARK: - View Lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupChatBackground];
    //[self loadChatBackground];
    self.lastKnownStatuses = [NSMutableDictionary dictionary];
    self.cachedHeights = [NSMutableDictionary dictionary];
    self.unsendingMessageIDs = [NSMutableSet set];
    self.isPresentingFailureAlert = NO;
    self.didCaptureNotificationHandoff = [ChManager sharedManager].isHandlingNotificationHandoff;

    [IQKeyboardManager sharedManager].enable = NO;
    [IQKeyboardManager sharedManager].enableAutoToolbar = NO;
    self.typingAutoHideThreshold = 0.0; // px from bottom

    self.view.backgroundColor = [PPChatsFunc chatCanvasBackgroundColor];
    [self setupInputView];
    [self setupTableView];
    [self pp_setupPremiumEmptyStateIfNeeded];
    [self setupInitialLoadIndicator];
    CGFloat initialWidth = self.view.bounds.size.width > 0
        ? self.view.bounds.size.width
        : UIScreen.mainScreen.bounds.size.width;
    self.fixedMediaMaxWidth = MAX(160.0, initialWidth * 0.72);

    self.baseTableInsets = self.tableView.contentInset;
    
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;

    // 🔒 Critical: prevent UIKit from guessing heights (fixes shake)
    self.tableView.estimatedRowHeight = 0;
    self.tableView.estimatedSectionHeaderHeight = 0;
    self.tableView.estimatedSectionFooterHeight = 0;

    [self viewDidLoadRecordData];

    [self fetchInitForDidLoad];

    [self ensureThreadThen:^(NSString *threadID) { }];

    [self registerForKeyboardNotifications];
    [self registerAppStateObservers];
    
    [self enableSwipeToDismiss];
    
    [self setupScrollToBottomButton];
    
    [self setupEditorNotifications];
}

- (void)setupInitialLoadIndicator
{
    if (self.initialLoadIndicator) return;

    UIActivityIndicatorView *indicator =
        [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    indicator.translatesAutoresizingMaskIntoConstraints = NO;
    indicator.hidesWhenStopped = YES;
    indicator.color = AppPrimaryTextClr;
    [self.view addSubview:indicator];
    [NSLayoutConstraint activateConstraints:@[
        [indicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [indicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
    self.initialLoadIndicator = indicator;
    [self.initialLoadIndicator startAnimating];
}

- (void)pp_setupPremiumEmptyStateIfNeeded
{
    if (self.chatEmptyStateView) return;

    UIView *container = [UIView new];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    container.hidden = YES;
    container.alpha = 0.0;
    container.transform = [self pp_preparedEmptyStateTransform];
    container.accessibilityViewIsModal = NO;

    UIBlurEffect *blurEffect;
    if (@available(iOS 13.0, *)) {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    } else {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight];
    }

    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.clipsToBounds = YES;
    blurView.userInteractionEnabled = NO;

    UIView *contentView = [UIView new];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    contentView.userInteractionEnabled = YES;

    UIView *iconContainer = [UIView new];
    iconContainer.translatesAutoresizingMaskIntoConstraints = NO;
    iconContainer.clipsToBounds = YES;
    iconContainer.isAccessibilityElement = NO;

    UIImageSymbolConfiguration *iconConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:26.0
                                                        weight:UIImageSymbolWeightSemibold];
    UIImageView *iconView =
        [[UIImageView alloc] initWithImage:[PPSYSImage(@"bubble.left.and.bubble.right.fill")
                                             imageWithConfiguration:iconConfig]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.isAccessibilityElement = NO;

    UILabel *titleLabel = [UILabel new];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = kLang(@"chat_empty_thread_title");
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle3]
                       scaledFontForFont:([GM boldFontWithSize:22.0] ?: [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold])];
    titleLabel.adjustsFontForContentSizeCategory = YES;
    titleLabel.numberOfLines = 2;

    UILabel *subtitleLabel = [UILabel new];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.text = kLang(@"chat_empty_thread_subtitle");
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    subtitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
                          scaledFontForFont:([GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium])];
    subtitleLabel.adjustsFontForContentSizeCategory = YES;
    subtitleLabel.numberOfLines = 4;

    UIButton *actionButton =
        [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleCapsule
                                                         configType:PPButtonConfigrationGlass];
    actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    actionButton.accessibilityLabel = kLang(@"chat_empty_thread_action");
    actionButton.titleLabel.font = [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    [actionButton addTarget:self action:@selector(pp_chatEmptyStateActionTapped) forControlEvents:UIControlEventTouchUpInside];
    [actionButton addTarget:self action:@selector(pp_chatEmptyStateActionTouchDown:) forControlEvents:UIControlEventTouchDown];
    [actionButton addTarget:self action:@selector(pp_chatEmptyStateActionRelease:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];

    UIButtonConfiguration *buttonConfig = actionButton.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
    NSMutableDictionary<NSAttributedStringKey, id> *titleAttributes = [NSMutableDictionary dictionary];
    titleAttributes[NSFontAttributeName] = actionButton.titleLabel.font;
    titleAttributes[NSForegroundColorAttributeName] = AppPrimaryTextClr ?: UIColor.labelColor;
    buttonConfig.attributedTitle =
        [[NSAttributedString alloc] initWithString:kLang(@"chat_empty_thread_action")
                                        attributes:titleAttributes];
    buttonConfig.image = PPSYSImage(@"square.and.pencil");
    buttonConfig.imagePlacement = NSDirectionalRectEdgeLeading;
    buttonConfig.imagePadding = 8.0;
    buttonConfig.contentInsets = NSDirectionalEdgeInsetsMake(12.0, 16.0, 12.0, 16.0);
    buttonConfig.baseForegroundColor = AppPrimaryTextClr ?: UIColor.labelColor;
    buttonConfig.background.backgroundColor = UIColor.clearColor;
    buttonConfig.baseBackgroundColor = UIColor.clearColor;
    actionButton.configuration = buttonConfig;

    UIStackView *stackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        iconContainer,
        titleLabel,
        subtitleLabel,
        actionButton
    ]];
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.alignment = UIStackViewAlignmentCenter;
    stackView.spacing = 12.0;
    stackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [stackView setCustomSpacing:16.0 afterView:iconContainer];
    [stackView setCustomSpacing:8.0 afterView:titleLabel];
    [stackView setCustomSpacing:20.0 afterView:subtitleLabel];

    [self.view addSubview:container];
    [container addSubview:blurView];
    [container addSubview:contentView];
    [contentView addSubview:stackView];
    [iconContainer addSubview:iconView];

    NSLayoutConstraint *maxWidth = [container.widthAnchor constraintLessThanOrEqualToConstant:390.0];
    maxWidth.priority = UILayoutPriorityRequired;

    NSLayoutConstraint *leadingLimit = [container.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:24.0];
    NSLayoutConstraint *trailingLimit = [container.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-24.0];
    NSLayoutConstraint *topLimit = [container.topAnchor constraintGreaterThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:96.0];
    UIView *bottomBarView = [self pp_activeChatInputBarViewForLayout];
    NSLayoutConstraint *bottomLimit = [container.bottomAnchor constraintLessThanOrEqualToAnchor:bottomBarView.topAnchor constant:-24.0];

    [NSLayoutConstraint activateConstraints:@[
        [container.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [container.centerYAnchor constraintEqualToAnchor:self.tableView.centerYAnchor constant:-12.0],
        maxWidth,
        leadingLimit,
        trailingLimit,
        topLimit,
        bottomLimit,

        [blurView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],

        [contentView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],

        [stackView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:26.0],
        [stackView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24.0],
        [stackView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24.0],
        [stackView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-24.0],

        [iconContainer.widthAnchor constraintEqualToConstant:64.0],
        [iconContainer.heightAnchor constraintEqualToConstant:64.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconContainer.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconContainer.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:32.0],
        [iconView.heightAnchor constraintEqualToConstant:32.0],

        [titleLabel.leadingAnchor constraintEqualToAnchor:stackView.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:stackView.trailingAnchor],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:stackView.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:stackView.trailingAnchor],
        [actionButton.heightAnchor constraintGreaterThanOrEqualToConstant:48.0]
    ]];

    self.chatEmptyStateView = container;
    self.chatEmptyStateBlurView = blurView;
    self.chatEmptyStateIconContainerView = iconContainer;
    self.chatEmptyStateIconView = iconView;
    self.chatEmptyStateTitleLabel = titleLabel;
    self.chatEmptyStateSubtitleLabel = subtitleLabel;
    self.chatEmptyStateActionButton = actionButton;

    self.chatEmptyStateView.accessibilityElements = @[titleLabel, subtitleLabel, actionButton];
    [self pp_applyPremiumEmptyStateTheme];
}

- (CGAffineTransform)pp_preparedEmptyStateTransform
{
    return CGAffineTransformScale(CGAffineTransformMakeTranslation(0.0, 12.0), 0.985, 0.985);
}

- (void)pp_applyPremiumEmptyStateTheme
{
    if (!self.chatEmptyStateView) return;

    self.chatEmptyStateView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.chatEmptyStateBlurView.backgroundColor = PPChatEmptyStateSurfaceColor();
    self.chatEmptyStateBlurView.layer.cornerRadius = 28.0;
    self.chatEmptyStateBlurView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.chatEmptyStateBlurView.layer.borderColor = PPChatPremiumHeaderBorderColor().CGColor;
    if (@available(iOS 13.0, *)) {
        self.chatEmptyStateBlurView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    self.chatEmptyStateIconContainerView.backgroundColor = PPChatEmptyStateIconSurfaceColor();
    self.chatEmptyStateIconContainerView.layer.cornerRadius = 22.0;
    self.chatEmptyStateIconContainerView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.chatEmptyStateIconContainerView.layer.borderColor = PPChatPremiumHeaderBorderColor().CGColor;
    if (@available(iOS 13.0, *)) {
        self.chatEmptyStateIconContainerView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIColor *accent = [PPChatsFunc chatNeutralAccentColor];
    self.chatEmptyStateIconView.tintColor = accent;
    self.chatEmptyStateTitleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    self.chatEmptyStateSubtitleLabel.textColor = AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
    self.chatEmptyStateActionButton.tintColor = AppPrimaryTextClr ?: UIColor.labelColor;
}

- (void)pp_updateChatEmptyStateAnimated:(BOOL)animated
{
    BOOL shouldShow =
        self.didFinishInitialLoad &&
        self.messages.count == 0 &&
        !self.initialLoadIndicator.isAnimating;
    [self pp_setChatEmptyStateVisible:shouldShow animated:animated];
}

- (void)pp_setChatEmptyStateVisible:(BOOL)visible animated:(BOOL)animated
{
    if (!self.chatEmptyStateView) return;

    if (visible) {
        [self pp_applyPremiumEmptyStateTheme];
        self.chatEmptyStateView.hidden = NO;
        [self.view bringSubviewToFront:self.chatEmptyStateView];
        [self.view bringSubviewToFront:self.typingIndicatorView];
        [self.view bringSubviewToFront:[self pp_activeChatInputBarViewForLayout]];
        [self pp_bringChatHeaderToFront];
    }

    if (self.isChatEmptyStateVisible == visible &&
        self.chatEmptyStateView.hidden == !visible) {
        return;
    }

    self.isChatEmptyStateVisible = visible;

    void (^changes)(void) = ^{
        self.chatEmptyStateView.alpha = visible ? 1.0 : 0.0;
        self.chatEmptyStateView.transform = visible ? CGAffineTransformIdentity : [self pp_preparedEmptyStateTransform];
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        changes();
        self.chatEmptyStateView.hidden = !visible;
        return;
    }

    if (visible) {
        self.chatEmptyStateView.alpha = 0.0;
        self.chatEmptyStateView.transform = [self pp_preparedEmptyStateTransform];
        [UIView animateWithDuration:0.42
                              delay:0.04
             usingSpringWithDamping:0.88
              initialSpringVelocity:0.35
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:changes
                         completion:nil];
    } else {
        [UIView animateWithDuration:0.20
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseInOut
                         animations:changes
                         completion:^(__unused BOOL finished) {
            if (!self.isChatEmptyStateVisible) {
                self.chatEmptyStateView.hidden = YES;
            }
        }];
    }
}

- (void)pp_chatEmptyStateActionTapped
{
    [self pp_focusChatComposer];
}

- (void)pp_chatEmptyStateActionTouchDown:(UIButton *)sender
{
    [UIView animateWithDuration:0.09
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        sender.transform = CGAffineTransformMakeScale(0.965, 0.965);
    } completion:nil];
}

- (void)pp_chatEmptyStateActionRelease:(UIButton *)sender
{
    [UIView animateWithDuration:0.18
                          delay:0.0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.45
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        sender.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_focusChatComposer
{
    if (self.useSwiftUIInputBar && self.swiftUIInputVC) {
        [self.swiftUIInputVC focusTextInput];
        return;
    }

    if (![self pp_focusFirstTextInputInView:self.inputbar]) {
        [self.inputbar becomeFirstResponder];
    }
}

- (BOOL)pp_focusFirstTextInputInView:(UIView *)view
{
    if (!view) return NO;

    if ([view conformsToProtocol:@protocol(UITextInput)] &&
        [view canBecomeFirstResponder]) {
        [view becomeFirstResponder];
        return YES;
    }

    for (UIView *subview in view.subviews) {
        if ([self pp_focusFirstTextInputInView:subview]) {
            return YES;
        }
    }

    return NO;
}






- (void)setInitialLoadingVisible:(BOOL)visible
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.initialLoadIndicator) return;
        if (visible && (self.didFinishInitialLoad || self.messages.count > 0)) {
            self.didFinishInitialLoad = YES;
            [self.initialLoadIndicator stopAnimating];
            [self pp_updateChatEmptyStateAnimated:YES];
            return;
        }
        if (visible) {
            self.initialLoadVisibilityToken += 1;
            NSUInteger token = self.initialLoadVisibilityToken;
            [self.initialLoadIndicator startAnimating];
            [self.view bringSubviewToFront:self.initialLoadIndicator];
            [self pp_setChatEmptyStateVisible:NO animated:YES];

            // Fail-safe: do not keep blocking loader forever if listener state gets stale.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(12.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                if (token != self.initialLoadVisibilityToken) return;
                if (self.didFinishInitialLoad) return;
                [self.initialLoadIndicator stopAnimating];
            });
        } else {
            self.initialLoadVisibilityToken += 1;
            [self.initialLoadIndicator stopAnimating];
            [self pp_updateChatEmptyStateAnimated:YES];
        }
    });
}

- (void)markThreadMessagesAsReadIfNeeded
{
    if (!self.isViewVisible) return;
    if (!self.chatThread.ID.length) return;

    self.didMarkMessagesAsRead = YES;
    [[ChManager sharedManager]
     markMessagesAsReadInThread:self.chatThread.ID
     fromUser:[self resolvedOtherUserID]];
}

- (void)activateRealtimeAfterInitialLoadIfNeeded
{
    if (!self.isViewVisible || !self.didFinishInitialLoad) return;

    NSString *presenceUserID = [self resolvedOtherUserPresenceID];
    if (presenceUserID.length > 0 && !self.userStatusListener) {
        [self observeUserStatus:presenceUserID];
    }

    [self markThreadMessagesAsReadIfNeeded];

    [self.typingController start];
}

- (NSString *)resolvedOtherUserID
{
    NSString *otherUserID = self.threadOtherUser.ID;
    if (otherUserID.length == 0) {
        otherUserID = self.chatThread.otherUser.ID;
    }
    if (otherUserID.length == 0) {
        NSString *currentUserID = [FIRAuth auth].currentUser.uid ?: UserManager.sharedManager.currentUser.ID ?: @"";
        for (NSString *candidate in self.chatThread.memberIDs ?: @[]) {
            if (![candidate isKindOfClass:NSString.class]) continue;
            if (candidate.length > 0 && ![candidate isEqualToString:currentUserID]) {
                otherUserID = candidate;
                break;
            }
        }
    }
    return otherUserID ?: @"";
}

- (NSString *)pp_currentOutgoingSenderID
{
    NSString *authUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (authUID.length > 0) {
        return authUID;
    }
    return UserManager.sharedManager.currentUser.ID ?: @"";
}

- (NSString *)pp_resolvedOutgoingReceiverIDForSenderID:(NSString *)senderID
{
    NSString *safeSenderID = senderID ?: @"";
    NSArray *members = self.chatThread.memberIDs ?: @[];
    BOOL hasKnownMembers = members.count > 0;
    BOOL (^candidateIsUsable)(NSString *) = ^BOOL(NSString *candidate) {
        if (candidate.length == 0 || [candidate isEqualToString:safeSenderID]) {
            return NO;
        }
        return !hasKnownMembers || [members containsObject:candidate];
    };

    NSString *receiverID = [self resolvedOtherUserID];
    if (candidateIsUsable(receiverID)) {
        return receiverID;
    }

    NSString *supportUserID = self.chatThread.supportUserID ?: @"";
    if (candidateIsUsable(supportUserID)) {
        return supportUserID;
    }

    for (NSString *candidate in members) {
        if (![candidate isKindOfClass:NSString.class]) continue;
        if (candidateIsUsable(candidate)) {
            return candidate;
        }
    }
    return @"";
}

- (BOOL)pp_applyOutgoingIdentityToMessage:(ChatMessageModel *)msg
{
    if (!msg) return NO;

    NSString *senderID = [self pp_currentOutgoingSenderID];
    NSString *receiverID = [self pp_resolvedOutgoingReceiverIDForSenderID:senderID];
    if (senderID.length == 0 ||
        receiverID.length == 0 ||
        [receiverID isEqualToString:senderID]) {
        NSLog(@"❌ [Chat] Invalid outgoing identity sender=%@ receiver=%@ thread=%@",
              senderID ?: @"",
              receiverID ?: @"",
              self.chatThread.ID ?: @"");
        return NO;
    }

    msg.senderID = senderID;
    msg.receiverID = receiverID;
    return YES;
}

- (NSString *)resolvedOtherUserPresenceID
{
    return [self resolvedOtherUserID];
}

- (void)startObservingMessagesIfNeeded
{
    if (!self.chatThread.ID.length) return;
    if (self.messageListener) return;

    // If flag says "observing" but listener is nil, recover from stale state.
    if (self.isObservingMessages) {
        self.isObservingMessages = NO;
    }

    [self observeMessages];
}

- (void)scheduleMessageResubscribe
{
    if (self.isSchedulingMessageResubscribe || !self.isViewVisible) return;
    self.isSchedulingMessageResubscribe = YES;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        self.isSchedulingMessageResubscribe = NO;
        if (!self.isViewVisible || self.messageListener || !self.chatThread.ID.length) {
            return;
        }
        [self startObservingMessagesIfNeeded];
    });
}
- (void)enableSwipeToDismiss
{
    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc]
         initWithTarget:self
                 action:@selector(handleSwipeToDismiss:)];

    pan.name = PPChatDismissPanName;
    pan.delegate = (id<UIGestureRecognizerDelegate>)self;
    [self.view addGestureRecognizer:pan];
}
- (void)handleSwipeToDismiss:(UIPanGestureRecognizer *)pan
{
    CGPoint translation = [pan translationInView:self.view];
    CGFloat progress = translation.y / self.view.bounds.size.height;
    progress = MAX(0, MIN(1, progress));

    switch (pan.state) {

        case UIGestureRecognizerStateChanged: {
            if (translation.y > 0) {
                self.view.transform =
                    CGAffineTransformMakeTranslation(0, translation.y);
            }
        } break;

        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {

            if (progress > 0.18) {
                [self dismissViewControllerAnimated:YES completion:nil];
            } else {
                [UIView animateWithDuration:0.25
                                 animations:^{
                    self.view.transform = CGAffineTransformIdentity;
                }];
            }
        } break;

        default:
            break;
    }
}
- (BOOL)isEmojiOnlyText:(NSString *)text
{
    if (text.length == 0) return NO;

    __block BOOL hasEmoji = NO;
    __block BOOL hasNonEmoji = NO;

    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *substring, NSRange range, NSRange enclosingRange, BOOL *stop) {

        if (substring.length == 0) return;

        const unichar hs = [substring characterAtIndex:0];
        BOOL isEmoji =
            (hs >= 0xD800 && hs <= 0xDBFF) || // surrogate
            (hs >= 0x2100 && hs <= 0x27BF);   // symbols

        if (isEmoji) {
            hasEmoji = YES;
        } else {
            NSString *trimmed =
                [substring stringByTrimmingCharactersInSet:
                 [NSCharacterSet whitespaceAndNewlineCharacterSet]];

            if (trimmed.length > 0) {
                hasNonEmoji = YES;
            }
        }
    }];

    return hasEmoji && !hasNonEmoji;
}
- (void)setupInputView {
    self.inputbar = [[PPChatInputBarView alloc] init];
    self.inputbar.delegate = self;

    self.inputbar.translatesAutoresizingMaskIntoConstraints = NO;
    self.inputbar.semanticContentAttribute = GM.setSemantic;
     
    [self.view addSubview:self.inputbar];
    
    
    self.inputBarBottomConstraint =
    [self.inputbar.bottomAnchor
     constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor];

    [NSLayoutConstraint activateConstraints:@[
        [self.inputbar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-2],
        [self.inputbar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:2],
        self.inputBarBottomConstraint
    ]];

    self.useSwiftUIInputBar = YES;
    self.swiftUIInputVC = [[PPNovaSwiftUIChatBarViewController alloc] init];
    self.swiftUIInputVC.delegate = (id<PPNovaSwiftUIChatBarViewControllerDelegate>)self;
    self.swiftUIInputVC.voiceEnabled = YES;
    [self addChildViewController:self.swiftUIInputVC];
    self.swiftUIInputVC.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.swiftUIInputVC.view];
    [self.swiftUIInputVC didMoveToParentViewController:self];

    self.swiftUIInputBarBottomConstraint =
        [self.swiftUIInputVC.view.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor
                                                               constant:-8.0];
    self.swiftUIInputBarHeightConstraint =
        [self.swiftUIInputVC.view.heightAnchor constraintEqualToConstant:54.0];
    [NSLayoutConstraint activateConstraints:@[
        [self.swiftUIInputVC.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:22.0],
        [self.swiftUIInputVC.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-22.0],
        self.swiftUIInputBarHeightConstraint,
        self.swiftUIInputBarBottomConstraint
    ]];

    self.swiftUIInputVC.view.hidden = !self.useSwiftUIInputBar;
    self.inputbar.hidden = self.useSwiftUIInputBar;
    /*self.bottomFill = [UIView new];
    self.bottomFill.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomFill.backgroundColor = AppBackgroundClrDarker;
    
    self.bottomFill.layer.cornerRadius = 0.0;
    self.bottomFill.layer.masksToBounds = NO;

    [self.bottomFill pp_setShadowColor:[UIColor blackColor]];
    self.bottomFill.layer.shadowOpacity = 0.01;
    self.bottomFill.layer.shadowRadius = 12;
    self.bottomFill.layer.shadowOffset = CGSizeMake(0, -6);
    

    [self.view insertSubview:self.bottomFill belowSubview:self.inputbar];

    [NSLayoutConstraint activateConstraints:@[
        [self.bottomFill.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bottomFill.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bottomFill.topAnchor constraintEqualToAnchor:self.inputbar.topAnchor],
        [self.bottomFill.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];*/
    [self setupBottomFillBlur];
}

- (UIView *)pp_activeChatInputBarViewForLayout
{
    if (self.useSwiftUIInputBar && self.swiftUIInputVC) {
        return self.swiftUIInputVC.view;
    }
    return self.inputbar;
}

- (UIView *)pp_visibleBottomNavigationAnchorView
{
    UITabBarController *tabBarController = self.tabBarController;
    SEL selector = @selector(pp_novaAmbientBottomNavigationAnchorView);
    if (!tabBarController || ![tabBarController respondsToSelector:selector]) {
        return nil;
    }

    UIView *(*anchorFunc)(id, SEL) = (UIView *(*)(id, SEL))[tabBarController methodForSelector:selector];
    if (!anchorFunc) {
        return nil;
    }

    UIView *anchorView = anchorFunc(tabBarController, selector);
    if (!anchorView ||
        !anchorView.superview ||
        anchorView.hidden ||
        anchorView.alpha <= 0.01 ||
        CGRectIsEmpty(anchorView.bounds)) {
        return nil;
    }
    return anchorView;
}

- (CGFloat)pp_visibleNotificationHandoffBottomNavigationClearance
{
    if (!self.keepsBottomNavigationVisibleForNotificationHandoff ||
        self.isKeyboardVisible ||
        CGRectIsEmpty(self.view.bounds)) {
        return 0.0;
    }

    UIView *anchorView = [self pp_visibleBottomNavigationAnchorView];
    if (!anchorView) {
        return 0.0;
    }

    CGRect anchorFrame = [anchorView.superview convertRect:anchorView.frame toView:self.view];
    if (CGRectIsEmpty(anchorFrame)) {
        return 0.0;
    }

    CGFloat safeBottomY = CGRectGetHeight(self.view.bounds) - self.view.safeAreaInsets.bottom;
    CGFloat overlapAboveSafeArea = MAX(0.0, safeBottomY - CGRectGetMinY(anchorFrame));
    return ceil(overlapAboveSafeArea + 10.0);
}

- (CGFloat)pp_restingInputBarBottomConstant
{
    return -[self pp_visibleNotificationHandoffBottomNavigationClearance];
}

- (CGFloat)pp_restingSwiftUIInputBarBottomConstant
{
    return -8.0 - [self pp_visibleNotificationHandoffBottomNavigationClearance];
}

- (void)pp_updateInputBarBottomConstraintsForCurrentState
{
    if (self.isKeyboardVisible) {
        return;
    }

    CGFloat inputConstant = [self pp_restingInputBarBottomConstant];
    CGFloat swiftConstant = [self pp_restingSwiftUIInputBarBottomConstant];

    if (self.inputBarBottomConstraint &&
        fabs(self.inputBarBottomConstraint.constant - inputConstant) > 0.5) {
        self.inputBarBottomConstraint.constant = inputConstant;
    }

    if (self.swiftUIInputBarBottomConstraint &&
        fabs(self.swiftUIInputBarBottomConstraint.constant - swiftConstant) > 0.5) {
        self.swiftUIInputBarBottomConstraint.constant = swiftConstant;
    }
}

- (void)pp_applyNotificationHandoffBottomNavigationVisibilityAnimated:(BOOL)animated
{
    if (!self.keepsBottomNavigationVisibleForNotificationHandoff) {
        return;
    }

    [[NSNotificationCenter defaultCenter]
        postNotificationName:PPShowSystemTabBarNotification
                      object:nil];

    UITabBarController *tabBarController = self.tabBarController;
    SEL selector = @selector(pp_setBottomNavigationHidden:animated:);
    if ([tabBarController respondsToSelector:selector]) {
        void (*setHiddenFunc)(id, SEL, BOOL, BOOL) =
            (void (*)(id, SEL, BOOL, BOOL))[tabBarController methodForSelector:selector];
        if (setHiddenFunc) {
            setHiddenFunc(tabBarController, selector, NO, animated);
        }
    }

    [self pp_updateInputBarBottomConstraintsForCurrentState];
}

- (void)scrollToBottomButtonTapped
{
    [self scrollToBottomAnimated:YES];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (![scrollView isEqual:self.tableView]) return;
    CGFloat topThreshold = -scrollView.adjustedContentInset.top + 24.0;
    if (scrollView.contentOffset.y <= topThreshold) {
        [self pp_loadOlderMessagesIfNeeded];
    }
    
    
    UIColor *bubbleColor = [self captureBottomVisibleBubbleColor];
    [self updateBottomBarWithColor:bubbleColor];

    BOOL farFromBottom = ![self isNearBottom];
    [self setScrollToBottomButtonVisible:farFromBottom animated:YES];
}

- (void)pp_loadOlderMessagesIfNeeded
{
    if (self.isExpandingMessagePage || !self.didFinishInitialLoad) return;
    if (self.messages.count < self.messagePageLimit) return;
    self.isExpandingMessagePage = YES;
    self.previousContentHeightBeforeExpansion = self.tableView.contentSize.height;
    self.previousContentOffsetYBeforeExpansion = self.tableView.contentOffset.y;
    self.messagePageLimit += PPChatMessagePageStep;
    [self.messageListener remove];
    self.messageListener = nil;
    self.isObservingMessages = NO;
    self.didFinishInitialLoad = NO;
    [self observeMessages];
}

- (void)updateBottomBarWithColor:(UIColor *)color
{
    if (!color) return;

    [UIView animateWithDuration:0.15
                     animations:^{
        self.bottomFillBlurView.backgroundColor = color;
    }];
}

- (void)setupScrollToBottomButton
{
    if (self.scrollToBottomButton) return;

    UIButton *btn =
    [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleCapsule
                                                     configType:PPButtonConfigrationGlass];

    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.alpha = 0.0;
    btn.transform = CGAffineTransformMakeScale(0.85, 0.85);

    UIButtonConfiguration *config = btn.configuration;
    config.image = PPSYSImage(@"chevron.down");
    config.baseForegroundColor = AppPrimaryTextClr;
    config.contentInsets = NSDirectionalEdgeInsetsMake(10, 10, 10, 10);
    btn.configuration = config;

    btn.layer.cornerRadius = 22;
    btn.layer.masksToBounds = YES;

    [btn addTarget:self
            action:@selector(scrollToBottomButtonTapped)
  forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:btn];
    self.scrollToBottomButton = btn;

    [NSLayoutConstraint activateConstraints:@[
        [btn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:-0],
        [btn.bottomAnchor
         constraintEqualToAnchor:[self pp_activeChatInputBarViewForLayout].topAnchor
         constant:-12],
        [btn.widthAnchor constraintEqualToConstant:38],
        [btn.heightAnchor constraintEqualToConstant:38],
    ]];
}

- (void)setScrollToBottomButtonVisible:(BOOL)visible animated:(BOOL)animated
{
    if (!self.scrollToBottomButton) return;

    void (^changes)(void) = ^{
        self.scrollToBottomButton.alpha = visible ? 1.0 : 0.0;
        self.scrollToBottomButton.transform =
            visible ? CGAffineTransformIdentity
                    : CGAffineTransformMakeScale(0.85, 0.85);
    };

    if (animated) {
        [UIView animateWithDuration:0.25
                              delay:0
             usingSpringWithDamping:0.85
              initialSpringVelocity:0.4
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

- (void)viewDidLoadRecordData
{
    self.audioResumeTimes = [NSMutableDictionary dictionary];
    self.audioController = [[PPAudioPlaybackController alloc] init];
    self.audioController.delegate = self;
}

- (void)inputBarDidStartRecording:(PPChatInputBarView *)bar {
    [self startVoiceRecording];
}

- (void)inputBarDidCancelRecording:(PPChatInputBarView *)bar {
    
    [self pp_cancelRecording];
}

-(void)inputBarDidStopRecordingPreview:(PPChatInputBarView *)bar
{
    if (self.previewPlayer.isPlaying) {
            [self.previewPlayer stop];
            self.previewPlayer.currentTime = 0;
        }
}


- (void)inputBar:(PPChatInputBarView *)bar didFinishRecordingWithURL:(nullable NSURL *)fileURL duration:(NSTimeInterval)duration locked:(BOOL)locked {
    NSLog(@"✅ didFinishRecordingWithURL");
    [self finishVoiceRecordingAndSend];
   // [self pp_showRecordingPreviewWithURL:self.currentRecordingURL duration:duration];
   // [self finishVoiceRecordingAndSend];
}

- (void)switchAudioSessionToPlayback
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *err = nil;

    [session setCategory:AVAudioSessionCategoryPlayback
             withOptions:AVAudioSessionCategoryOptionDuckOthers
                   error:&err];

    [session setActive:YES error:&err];

    if (err) {
        NSLog(@"❌ AudioSession playback error: %@", err);
    } else {
        NSLog(@"✅ AudioSession switched to playback");
    }
}

- (void)stopRecordingTimer
{
    [self.recordingTimer invalidate];
    self.recordingTimer = nil;
}
- (void)startRecordingTimer
{
    [self stopRecordingTimer];
   /* self.recordingTimer =
        [NSTimer scheduledTimerWithTimeInterval:1.0
                                         target:self
                                       selector:@selector(updateRecordingTime)
                                       userInfo:nil
                                        repeats:YES];*/
}
- (void)stopSilenceDetection
{
    [self.silenceTimer invalidate];
    self.silenceTimer = nil;
}

-(void)inputBarDidTapAttachVideo:(PPChatInputBarView *)bar
{
    [self presentSourcePickerForMediaType:UTTypeMovie.identifier];
}

-(void)inputBarDidTapAttachImage:(PPChatInputBarView *)bar
{
    [self presentSourcePickerForMediaType:UTTypeImage.identifier];
}
#pragma mark - Input Bar Delegate (ONLY ENTRY POINT)
 

- (void)inputBar:(PPChatInputBarView *)bar didChangeHeight:(CGFloat)newHeight {
    [UIView performWithoutAnimation:^{
            [self.view layoutIfNeeded];
        }];

        if ([self isNearBottom]) {
            [self scrollToBottomAnimated:NO];
        }
}


- (void)inputBar:(PPChatInputBarView *)bar didSendText:(NSString *)text {
    [self sendChatMessageText:text];
}


- (void)inputBarDidTapAttach:(PPChatInputBarView *)bar {
     
}

- (void)inputBar:(PPChatInputBarView *)bar didChangeText:(UITextView *)textView
{
    [self.typingController userDidType];
}

- (void)inputBarDidCancelReply:(PPChatInputBarView *)bar
{
    [self pp_clearPendingReplyAnimated:YES];
}

#pragma mark - PPNovaSwiftUIChatBarViewControllerDelegate

- (void)swiftUIChatBarDidSendText:(NSString *)text {
    [self sendChatMessageText:text];
}

- (void)swiftUIChatBarDidTapCamera {
    [self presentSourcePickerForMediaType:UTTypeImage.identifier];
}

- (void)swiftUIChatBarDidTapVideo {
    [self presentSourcePickerForMediaType:UTTypeMovie.identifier];
}

- (void)swiftUIChatBarDidTapContact {
    [self presentSourcePickerForMediaType:UTTypeImage.identifier];
}

- (void)swiftUIChatBarDidChangeText:(NSString *)text {
    [self.typingController userDidType];
}

- (void)swiftUIChatBarDidCancelReply {
    [self pp_clearPendingReplyAnimated:YES];
}

- (void)swiftUIChatBarDidSendAudioWithURL:(NSURL *)audioURL duration:(double)duration {
    if (self.previewPlayer.isPlaying) {
        [self.previewPlayer stop];
        self.previewPlayer.currentTime = 0;
    }
    self.currentRecordingURL = audioURL;
    self.swiftUIRecordingDuration = duration > 0.0 ? duration : 0.0;
    self.recordingStartDate =
        [NSDate dateWithTimeIntervalSinceNow:-self.swiftUIRecordingDuration];
    self.didFinishRecordingOnce = NO;
    [self finishVoiceRecordingAndSend];
}

#pragma mark - Message Reply

- (ChatMessageModel *)pp_messageForCell:(UITableViewCell *)cell
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (!indexPath || indexPath.row < 0 || indexPath.row >= (NSInteger)self.messages.count) {
        return nil;
    }
    return self.messages[indexPath.row];
}

- (void)pp_selectReplyMessage:(ChatMessageModel *)message
{
    if (!message || !message.ID.length) return;

    self.replyingToMessage = message;
    NSString *title =
        [NSString stringWithFormat:kLang(@"chat_replying_to_format"),
                                   [self pp_replySenderNameForMessage:message]];
    NSString *subtitle = [self pp_replyPreviewTextForMessage:message];
    [self.inputbar setReplyPreviewTitle:title subtitle:subtitle animated:YES];
    [self.swiftUIInputVC setReplyPreviewTitle:title subtitle:subtitle animated:YES];
    self.swiftUIInputBarHeightConstraint.constant = [self pp_expandedSwiftUIComposerHeight];
    [self pp_animateComposerHeightChange];

    UIImpactFeedbackGenerator *feedback =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurredWithIntensity:0.55];
}

- (void)pp_clearPendingReplyAnimated:(BOOL)animated
{
    self.replyingToMessage = nil;
    [self.inputbar clearReplyPreviewAnimated:animated];
    [self.swiftUIInputVC clearReplyPreviewAnimated:animated];
    self.swiftUIInputBarHeightConstraint.constant = 54.0;
    [self pp_animateComposerHeightChange];
}

- (void)pp_animateComposerHeightChange
{
    BOOL keepBottomPinned = [self isNearBottom];
    void (^changes)(void) = ^{
        [self.view layoutIfNeeded];
        [self pp_applyTableViewBottomInsetForActiveComposer];
        if (keepBottomPinned) {
            [self pp_scrollTableViewToBottomWithoutAnimation];
        }
    };
    if (UIAccessibilityIsReduceMotionEnabled()) {
        changes();
        return;
    }
    [UIView animateWithDuration:0.34
                          delay:0.0
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:changes
                     completion:nil];
}

- (CGFloat)pp_expandedSwiftUIComposerHeight
{
    return UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory)
        ? 118.0
        : 108.0;
}

- (void)pp_applyPendingReplyToMessage:(ChatMessageModel *)message clearAfterApplying:(BOOL)clearAfterApplying
{
    if (!message || !self.replyingToMessage.ID.length) return;
    message.replyToMessageID = self.replyingToMessage.ID;
    if (message.ID.length > 0) {
        [self.cachedHeights removeObjectForKey:message.ID];
    }
    if (clearAfterApplying) {
        [self pp_clearPendingReplyAnimated:YES];
    }
}

- (NSString *)pp_replySenderNameForMessage:(ChatMessageModel *)message
{
    NSString *currentID = UserManager.sharedManager.currentUser.ID ?: @"";
    if ([message.senderID isEqualToString:currentID]) {
        return kLang(@"chat_reply_sender_you");
    }

    NSString *name = [self.threadOtherUser bestDisplayName];
    if (name.length > 0) {
        return name;
    }
    return kLang(@"Message");
}

- (NSString *)pp_replyPreviewTextForMessage:(ChatMessageModel *)message
{
    if (message.isDeleted) return kLang(@"chat_message_unsent");
    switch (message.messageType) {
        case ChatMessageTypeImage:
            return kLang(@"chat_reply_image");
        case ChatMessageTypeVideo:
            return kLang(@"chat_reply_video");
        case ChatMessageTypeAudio:
            return kLang(@"chat_reply_audio");
        case ChatMessageTypeText:
        default: {
            NSString *text = [message.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (!text.length) return kLang(@"Message");
            if (text.length <= 96) return text;
            return [[text substringToIndex:96] stringByAppendingString:@"..."];
        }
    }
}

- (ChatMessageModel *)pp_messageWithID:(NSString *)messageID
{
    if (messageID.length == 0) return nil;
    for (ChatMessageModel *candidate in self.messages ?: @[]) {
        if ([candidate.ID isEqualToString:messageID]) {
            return candidate;
        }
    }
    return nil;
}

- (ChatMessageModel *)pp_messageModelFromSnapshot:(FIRDocumentSnapshot *)document
{
    ChatMessageModel *message =
        [[ChatMessageModel alloc] initWithDictionary:document.data ?: @{}];

    // Firestore document ID is the stable row identity. Some legacy/pro clients
    // omit the uppercase ID field, which otherwise makes live modified events
    // look like brand-new messages until the controller is reopened.
    if (document.documentID.length > 0) {
        message.ID = document.documentID;
    }

    return message;
}

- (void)pp_replyPreviewPartsForMessage:(ChatMessageModel *)message
                                 title:(NSString **)title
                              subtitle:(NSString **)subtitle
{
    if (!message.replyToMessageID.length) {
        if (title) *title = nil;
        if (subtitle) *subtitle = nil;
        return;
    }

    ChatMessageModel *source = [self pp_messageWithID:message.replyToMessageID];
    if (!source) {
        if (title) *title = kLang(@"chat_replying");
        if (subtitle) *subtitle = kLang(@"chat_reply_unavailable");
        return;
    }

    if (title) {
        *title = [NSString stringWithFormat:kLang(@"chat_replying_to_format"),
                                             [self pp_replySenderNameForMessage:source]];
    }
    if (subtitle) {
        *subtitle = [self pp_replyPreviewTextForMessage:source];
    }
}

- (void)pp_applyReplyPreviewForMessage:(ChatMessageModel *)message
                              toBubble:(ChatBubbleView *)bubble
                            isIncoming:(BOOL)isIncoming
{
    NSString *title = nil;
    NSString *subtitle = nil;
    [self pp_replyPreviewPartsForMessage:message title:&title subtitle:&subtitle];
    if (title.length == 0 && subtitle.length == 0) {
        [bubble clearReplyPreview];
        return;
    }
    [bubble setReplyPreviewTitle:title subtitle:subtitle isIncoming:isIncoming];
}

- (void)pp_applyReplyPreviewForMessage:(ChatMessageModel *)message
                            toImageCell:(ChatImageMessageCell *)cell
                             isIncoming:(BOOL)isIncoming
{
    NSString *title = nil;
    NSString *subtitle = nil;
    [self pp_replyPreviewPartsForMessage:message title:&title subtitle:&subtitle];
    if (title.length == 0 && subtitle.length == 0) {
        [cell clearReplyPreview];
        return;
    }
    [cell setReplyPreviewTitle:title subtitle:subtitle isIncoming:isIncoming];
}

- (void)pp_applyReplyPreviewForMessage:(ChatMessageModel *)message
                            toVideoCell:(ChatVideoMessageCell *)cell
                             isIncoming:(BOOL)isIncoming
{
    NSString *title = nil;
    NSString *subtitle = nil;
    [self pp_replyPreviewPartsForMessage:message title:&title subtitle:&subtitle];
    if (title.length == 0 && subtitle.length == 0) {
        [cell clearReplyPreview];
        return;
    }
    [cell setReplyPreviewTitle:title subtitle:subtitle isIncoming:isIncoming];
}

- (void)pp_applyReplyPreviewForMessage:(ChatMessageModel *)message
                            toAudioCell:(ChatAudioMessageCell *)cell
                             isIncoming:(BOOL)isIncoming
{
    NSString *title = nil;
    NSString *subtitle = nil;
    [self pp_replyPreviewPartsForMessage:message title:&title subtitle:&subtitle];
    if (title.length == 0 && subtitle.length == 0) {
        [cell clearReplyPreview];
        return;
    }
    [cell setReplyPreviewTitle:title subtitle:subtitle isIncoming:isIncoming];
}

- (void)chatMessageCellDidRequestCopy:(ChatMessageCell *)cell
{
    [PPHUD showSuccess:kLang(@"chat_copied")];
}

- (void)chatMessageCellDidRequestReply:(ChatMessageCell *)cell
{
    [self pp_selectReplyMessage:[self pp_messageForCell:cell]];
}

- (void)chatImageMessageCellDidRequestReply:(ChatImageMessageCell *)cell
{
    [self pp_selectReplyMessage:[self pp_messageForCell:cell]];
}

- (void)chatImageMessageCellDidTapView:(ChatImageMessageCell *)cell
{
    ChatMessageModel *message = [self pp_messageForCell:cell];
    [self pp_openImageMessage:message fromCell:cell];
}

- (void)chatImageMessageCellDidTapDownload:(ChatImageMessageCell *)cell
{
    ChatMessageModel *message = [self pp_messageForCell:cell];
    UIImage *visibleImage = message.localImage ?: cell.imageViewMsg.image;
    [self pp_downloadImageMessage:message visibleImage:visibleImage];
}

#pragma mark - Premium Message Interaction

- (UIView *)pp_messageInteractionViewForCell:(UITableViewCell *)cell
{
    if ([cell isKindOfClass:ChatMessageCell.class]) {
        return [(ChatMessageCell *)cell messageInteractionView];
    }
    if ([cell isKindOfClass:ChatImageMessageCell.class]) {
        return [(ChatImageMessageCell *)cell messageInteractionView];
    }
    if ([cell isKindOfClass:ChatVideoMessageCell.class]) {
        return [(ChatVideoMessageCell *)cell messageInteractionView];
    }
    if ([cell isKindOfClass:ChatAudioMessageCell.class]) {
        return [(ChatAudioMessageCell *)cell messageInteractionView];
    }
    return cell.contentView;
}

- (BOOL)pp_currentUserOwnsMessage:(ChatMessageModel *)message
{
    NSString *authUID = [FIRAuth auth].currentUser.uid ?: @"";
    NSString *profileID = UserManager.sharedManager.currentUser.ID ?: @"";
    return message.senderID.length > 0 &&
        ([message.senderID isEqualToString:authUID] ||
         [message.senderID isEqualToString:profileID]);
}

- (CGFloat)pp_replyPanPhysicalDirectionForMessage:(ChatMessageModel *)message
{
    CGFloat outgoingDirection = Language.isRTL ? -1.0 : 1.0;
    return [self pp_currentUserOwnsMessage:message] ? outgoingDirection : -outgoingDirection;
}

- (BOOL)pp_canUnsendMessage:(ChatMessageModel *)message
{
    if (!message || message.isDeleted || message.isLocalPending || message.ID.length == 0) return NO;
    if ([self.unsendingMessageIDs containsObject:message.ID]) return NO;
    if (![self pp_currentUserOwnsMessage:message] || !message.timestamp) return NO;
    NSTimeInterval age = -[message.timestamp timeIntervalSinceNow];
    return age >= -60.0 && age <= PPChatUnsendWindow;
}

- (UIView *)pp_replyIndicatorForCell:(UITableViewCell *)cell createIfNeeded:(BOOL)create
{
    UIView *indicator = [cell viewWithTag:PPChatReplyIndicatorTag];
    if (indicator || !create) return indicator;

    indicator = [UIView new];
    indicator.tag = PPChatReplyIndicatorTag;
    indicator.translatesAutoresizingMaskIntoConstraints = NO;
    indicator.userInteractionEnabled = NO;
    indicator.alpha = 0.0;
    indicator.transform = CGAffineTransformMakeScale(0.76, 0.76);
    indicator.backgroundColor = [[PPChatsFunc chatNeutralAccentColor] colorWithAlphaComponent:0.12];
    indicator.layer.cornerRadius = 18.0;
    if (@available(iOS 13.0, *)) indicator.layer.cornerCurve = kCACornerCurveContinuous;

    UIImageView *icon = [[UIImageView alloc] initWithImage:PPSYSImage(@"arrowshape.turn.up.left.fill")];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.tintColor = [PPChatsFunc chatNeutralAccentColor];
    if (Language.isRTL) {
        icon.transform = CGAffineTransformMakeScale(-1.0, 1.0);
    }
    [indicator addSubview:icon];
    [cell insertSubview:indicator belowSubview:cell.contentView];

    NSLayoutXAxisAnchor *edge = Language.isRTL ? cell.trailingAnchor : cell.leadingAnchor;
    NSLayoutConstraint *edgeConstraint = Language.isRTL
        ? [indicator.trailingAnchor constraintEqualToAnchor:edge constant:-14.0]
        : [indicator.leadingAnchor constraintEqualToAnchor:edge constant:14.0];
    [NSLayoutConstraint activateConstraints:@[
        edgeConstraint,
        [indicator.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [indicator.widthAnchor constraintEqualToConstant:36.0],
        [indicator.heightAnchor constraintEqualToConstant:36.0],
        [icon.centerXAnchor constraintEqualToAnchor:indicator.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:indicator.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:16.0],
        [icon.heightAnchor constraintEqualToConstant:16.0],
    ]];
    return indicator;
}

- (void)pp_prepareInteractionsForCell:(UITableViewCell *)cell message:(ChatMessageModel *)message
{
    cell.contentView.transform = CGAffineTransformIdentity;
    UIView *interactionView = [self pp_messageInteractionViewForCell:cell];
    interactionView.transform = CGAffineTransformIdentity;
    UIView *indicator = [self pp_replyIndicatorForCell:cell createIfNeeded:!message.isDeleted];
    indicator.alpha = 0.0;
    indicator.transform = CGAffineTransformMakeScale(0.76, 0.76);

    NSArray<UIGestureRecognizer *> *legacyReplyRecognizers =
        [cell.contentView.gestureRecognizers copy] ?: @[];
    for (UIGestureRecognizer *recognizer in legacyReplyRecognizers) {
        if ([recognizer.name isEqualToString:PPChatReplyPanName]) {
            [cell.contentView removeGestureRecognizer:recognizer];
        }
    }

    BOOL hasReplyPan = NO;
    for (UIGestureRecognizer *recognizer in interactionView.gestureRecognizers ?: @[]) {
        if ([recognizer.name isEqualToString:PPChatReplyPanName]) {
            hasReplyPan = YES;
            recognizer.enabled = !message.isDeleted;
            break;
        }
    }
    if (!hasReplyPan && !message.isDeleted) {
        UIPanGestureRecognizer *pan =
            [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pp_handleReplyPan:)];
        pan.name = PPChatReplyPanName;
        pan.delegate = self;
        pan.cancelsTouchesInView = NO;
        pan.maximumNumberOfTouches = 1;
        [interactionView addGestureRecognizer:pan];
    }

    __weak typeof(self) weakSelf = self;
    __weak UITableViewCell *weakCell = cell;
    UIAccessibilityCustomAction *replyAction =
        [[UIAccessibilityCustomAction alloc] initWithName:kLang(@"reply")
                                            actionHandler:^BOOL(__unused UIAccessibilityCustomAction *action) {
        [weakSelf pp_selectReplyMessage:message];
        return YES;
    }];
    NSMutableArray<UIAccessibilityCustomAction *> *actions = [NSMutableArray arrayWithObject:replyAction];
    if (message.isTextMessage && message.text.length > 0) {
        UIAccessibilityCustomAction *copyAction =
            [[UIAccessibilityCustomAction alloc] initWithName:kLang(@"copy")
                                                actionHandler:^BOOL(__unused UIAccessibilityCustomAction *action) {
            UIPasteboard.generalPasteboard.string = message.text;
            [PPHUD showSuccess:kLang(@"chat_copied")];
            return YES;
        }];
        [actions addObject:copyAction];
    }
    if ([self pp_canUnsendMessage:message]) {
        UIAccessibilityCustomAction *unsendAction =
            [[UIAccessibilityCustomAction alloc]
                initWithName:PPChatLocalizedStringOrFallback(@"chat_unsend", @"Delete")
                                                actionHandler:^BOOL(__unused UIAccessibilityCustomAction *action) {
            [weakSelf pp_presentUnsendConfirmationForMessage:message sourceCell:weakCell];
            return YES;
        }];
        [actions addObject:unsendAction];
    }
    if (message.isDeleted) [actions removeAllObjects];
    cell.accessibilityCustomActions = actions;
    [self pp_messageInteractionViewForCell:cell].accessibilityCustomActions = actions;
}

- (UITableViewCell *)pp_cellContainingView:(UIView *)view
{
    UIView *candidate = view;
    while (candidate && ![candidate isKindOfClass:UITableViewCell.class]) {
        candidate = candidate.superview;
    }
    return (UITableViewCell *)candidate;
}

- (void)pp_handleReplyPan:(UIPanGestureRecognizer *)pan
{
    UITableViewCell *cell = [self pp_cellContainingView:pan.view];
    ChatMessageModel *message = [self pp_messageForCell:cell];
    if (!cell || !message || message.isDeleted) return;

    UIView *interactionView = [self pp_messageInteractionViewForCell:cell];
    if (!interactionView) return;

    CGFloat replyDirection = [self pp_replyPanPhysicalDirectionForMessage:message];
    CGFloat physicalTranslation = [pan translationInView:cell].x;
    CGFloat directionalTranslation = physicalTranslation * replyDirection;
    CGFloat clamped = MAX(0.0, MIN(directionalTranslation, PPChatReplyPanMaxDistance));
    CGFloat progress = MIN(1.0, clamped / PPChatReplyPanCommitDistance);
    CGFloat physicalOffset = replyDirection * clamped;
    UIView *indicator = [self pp_replyIndicatorForCell:cell createIfNeeded:YES];

    switch (pan.state) {
        case UIGestureRecognizerStateBegan:
            self.activeReplyGestureCell = cell;
            self.replyGesturePassedThreshold = NO;
            [cell.contentView.layer removeAllAnimations];
            [interactionView.layer removeAllAnimations];
            [indicator.layer removeAllAnimations];
            break;
        case UIGestureRecognizerStateChanged:
            interactionView.transform = CGAffineTransformMakeTranslation(physicalOffset, 0.0);
            indicator.alpha = 0.14 + (0.86 * progress);
            CGFloat indicatorScale = 0.76 + (0.28 * progress);
            indicator.transform = CGAffineTransformMakeScale(indicatorScale, indicatorScale);
            if (progress >= 1.0 && !self.replyGesturePassedThreshold) {
                self.replyGesturePassedThreshold = YES;
                UISelectionFeedbackGenerator *feedback = [UISelectionFeedbackGenerator new];
                [feedback selectionChanged];
            }
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            BOOL shouldReply = pan.state == UIGestureRecognizerStateEnded && progress >= 1.0;
            if (shouldReply) [self pp_selectReplyMessage:message];
            void (^reset)(void) = ^{
                interactionView.transform = CGAffineTransformIdentity;
                indicator.alpha = 0.0;
                indicator.transform = CGAffineTransformMakeScale(0.76, 0.76);
            };
            if (UIAccessibilityIsReduceMotionEnabled()) {
                [UIView animateWithDuration:0.12
                                      delay:0.0
                                    options:UIViewAnimationOptionBeginFromCurrentState |
                                            UIViewAnimationOptionAllowUserInteraction
                                 animations:reset
                                 completion:nil];
            } else {
                [UIView animateWithDuration:(shouldReply ? 0.28 : 0.34)
                                      delay:0.0
                     usingSpringWithDamping:(shouldReply ? 0.82 : 0.88)
                      initialSpringVelocity:(shouldReply ? 0.42 : 0.22)
                                    options:UIViewAnimationOptionBeginFromCurrentState |
                                            UIViewAnimationOptionAllowUserInteraction
                                 animations:reset
                                 completion:nil];
            }
            self.activeReplyGestureCell = nil;
            self.replyGesturePassedThreshold = NO;
            break;
        }
        default:
            break;
    }
}

- (UIMenu *)pp_contextMenuForMessage:(ChatMessageModel *)message sourceCell:(UITableViewCell *)cell
{
    NSMutableArray<UIMenuElement *> *actions = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;
    [actions addObject:[UIAction actionWithTitle:kLang(@"reply")
                                        image:PPSYSImage(@"arrowshape.turn.up.left")
                                   identifier:nil
                                      handler:^(__unused UIAction *action) {
        [weakSelf pp_selectReplyMessage:message];
    }]];

    if (message.isTextMessage && message.text.length > 0) {
        [actions addObject:[UIAction actionWithTitle:kLang(@"copy")
                                            image:PPSYSImage(@"doc.on.doc")
                                       identifier:nil
                                          handler:^(__unused UIAction *action) {
            UIPasteboard.generalPasteboard.string = message.text;
            [PPHUD showSuccess:kLang(@"chat_copied")];
        }]];
    }

    if ([self pp_canUnsendMessage:message]) {
        UIAction *unsend =
            [UIAction actionWithTitle:PPChatLocalizedStringOrFallback(@"chat_unsend", @"Delete")
                                            image:PPSYSImage(@"arrow.uturn.backward")
                                       identifier:nil
                                          handler:^(__unused UIAction *action) {
            [weakSelf pp_presentUnsendConfirmationForMessage:message sourceCell:cell];
        }];
        unsend.attributes = UIMenuElementAttributesDestructive;
        [actions addObject:unsend];
    }
    return [UIMenu menuWithTitle:@"" children:actions];
}

- (nullable UIContextMenuConfiguration *)tableView:(UITableView *)tableView
       contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
                                           point:(CGPoint)point
{
    if (indexPath.row >= (NSInteger)self.messages.count) return nil;
    ChatMessageModel *message = self.messages[indexPath.row];
    if (message.isDeleted || [self.unsendingMessageIDs containsObject:message.ID]) return nil;
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    __weak typeof(self) weakSelf = self;
    return [UIContextMenuConfiguration configurationWithIdentifier:message.ID
                                                   previewProvider:nil
                                                    actionProvider:^UIMenu * _Nullable(__unused NSArray<UIMenuElement *> *suggestedActions) {
        return [weakSelf pp_contextMenuForMessage:message sourceCell:cell];
    }];
}

- (nullable UITargetedPreview *)pp_contextMenuPreviewForTableView:(UITableView *)tableView
                                                    configuration:(UIContextMenuConfiguration *)configuration
{
    ChatMessageModel *message = [self pp_messageWithID:(NSString *)configuration.identifier];
    NSInteger row = [self.messages indexOfObjectIdenticalTo:message];
    if (!message || row == NSNotFound) return nil;
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
    UIView *surface = [self pp_messageInteractionViewForCell:cell];
    if (!surface.window) return nil;
    if ([cell isKindOfClass:ChatMessageCell.class]) {
        [[(ChatMessageCell *)cell bubbleView] setContextMenuPresentationActive:YES];
    }

    UIPreviewParameters *parameters = [UIPreviewParameters new];
    parameters.backgroundColor = UIColor.clearColor;
    CGFloat radius = MIN(18.0, floor(MIN(CGRectGetWidth(surface.bounds),
                                         CGRectGetHeight(surface.bounds)) * 0.5));
    parameters.visiblePath = [UIBezierPath bezierPathWithRoundedRect:surface.bounds
                                                         cornerRadius:radius];
    return [[UITargetedPreview alloc] initWithView:surface parameters:parameters];
}

- (void)tableView:(UITableView *)tableView
 willDisplayContextMenuWithConfiguration:(UIContextMenuConfiguration *)configuration
          animator:(nullable id<UIContextMenuInteractionAnimating>)animator
{
    (void)animator;
    ChatMessageModel *message = [self pp_messageWithID:(NSString *)configuration.identifier];
    NSInteger row = [self.messages indexOfObjectIdenticalTo:message];
    if (!message || row == NSNotFound) return;
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
    if ([cell isKindOfClass:ChatMessageCell.class]) {
        [[(ChatMessageCell *)cell bubbleView] setContextMenuPresentationActive:YES];
    }
}

- (void)tableView:(UITableView *)tableView
 willEndContextMenuInteractionWithConfiguration:(UIContextMenuConfiguration *)configuration
          animator:(nullable id<UIContextMenuInteractionAnimating>)animator
{
    void (^restoreBubble)(void) = ^{
        ChatMessageModel *message = [self pp_messageWithID:(NSString *)configuration.identifier];
        NSInteger row = [self.messages indexOfObjectIdenticalTo:message];
        if (!message || row == NSNotFound) return;
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
        if ([cell isKindOfClass:ChatMessageCell.class]) {
            [[(ChatMessageCell *)cell bubbleView] setContextMenuPresentationActive:NO];
        }
    };
    if (animator) {
        [animator addCompletion:restoreBubble];
    } else {
        restoreBubble();
    }
}

- (nullable UITargetedPreview *)tableView:(UITableView *)tableView
 previewForHighlightingContextMenuWithConfiguration:(UIContextMenuConfiguration *)configuration
{
    return [self pp_contextMenuPreviewForTableView:tableView configuration:configuration];
}

- (nullable UITargetedPreview *)tableView:(UITableView *)tableView
 previewForDismissingContextMenuWithConfiguration:(UIContextMenuConfiguration *)configuration
{
    return [self pp_contextMenuPreviewForTableView:tableView configuration:configuration];
}

- (void)pp_presentUnsendConfirmationForMessage:(ChatMessageModel *)message
                                     sourceCell:(UITableViewCell *)sourceCell
{
    if (![self pp_canUnsendMessage:message]) return;
    NSString *title = PPChatLocalizedStringOrFallback(@"chat_unsend_title", @"Delete");
    NSString *messageText = PPChatLocalizedStringOrFallback(@"chat_unsend_confirmation", nil);
    NSString *actionTitle = PPChatLocalizedStringOrFallback(@"chat_unsend", @"Delete");
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:title
                                            message:messageText
                                     preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:actionTitle
                                              style:UIAlertActionStyleDestructive
                                            handler:^(__unused UIAlertAction *action) {
        [weakSelf pp_unsendMessage:message sourceCell:sourceCell];
    }]];
    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    popover.sourceView = sourceCell ?: self.view;
    popover.sourceRect = sourceCell ? sourceCell.bounds : self.view.bounds;
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)pp_unsendMessage:(ChatMessageModel *)message sourceCell:(UITableViewCell *)sourceCell
{
    if (![self pp_canUnsendMessage:message]) return;
    [self.unsendingMessageIDs addObject:message.ID];
    sourceCell.userInteractionEnabled = NO;
    [UIView animateWithDuration:0.16 animations:^{ sourceCell.alpha = 0.62; }];

    __weak typeof(self) weakSelf = self;
    [[ChManager sharedManager] unsendMessageWithID:message.ID
                                         threadID:self.chatThread.ID
                                       completion:^(NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self.unsendingMessageIDs removeObject:message.ID];
        sourceCell.userInteractionEnabled = YES;
        sourceCell.alpha = 1.0;
        if (error) {
            NSString *publicMessage =
                [PPFirebaseSessionBridge publicMessageForError:error fallbackKey:@"chat_unsend_failed"];
            [PPHUD showError:publicMessage.length > 0 ? publicMessage : kLang(@"chat_unsend_failed")];
            return;
        }

        if ([self.audioController.currentMessageID isEqualToString:message.ID]) {
            [self.audioController stop];
        }
        if ([self.replyingToMessage.ID isEqualToString:message.ID]) {
            [self pp_clearPendingReplyAnimated:YES];
        }
        message.isDeleted = YES;
        message.text = @"";
        message.replyToMessageID = nil;
        if (message.localVideoURL.isFileURL) {
            [NSFileManager.defaultManager removeItemAtURL:message.localVideoURL error:nil];
        }
        NSString *cachedAudioPath =
            [NSTemporaryDirectory() stringByAppendingPathComponent:
                [NSString stringWithFormat:@"chat_%@.m4a", message.ID]];
        [NSFileManager.defaultManager removeItemAtPath:cachedAudioPath error:nil];
        message.fileURL = nil;
        message.thumbnailURL = nil;
        message.thumbnailImage = nil;
        message.blurHash = nil;
        message.waveformSamples = @[];
        message.localImage = nil;
        message.localVideoURL = nil;
        [self.cachedHeights removeObjectForKey:message.ID];
        if (self.messages.lastObject == message) {
            self.chatThread.lastMessage = kLang(@"chat_message_unsent");
            self.chatThread.lastMessageAt = message.timestamp;
            if ([self.delegate respondsToSelector:@selector(ReloadChats)]) {
                [self.delegate ReloadChats];
            }
        }
        NSInteger row = [self.messages indexOfObjectIdenticalTo:message];
        if (row != NSNotFound) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
            [self.tableView reloadRowsAtIndexPaths:@[indexPath]
                                  withRowAnimation:UITableViewRowAnimationFade];
        }
        [PPHUD showSuccess:kLang(@"chat_unsend_success")];
    }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    if (indexPath.row >= (NSInteger)self.messages.count) return;
    ChatMessageModel *message = self.messages[indexPath.row];
    if (message.replyToMessageID.length == 0 || message.isDeleted) return;
    ChatMessageModel *source = [self pp_messageWithID:message.replyToMessageID];
    NSInteger sourceRow = [self.messages indexOfObjectIdenticalTo:source];
    if (!source || sourceRow == NSNotFound) {
        [PPHUD showError:kLang(@"chat_reply_unavailable")];
        return;
    }
    NSIndexPath *sourcePath = [NSIndexPath indexPathForRow:sourceRow inSection:0];
    [tableView scrollToRowAtIndexPath:sourcePath
                    atScrollPosition:UITableViewScrollPositionMiddle
                            animated:!UIAccessibilityIsReduceMotionEnabled()];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.30 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UITableViewCell *sourceCell = [tableView cellForRowAtIndexPath:sourcePath];
        UIView *surface = [self pp_messageInteractionViewForCell:sourceCell];
        if (!surface) return;
        [UIView animateKeyframesWithDuration:0.42
                                      delay:0.0
                                    options:UIViewKeyframeAnimationOptionBeginFromCurrentState |
                                            UIViewKeyframeAnimationOptionAllowUserInteraction
                                 animations:^{
            [UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:0.42 animations:^{
                surface.transform = CGAffineTransformMakeScale(1.035, 1.035);
            }];
            [UIView addKeyframeWithRelativeStartTime:0.42 relativeDuration:0.58 animations:^{
                surface.transform = CGAffineTransformIdentity;
            }];
        } completion:nil];
    });
}

#pragma mark - Media Viewer And Download

- (void)pp_openImageMessage:(ChatMessageModel *)message fromCell:(ChatImageMessageCell *)cell
{
    if (!message) return;

    UIImage *visibleImage = message.localImage ?: cell.imageViewMsg.image;
    if (message.fileURL.length == 0 && visibleImage) {
        [self pp_presentImageViewerWithImage:visibleImage fromImageView:cell.imageViewMsg];
        return;
    }

    if (message.fileURL.length == 0) {
        [PPHUD showError:kLang(@"chat_media_unavailable")];
        return;
    }

    [PPHUD showLoading:kLang(@"chat_media_opening")];
    __weak typeof(self) weakSelf = self;
    [PPImageLoaderManager.shared fetchImageWithURL:message.fileURL
                                        completion:^(UIImage * _Nullable image) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [PPHUD dismiss];
            if (cell.boundMessageID.length > 0 &&
                ![cell.boundMessageID isEqualToString:message.ID]) {
                return;
            }
            UIImage *resolvedImage = image ?: visibleImage;
            if (!resolvedImage) {
                [PPHUD showError:kLang(@"chat_media_unavailable")];
                return;
            }
            [strongSelf pp_presentImageViewerWithImage:resolvedImage
                                         fromImageView:cell.imageViewMsg];
        });
    }];
}

- (void)pp_presentImageViewerWithImage:(UIImage *)image fromImageView:(UIImageView *)imageView
{
    if (!image || !imageView) return;
    FullScreenImageViewerController *viewer =
        [[FullScreenImageViewerController alloc] initWithImage:image];
    [viewer presentFullScreenFromImageView:imageView];
}

- (void)pp_downloadImageMessage:(ChatMessageModel *)message visibleImage:(UIImage *)visibleImage
{
    if (!message) return;
    [PPHUD showLoading:kLang(@"chat_media_saving")];

    void (^saveImage)(UIImage *) = ^(UIImage *image) {
        if (!image) {
            [PPHUD showError:kLang(@"chat_media_save_failed")];
            return;
        }
        [self pp_saveImageToPhotoLibrary:image];
    };

    if (message.fileURL.length > 0) {
        [PPImageLoaderManager.shared fetchImageWithURL:message.fileURL
                                            completion:^(UIImage * _Nullable image) {
            dispatch_async(dispatch_get_main_queue(), ^{
                saveImage(image ?: message.localImage);
            });
        }];
        return;
    }

    saveImage(message.localImage ?: visibleImage);
}

- (void)pp_downloadVideoMessage:(ChatMessageModel *)message
{
    if (!message) return;

    NSURL *localURL = message.localVideoURL;
    if (!localURL && [message.fileURL hasPrefix:@"file://"]) {
        localURL = [NSURL URLWithString:message.fileURL];
    }

    if (localURL.isFileURL) {
        [PPHUD showLoading:kLang(@"chat_media_saving")];
        [self pp_saveVideoAtURLToPhotoLibrary:localURL];
        return;
    }

    if (message.fileURL.length == 0) {
        [PPHUD showError:kLang(@"chat_media_unavailable")];
        return;
    }

    NSURL *remoteURL = [NSURL URLWithString:message.fileURL];
    if (!remoteURL || remoteURL.scheme.length == 0) {
        [PPHUD showError:kLang(@"chat_media_unavailable")];
        return;
    }

    [PPHUD showLoading:kLang(@"chat_media_downloading")];
    NSURLSessionDownloadTask *task =
        [NSURLSession.sharedSession downloadTaskWithURL:remoteURL
                                      completionHandler:^(NSURL *location,
                                                          NSURLResponse *response,
                                                          NSError *error) {
        if (error || !location) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [PPHUD showError:kLang(@"chat_media_save_failed")];
            });
            return;
        }

        NSString *fileName = [NSString stringWithFormat:@"purepets_chat_%@.mp4", message.ID ?: [GM cleanID]];
        NSURL *tempURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];
        [[NSFileManager defaultManager] removeItemAtURL:tempURL error:nil];
        NSError *moveError = nil;
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:tempURL error:&moveError];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (moveError) {
                [PPHUD showError:kLang(@"chat_media_save_failed")];
                return;
            }
            [self pp_saveVideoAtURLToPhotoLibrary:tempURL];
        });
    }];
    [task resume];
}

- (void)pp_requestPhotoSaveAccessWithCompletion:(void (^)(BOOL granted))completion
{
    PHAuthorizationStatus status;
    if (@available(iOS 14.0, *)) {
        status = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly];
        if (status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited) {
            completion(YES);
            return;
        }
        if (status == PHAuthorizationStatusDenied || status == PHAuthorizationStatusRestricted) {
            [PPHUD dismiss];
            [PPPermissionHelper showPermissionDeniedAlertForFeature:kLang(@"pp_perm_photos_feature")
                                                   onViewController:self];
            completion(NO);
            return;
        }
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
                                                   handler:^(PHAuthorizationStatus newStatus) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(newStatus == PHAuthorizationStatusAuthorized ||
                           newStatus == PHAuthorizationStatusLimited);
            });
        }];
        return;
    }

    status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusAuthorized) {
        completion(YES);
        return;
    }
    if (status == PHAuthorizationStatusDenied || status == PHAuthorizationStatusRestricted) {
        [PPHUD dismiss];
        [PPPermissionHelper showPermissionDeniedAlertForFeature:kLang(@"pp_perm_photos_feature")
                                               onViewController:self];
        completion(NO);
        return;
    }
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus newStatus) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(newStatus == PHAuthorizationStatusAuthorized);
        });
    }];
}

- (void)pp_saveImageToPhotoLibrary:(UIImage *)image
{
    if (!image) {
        [PPHUD showError:kLang(@"chat_media_save_failed")];
        return;
    }

    [self pp_requestPhotoSaveAccessWithCompletion:^(BOOL granted) {
        if (!granted) {
            [PPHUD dismiss];
            return;
        }
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromImage:image];
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    [PPHUD showSuccess:kLang(@"chat_media_download_complete")];
                } else {
                    [PPHUD showError:kLang(@"chat_media_save_failed")
                             subtitle:error.localizedDescription ?: @""];
                }
            });
        }];
    }];
}

- (void)pp_saveVideoAtURLToPhotoLibrary:(NSURL *)videoURL
{
    if (!videoURL.isFileURL) {
        [PPHUD showError:kLang(@"chat_media_save_failed")];
        return;
    }

    [self pp_requestPhotoSaveAccessWithCompletion:^(BOOL granted) {
        if (!granted) {
            [PPHUD dismiss];
            return;
        }
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:videoURL];
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    [PPHUD showSuccess:kLang(@"chat_media_download_complete")];
                } else {
                    [PPHUD showError:kLang(@"chat_media_save_failed")
                             subtitle:error.localizedDescription ?: @""];
                }
            });
        }];
    }];
}


#pragma mark - Recording Core

- (void)startVoiceRecording
{
    if (self.recordingState != PPVoiceRecordingStateIdle) {
        NSLog(@"⚠️ Cannot start recording: current state is %ld (expected Idle)", (long)self.recordingState);
        return;
    }

    NSLog(@"🔊 Starting voice recording...");
    self.recordingState = PPVoiceRecordingStateRecording;
    self.swiftUIRecordingDuration = 0.0;
    self.recordingStartDate = [NSDate date];
    NSLog(@"🕒 Recording start time: %@", self.recordingStartDate);

    // 1️⃣ Create file URL
    self.currentRecordingURL = [self createNewRecordingURL];
    NSLog(@"🎙 Recording to file: %@", self.currentRecordingURL.path);

    // 2️⃣ Audio session (record)
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *sessionErr = nil;
    
    BOOL categorySuccess = [session setCategory:AVAudioSessionCategoryPlayAndRecord
                                    withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker
                                          error:&sessionErr];
    if (!categorySuccess || sessionErr) {
        NSLog(@"❌ Failed to set audio session category: %@", sessionErr.localizedDescription);
        [self handleRecordingError:sessionErr];
        return;
    }
    
    BOOL activateSuccess = [session setActive:YES error:&sessionErr];
    if (!activateSuccess || sessionErr) {
        NSLog(@"❌ Failed to activate audio session: %@", sessionErr.localizedDescription);
        [self handleRecordingError:sessionErr];
        return;
    }
    
    NSLog(@"✅ Audio session configured successfully");

    // 3️⃣ Recorder settings
    NSDictionary *settings = @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVSampleRateKey: @44100,
        AVNumberOfChannelsKey: @1,
        AVEncoderAudioQualityKey: @(AVAudioQualityHigh)
    };
    
    NSLog(@"⚙️ Audio settings: %@", settings);

    NSError *recErr = nil;
    self.audioRecorder = [[AVAudioRecorder alloc] initWithURL:self.currentRecordingURL
                                                      settings:settings
                                                         error:&recErr];

    if (!self.audioRecorder || recErr) {
        NSLog(@"❌ Recorder initialization failed: %@", recErr.localizedDescription);
        NSLog(@"❌ Recorder error details: %@", recErr);
        [self handleRecordingError:recErr];
        return;
    }

    NSLog(@"✅ AVAudioRecorder initialized successfully");
    self.audioRecorder.delegate = self;
    [self.audioRecorder setMeteringEnabled:YES];
    [self.audioRecorder prepareToRecord];
    
    BOOL recordingStarted = [self.audioRecorder record];
    if (recordingStarted) {
        NSLog(@"✅ Recording started successfully");
        [self startRecordingWaveUpdates];
        [self pp_startRecordingTimer];
        NSLog(@"📊 Wave updates and timer started");
    } else {
        NSLog(@"❌ Failed to start recording - recorder returned NO");
        self.recordingState = PPVoiceRecordingStateIdle;
        self.audioRecorder = nil;
    }
}


- (NSURL *)createNewRecordingURL
{
    NSString *fileName = [NSString stringWithFormat:@"voice_%@.m4a", NSUUID.UUID.UUIDString];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];

    return [NSURL fileURLWithPath:path];
}

// Helper method for error handling
- (void)handleRecordingError:(NSError *)error {
    self.recordingState = PPVoiceRecordingStateIdle;
    self.audioRecorder = nil;
    self.currentRecordingURL = nil;
    
    NSLog(@"🔄 Reset recording state to Idle due to error");
    
    // Optional: Post notification for UI update
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PPVoiceRecordingErrorOccurred"
                                                        object:error];
}

- (void)finishVoiceRecordingAndSend
{
    if (!self.currentRecordingURL) {
        self.swiftUIRecordingDuration = 0.0;
        return;
    }

    if (self.didFinishRecordingOnce) {
        NSLog(@"⛔️ [SEND] Ignored duplicate send");
        return;
    }
    self.didFinishRecordingOnce = YES;

    [self stopAllRecordingUpdates];

    // Stop recorder
    [self.audioRecorder stop];
    self.audioRecorder = nil;
    self.recordingState = PPVoiceRecordingStateIdle;

    NSTimeInterval duration = self.swiftUIRecordingDuration > 0.0
        ? self.swiftUIRecordingDuration
        : [[NSDate date] timeIntervalSinceDate:self.recordingStartDate];
    self.swiftUIRecordingDuration = 0.0;

    // ✅ 1. Build message model
    ChatMessageModel *msg = [ChatMessageModel new];
    msg.ID = [GM cleanID];
    if (![self pp_applyOutgoingIdentityToMessage:msg]) {
        if (self.currentRecordingURL.isFileURL) {
            [[NSFileManager defaultManager] removeItemAtURL:self.currentRecordingURL
                                                       error:nil];
        }
        self.currentRecordingURL = nil;
        self.didFinishRecordingOnce = NO;
        return;
    }
    msg.timestamp = [NSDate date];
    msg.status = ChatMessageStatusSending;
    msg.messageType = ChatMessageTypeAudio;
    msg.isLocalPending = YES;
    [self pp_applyPendingReplyToMessage:msg clearAfterApplying:YES];
    [self updateMessageStatus:msg];
    // 🔑 LOCAL FILE FIRST
    msg.fileURL = self.currentRecordingURL.absoluteString;
    msg.mediaDuration = duration;

    // ✅ GENERATE WAVEFORM BEFORE UPLOAD
    NSArray *samples =
    [WaveformGenerator samplesFromAudioURL:self.currentRecordingURL count:40];

    msg.waveformSamples = samples;

    // Debug (keep temporarily)
    NSLog(@"🎧 [SEND] waveformSamples count = %lu",
          (unsigned long)msg.waveformSamples.count);

    /*
     
     #pragma mark - Send

     - (void)sendRecordingPreview
     {
         if (!self.currentRecordingURL) return;

         //NSTimeInterval duration = self.previewPlayer.duration;
         NSTimeInterval duration =
             [[NSDate date] timeIntervalSinceDate:self.recordingStartDate];

         ChatMessageModel *msg = [ChatMessageModel new];
         msg.ID = [GM cleanID];
         msg.senderID = UserManager.sharedManager.currentUser.ID;
         msg.receiverID = self.chatThread.otherUser.ID;
         msg.timestamp = [NSDate date];
         msg.messageType = ChatMessageTypeAudio;
         msg.fileURL = self.currentRecordingURL.absoluteString;
         msg.mediaDuration = duration;
         msg.mimeType = @"audio/m4a";
         
         
         NSArray *samples =
         [WaveformGenerator samplesFromAudioURL:[NSURL URLWithString:msg.fileURL] count:40];
         NSLog(@"samples %@ ",samples);
         msg.waveformSamples = samples;     // ✅ FIRST
          
         

         [self uploadAudioMessage:msg];
     }
     */
    msg.isUploading = YES;
    msg.transferProgress = 0.0;
///vvvvvv
    // ✅ INSERT IMMEDIATELY
    [self insertOutgoingMessageImmediately:msg];

    // ✅ START UPLOAD (same msg instance!)
    [self uploadAudioMessage:msg];

    [[PPChatFeedbackManager shared] playFeedbackForEvent:PPChatFeedbackEventOutgoingSend];

    // Reset input UI
    [self.inputbar resetRecordingUI];
}
#pragma mark - PPAudioPlaybackControllerDelegate

- (void)audioPlaybackControllerDidUpdate:(PPAudioPlaybackController *)controller
                               messageID:(NSString *)messageID
                                progress:(CGFloat)progress
                                duration:(NSTimeInterval)duration
                               isPlaying:(BOOL)isPlaying
{
    if (!messageID.length) return;

    NSInteger row =
        [self.messages indexOfObjectPassingTest:^BOOL(ChatMessageModel *obj,
                                                      NSUInteger idx,
                                                      BOOL *stop) {
            return [obj.ID isEqualToString:messageID];
        }];

    if (row == NSNotFound) return;

    NSIndexPath *ip = [NSIndexPath indexPathForRow:row inSection:0];

    ChatAudioMessageCell *cell =
        (ChatAudioMessageCell *)[self.tableView cellForRowAtIndexPath:ip];

    if (![cell isKindOfClass:ChatAudioMessageCell.class]) return;

    // 🔁 Update UI
    [cell applyPlaybackStateForMessageID:messageID
                                progress:progress
                                isPlaying:isPlaying
                                 duration:duration];
    
    [cell setLoading:NO];
}

#pragma mark - PPRecordingBarViewDelegate


- (void)recordingBarDidTapPlayFromLocked
{
    NSLog(@"🔒▶️ Locked play tapped → finish recording");

    // 1️⃣ Guard
    if (!self.audioRecorder || !self.audioRecorder.isRecording) {
        NSLog(@"⚠️ No active recording");
        return;
    }

    // 2️⃣ Stop live updates
    [self stopAllRecordingUpdates];

    // 3️⃣ Finish recording (IMPORTANT: stop, don’t cancel)
    [self.audioRecorder stop];
    self.audioRecorder.delegate = nil;
    self.audioRecorder = nil;

    // 4️⃣ Capture duration
    NSTimeInterval duration =
        [[NSDate date] timeIntervalSinceDate:self.recordingStartDate];

    // 5️⃣ Switch session → playback
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setActive:NO error:nil];
    [self switchAudioSessionToPlayback];

    // 6️⃣ Prepare preview (NO PLAY)
    NSError *err = nil;
    self.previewPlayer =
        [[AVAudioPlayer alloc] initWithContentsOfURL:self.currentRecordingURL
                                               error:&err];

    if (err || !self.previewPlayer) {
        NSLog(@"❌ Preview init failed %@", err);
        return;
    }

    self.previewPlayer.delegate = self;
    [self.previewPlayer prepareToPlay];
    

    [self  startPreviewDisplayLink];
    [self pp_showRecordingPreviewWithURL:self.currentRecordingURL duration:duration];
    // 7️⃣ UI → Preview state (paused)
    [self.inputbar.recordingBar prepareForPreview];
    
    [self.inputbar updateRecordingDuration:duration];
    [self.inputbar.recordingBar.waveformView loadWaveformFromAudioURL:self.currentRecordingURL];
    NSLog(@"✅ Recording finished → preview ready (%.2fs)", duration);
}


- (void)recordingBarDidTogglePlayback
{
    if (!self.previewPlayer) return;

    if (self.previewPlayer.isPlaying) {

        // ⏸ Pause
        [self.previewPlayer pause];
        [self stopPreviewDisplayLink];

        [self.inputbar.recordingBar setPlaying:NO animated:YES];

    } else {

        // ▶️ Play (FIRST TIME OR REPLAY)
        if (self.previewPlayer.currentTime <= 0.01) {
            self.previewPlayer.currentTime = 0; // safety
        }

        [self.previewPlayer play];
        [self startPreviewDisplayLink];   // 🔥 THIS WAS MISSING

        [self.inputbar.recordingBar setPlaying:YES animated:YES];
    }
}


#pragma mark - PPAudioPlaybackControllerDelegate

- (void)audioPlaybackControllerDidUpdateProgress:(CGFloat)progress
                                       isPlaying:(BOOL)isPlaying
{
    [self.inputbar.recordingBar.waveformView setPlaybackProgress:progress];
}
- (void)inputBarDidToggleRecordingPreview:(PPChatInputBarView *)bar
{
    if (!self.previewPlayer) return;

        if (self.isPreviewPlaying) {
            [self pausePreviewPlayback];
        } else {
            [self startPreviewPlayback];
        }
}

- (void)startPreviewPlayback
{
    if (!self.previewPlayer) return;

    if (!self.previewPlayer.isPlaying) {
        [self.previewPlayer play];
    }

    self.isPreviewPlaying = YES;

    [self startPreviewDisplayLink];

    [self.inputbar.recordingBar setPlaying:YES animated:YES];
}


- (void)startPreviewDisplayLink
{
    [self stopPreviewDisplayLink];

    self.previewDisplayLink =
        [CADisplayLink displayLinkWithTarget:self
                                    selector:@selector(updatePreviewProgress)];
    [self.previewDisplayLink addToRunLoop:[NSRunLoop mainRunLoop]
                                  forMode:NSRunLoopCommonModes];
}



- (void)stopPreviewPlaybackFinished
{
    [self stopPreviewDisplayLink];

    self.isPreviewPlaying = NO;

    self.previewPlayer.currentTime = 0;
    [self.inputbar.recordingBar.waveformView setPlaybackProgress:1.0];

    [self.inputbar.recordingBar setPlaying:NO animated:YES];
}


- (void)stopPreviewDisplayLink
{
    [self.previewDisplayLink invalidate];
    self.previewDisplayLink = nil;
   // [self.inputbar.recordingBar setPlaying:NO animated:YES];
}
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    [self stopPreviewDisplayLink];

    self.isPreviewPlaying = NO;

    // Reset player
    self.previewPlayer.currentTime = 0;

    // Waveform full → reset
    [self.inputbar.recordingBar.waveformView setPlaybackProgress:0.0];

    // Time reset
    [self.inputbar updateRecordingDuration:0];

    [self.inputbar.recordingBar setPlaying:NO animated:YES];
}
- (void)updatePreviewProgress
{
    if (!self.previewPlayer || !self.previewPlayer.isPlaying) return;

    NSTimeInterval current = self.previewPlayer.currentTime;
    NSTimeInterval total   = self.previewPlayer.duration;

    if (total <= 0) return;

    CGFloat progress = current / total;

    // 🔥 Waveform fill
    [self.inputbar.recordingBar.waveformView
        setPlaybackProgress:progress];

    // ⏱ Time label
    [self.inputbar updateRecordingDuration:current];
}



- (void)pausePreviewPlayback
{
    if (!self.previewPlayer) return;

    [self.previewPlayer pause];

    self.isPreviewPlaying = NO;

    [self stopPreviewDisplayLink];

    [self.inputbar.recordingBar setPlaying:NO animated:YES];
}


- (void)pp_showRecordingPreviewWithURL:(NSURL *)url
                              duration:(NSTimeInterval)duration
{
    
    
    if (self.audioRecorder) {
        [self.audioRecorder stop];
        self.audioRecorder.delegate = nil;
        self.audioRecorder = nil;
    }

    [self stopSilenceDetection];
    [self stopRecordingTimer];

    // IMPORTANT: deactivate record session first
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setActive:NO error:nil];

    [self switchAudioSessionToPlayback];

    NSError *err = nil;
    self.previewPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&err];

    if (err || !self.previewPlayer) {
        NSLog(@"❌ Preview player error %@", err);
        return;
    }

    self.previewPlayer.delegate = self;
    [self.previewPlayer prepareToPlay];
    self.previewState = PPRecordingPreviewStatePaused;

    // Show PREVIEW UI
    [self.inputbar.recordingBar setRecordingState:PPRecordingBarStatePreview animated:YES];

    NSLog(@"🎧 Preview ready (%0.2fs)", duration);
}

- (void)stopAllRecordingUpdates
{
    // 🛑 Stop waveform updates
    [self stopRecordingWaveUpdates];

    // 🛑 Stop duration timer
    [self pp_stopRecordingTimer];

    // 🛑 Safety
    self.recordingWaveDisplayLink = nil;
    self.recordingTimer = nil;
}

- (void)startRecordingWaveUpdates
{
    self.didFinishRecordingOnce = NO;

    [self stopRecordingWaveUpdates];

    self.recordingWaveDisplayLink =
        [CADisplayLink displayLinkWithTarget:self
                                    selector:@selector(updateRecordingWave)];
    [self.recordingWaveDisplayLink addToRunLoop:[NSRunLoop mainRunLoop]
                                        forMode:NSRunLoopCommonModes];
}

- (void)updateRecordingWave
{
    if (!self.audioRecorder || !self.audioRecorder.isRecording) return;

    [self.audioRecorder updateMeters];

    // Average power: -160 (silence) → 0 (max)
    float avgPower = [self.audioRecorder averagePowerForChannel:0];

    // Normalize to 0.0 → 1.0
    float normalized = (avgPower + 60.0f) / 60.0f;
    normalized = MAX(0.0f, MIN(1.0f, normalized));

    // Gentle floor to avoid flat line
    normalized = MAX(normalized, 0.05f);

    // Forward to input bar
    [self.inputbar appendRecordingWaveSample:normalized];
}

- (void)stopRecordingWaveUpdates
{
    [self.recordingWaveDisplayLink invalidate];
    self.recordingWaveDisplayLink = nil;
}
 
- (void)pp_cancelRecording
{
    [self stopAllRecordingUpdates]; // 🔥 ADD THIS

    [self.audioRecorder stop];
    self.audioRecorder = nil;

    if (self.currentRecordingURL) {
        [[NSFileManager defaultManager]
         removeItemAtURL:self.currentRecordingURL error:nil];
    }

    self.currentRecordingURL = nil;
    self.swiftUIRecordingDuration = 0.0;
    [self.inputbar.recordingBar setRecordingState:PPRecordingBarStateHidden animated:YES];
}

#pragma mark - Preview


/*
 
 #pragma mark - Send

 - (void)sendRecordingPreview
 {
     if (!self.currentRecordingURL) return;

     //NSTimeInterval duration = self.previewPlayer.duration;
     NSTimeInterval duration =
         [[NSDate date] timeIntervalSinceDate:self.recordingStartDate];

     ChatMessageModel *msg = [ChatMessageModel new];
     msg.ID = [GM cleanID];
     msg.senderID = UserManager.sharedManager.currentUser.ID;
     msg.receiverID = self.chatThread.otherUser.ID;
     msg.timestamp = [NSDate date];
     msg.messageType = ChatMessageTypeAudio;
     msg.fileURL = self.currentRecordingURL.absoluteString;
     msg.mediaDuration = duration;
     msg.mimeType = @"audio/m4a";
     
     
     NSArray *samples =
     [WaveformGenerator samplesFromAudioURL:[NSURL URLWithString:msg.fileURL] count:40];
     NSLog(@"samples %@ ",samples);
     msg.waveformSamples = samples;     // ✅ FIRST
      
     

     [self uploadAudioMessage:msg];
 }
 */

#pragma mark - Upload

- (void)uploadAudioMessage:(ChatMessageModel *)msg
{
    if (!msg) return;

    if (!PPChatRequiresBelowIOS26StorageCredentialPreflight()) {
        // iOS 26+ approved path: preserve the existing upload implementation.
        [self pp_uploadAudioMessageApprovedIOS26Path:msg];
        return;
    }

    __weak typeof(self) weakSelf = self;
    PPChatEnsureBelowIOS26StorageCredentialReadiness(^(NSError * _Nullable authError) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (authError) {
            [strongSelf handleSendFailureForMessage:msg
                                              error:authError
                                        retryAction:^{
                [strongSelf uploadAudioMessage:msg];
            }];
            return;
        }

        [strongSelf pp_uploadAudioMessageApprovedIOS26Path:msg];
    });
}

- (void)pp_uploadAudioMessageApprovedIOS26Path:(ChatMessageModel *)msg
{
    if (!msg) return;

    NSURL *localURL = [NSURL URLWithString:msg.fileURL];
    NSData *data = [NSData dataWithContentsOfURL:localURL];
    if (!data) {
        [self handleSendFailureForMessage:msg
                                    error:nil
                              retryAction:^{
            [self uploadAudioMessage:msg];
        }];
        return;
    }

    FIRStorageReference *ref =
    [[[FIRStorage storage] reference]
     child:[NSString stringWithFormat:@"chat_media/audio/%@.m4a", msg.ID]];

    FIRStorageMetadata *metadata = [FIRStorageMetadata new];
    metadata.contentType = @"audio/mp4";
    msg.mimeType = metadata.contentType;
    FIRStorageUploadTask *task =
    [ref putData:data metadata:metadata];

    msg.isUploading = YES;
    msg.transferProgress = 0;
    msg.status = ChatMessageStatusSending;
    msg.isLocalPending = YES;
    [self updateMessageStatus:msg];

    __weak typeof(self) weakSelf = self;

    [task observeStatus:FIRStorageTaskStatusProgress handler:^(FIRStorageTaskSnapshot *snap) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (snap.progress.totalUnitCount > 0) {
            msg.transferProgress =
                (CGFloat)snap.progress.completedUnitCount /
                (CGFloat)snap.progress.totalUnitCount;
        }

        NSInteger row = [strongSelf.messages indexOfObject:msg];
        if (row == NSNotFound) return;

        NSIndexPath *ip =
            [NSIndexPath indexPathForRow:row inSection:0];

        ChatAudioMessageCell *cell =
            (ChatAudioMessageCell *)[strongSelf.tableView cellForRowAtIndexPath:ip];

        if ([cell isKindOfClass:ChatAudioMessageCell.class]) {
            [cell setLoading:YES];
        }

    }];

    [task observeStatus:FIRStorageTaskStatusFailure handler:^(FIRStorageTaskSnapshot *snap) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf handleSendFailureForMessage:msg
                                          error:snap.error
                                    retryAction:^{
            [strongSelf uploadAudioMessage:msg];
        }];
    }];
    
   
    [task observeStatus:FIRStorageTaskStatusSuccess handler:^(FIRStorageTaskSnapshot *snap) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        [ref downloadURLWithCompletion:^(NSURL *URL, NSError *error) {
            if (!URL || error) {
                [strongSelf handleSendFailureForMessage:msg
                                                  error:error
                                            retryAction:^{
                    [strongSelf uploadAudioMessage:msg];
                }];
                return;
            }

            msg.fileURL = URL.absoluteString;
            msg.isUploading = NO;
            msg.transferProgress = 1.0;
            msg.status = ChatMessageStatusSending;
            msg.isLocalPending = YES;
            NSLog(@"🎧 [SEND] waveformSamples count = %lu",
                  (unsigned long)msg.waveformSamples.count);

            [strongSelf ensureThreadThen:^(NSString *threadID) {
                [[ChManager sharedManager]
                 sendMessage:msg
                 inThread:threadID
                 senderID:msg.senderID
                 completion:^(NSError * _Nullable sendError) {
                    if (sendError) {
                        [strongSelf handleSendFailureForMessage:msg
                                                          error:sendError
                                                    retryAction:^{
                            msg.fileURL = localURL.absoluteString;
                            [strongSelf uploadAudioMessage:msg];
                        }];
                        return;
                    }

                    msg.isLocalPending = NO;
                    msg.status = ChatMessageStatusSent;
                    [strongSelf updateMessageStatus:msg];

                    if (localURL.isFileURL) {
                        [[NSFileManager defaultManager] removeItemAtURL:localURL
                                                                   error:nil];
                    }
                    if ([strongSelf.currentRecordingURL isEqual:localURL]) {
                        strongSelf.currentRecordingURL = nil;
                    }

                    NSInteger row = [strongSelf.messages indexOfObject:msg];
                    if (row == NSNotFound) return;
                    NSIndexPath *ip =
                        [NSIndexPath indexPathForRow:row inSection:0];
                    ChatAudioMessageCell *cell =
                        (ChatAudioMessageCell *)[strongSelf.tableView cellForRowAtIndexPath:ip];
                    if ([cell isKindOfClass:ChatAudioMessageCell.class]) {
                        [cell setLoading:NO];
                    }
                 }];
            }];
            
        }];
    }];
}

#pragma mark - Timer

- (void)pp_startRecordingTimer
{
    [self pp_stopRecordingTimer];
    self.recordingTimer =
    [NSTimer scheduledTimerWithTimeInterval:1
                                     target:self
                                   selector:@selector(pp_tickRecording)
                                   userInfo:nil
                                    repeats:YES];
}

- (void)pp_stopRecordingTimer
{
    [self.recordingTimer invalidate];
    self.recordingTimer = nil;
}

- (void)pp_tickRecording
{
    NSTimeInterval t =
    [[NSDate date] timeIntervalSinceDate:self.recordingStartDate];

    [self.inputbar updateRecordingDuration:t];
}

#pragma mark - Utils

- (NSURL *)pp_newRecordingURL
{
    NSString *name =
    [NSString stringWithFormat:@"voice_%@.m4a", NSUUID.UUID.UUIDString];
    return [NSURL fileURLWithPath:
            [NSTemporaryDirectory() stringByAppendingPathComponent:name]];
}

/* ******************************************************************************************************************************************************************** */
 

// SAFETY INIT: always create thread object, never nil
- (instancetype)initWithChatThread:(ChatThreadModel *)thread {
    self = [super init];
    if (self) {
        self.chatThread = thread ?: [ChatThreadModel new];
        self.messages = [NSMutableArray array];
        self.lastKnownStatuses = [NSMutableDictionary dictionary];
        self.lastMessageIDs = @[];
        self.isViewVisible = NO;
        self.isObservingMessages = NO;
        self.lastMessageCount = 0;
        self.isKeyboardVisible = NO;
        self.didFinishInitialLoad = NO;
        self.didMarkMessagesAsRead = NO;
        self.messagePageLimit = PPChatInitialMessagePageLimit;
    }
    return self;
}

- (void)ensureThreadThen:(void (^)(NSString *threadID))block {

    // ✅ Thread already exists (load case)
    if (self.chatThread.ID.length > 0) {

        [self startObservingMessagesIfNeeded];
        if (block) block(self.chatThread.ID);
        
        return;
    }

    // ⬇️ Thread does NOT exist (new chat)
    UserModel *otherUser = self.threadOtherUser ?: self.chatThread.otherUser;
    if (!otherUser) {
        NSLog(@"❌ [Chat] Missing other user. Cannot create thread.");
        [self setInitialLoadingVisible:NO];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [[ChManager sharedManager]
     createOrGetChatThreadWithUser:otherUser
     completion:^(ChatThreadModel *thread, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error || !thread.ID.length) {
            NSLog(@"❌ Failed to create thread");
            [strongSelf setInitialLoadingVisible:NO];
            return;
        }

        strongSelf.chatThread = thread;
        if (strongSelf.isViewVisible) {
            [ChManager sharedManager].activeThreadID = thread.ID;
        }

        if (strongSelf.typingController) {
            [strongSelf.typingController attachThreadID:thread.ID];
        }

        [strongSelf startObservingMessagesIfNeeded];
        // Resolve other user safely (NOW thread exists)
        if (!strongSelf.threadOtherUser) {
            strongSelf.threadOtherUser =
            [ChatThreadModel resolveOtherUserFromThread:strongSelf.chatThread];
        }

        NSString *presenceUserID = [strongSelf resolvedOtherUserPresenceID];
        if (strongSelf.isViewVisible &&
            presenceUserID.length > 0 &&
            !strongSelf.userStatusListener) {
            [strongSelf observeUserStatus:presenceUserID];
        }

        // Attach typing controller ONCE, safely
        if (!strongSelf.typingController &&
            strongSelf.chatThread.ID.length &&
            strongSelf.threadOtherUser.ID.length) {

            strongSelf.typingController =
            [[ChTypingController alloc] initWithThreadID:strongSelf.chatThread.ID
                                                myUserID:UserManager.sharedManager.currentUser.ID
                                             otherUserID:strongSelf.threadOtherUser.ID];

            __weak typeof(strongSelf) weakStrongSelf = strongSelf;
            strongSelf.typingController.onTypingChanged = ^(BOOL isTyping) {
                if (!weakStrongSelf.isKeyboardVisible && ![weakStrongSelf isNearBottom]) return;
                isTyping
                ? [weakStrongSelf.typingIndicatorView startAnimating]
                : [weakStrongSelf.typingIndicatorView stopAnimating];
            };

            [strongSelf.typingController attachThreadID:strongSelf.chatThread.ID];
        }
        


        if (block) block(thread.ID);
    }];
}





// Helper: Returns YES if user is near bottom of table (for typing indicator)
- (BOOL)isNearBottom {
    if (!self.tableView) return YES;

    CGFloat contentHeight = self.tableView.contentSize.height;
    CGFloat tableHeight = self.tableView.bounds.size.height;
    CGFloat offsetY = self.tableView.contentOffset.y;
    CGFloat bottomInset = self.tableView.adjustedContentInset.bottom;

    // Distance from bottom
    CGFloat distanceFromBottom =
    contentHeight - (offsetY + tableHeight - bottomInset);

    // Threshold: 120px (matches chat apps behavior)
    return distanceFromBottom < 220.0;
}

#pragma mark - App State (Preview Safety)

- (void)registerAppStateObservers
{
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(handleAppWillResignActive)
     name:UIApplicationWillResignActiveNotification
     object:nil];

    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(handleAppDidEnterBackground)
     name:UIApplicationDidEnterBackgroundNotification
     object:nil];

    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(handleAppDidBecomeActive)
     name:UIApplicationDidBecomeActiveNotification
     object:nil];
}

- (void)unregisterAppStateObservers
{
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:UIApplicationWillResignActiveNotification
     object:nil];

    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:UIApplicationDidEnterBackgroundNotification
     object:nil];

    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:UIApplicationDidBecomeActiveNotification
     object:nil];
}

- (void)handleAppWillResignActive
{
    [self stopRecordingPreviewIfNeeded];
}

- (void)handleAppDidEnterBackground
{
    [self stopRecordingPreviewIfNeeded];
}

- (void)handleAppDidBecomeActive
{
    if (!self.isViewVisible) return;

    [self startObservingMessagesIfNeeded];
    [self scheduleMessageResubscribe];

    if (self.didFinishInitialLoad) {
        [self activateRealtimeAfterInitialLoadIfNeeded];
    }
}

- (void)stopRecordingPreviewIfNeeded
{
    if (!self.previewPlayer) return;

    if (self.previewPlayer.isPlaying) {
        [self.previewPlayer stop];
    }

    self.previewPlayer.currentTime = 0;
    self.isPreviewPlaying = NO;

    [self stopPreviewDisplayLink];

    // Reset waveform + UI
    [self.inputbar.recordingBar.waveformView setPlaybackProgress:0.0];
    [self.inputbar.recordingBar setPlaying:NO animated:NO];

    NSLog(@"🛑 Preview auto-stopped (app background)");
}




- (void)sendImageFile:(UIImage *)image
{
    if (!image) return;

    ChatMessageModel *msg = [[ChatMessageModel alloc] init];
    msg.ID = [GM cleanID];
    if (![self pp_applyOutgoingIdentityToMessage:msg]) return;
    msg.timestamp = [NSDate date];
    msg.status = ChatMessageStatusSending;
    msg.messageType = ChatMessageTypeImage;
    [self pp_applyPendingReplyToMessage:msg clearAfterApplying:YES];
    msg.mediaWidth = image.size.width;
    msg.mediaHeight = image.size.height;
    if (msg.mediaWidth > 0 && msg.mediaHeight > 0) {
        msg.mediaAspectRatio = msg.mediaHeight / msg.mediaWidth;
    }
    msg.isUploading = YES;
    msg.isLocalPending = YES;
    msg.transferProgress = 0;
    CGFloat pixelCount = image.size.width * image.size.height;
    msg.localImage = (pixelCount <= 4000000.0) ? image : nil;
    msg.cachedMediaHeight =
        ChatMediaHeight([self resolvedMediaMaxBubbleWidth],
                        msg.mediaWidth,
                        msg.mediaHeight);

    [self insertOutgoingMessageImmediately:msg];
    [[PPChatFeedbackManager shared] playFeedbackForEvent:PPChatFeedbackEventOutgoingSend];

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            UIImage *normalized = [ChManager normalizedImage:image] ?: image;
            UIImage *displayImage =
                ChatPreparedImageForUpload(normalized, 1280.0f) ?: normalized;
            UIImage *imageToSend =
                ChatPreparedImageForUpload(normalized, 2048.0f) ?: displayImage;

            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf || !imageToSend) return;
                if (![strongSelf.messages containsObject:msg]) return;

                msg.localImage = displayImage;
                msg.mediaWidth = displayImage.size.width;
                msg.mediaHeight = displayImage.size.height;
                if (msg.mediaWidth > 0 && msg.mediaHeight > 0) {
                    msg.mediaAspectRatio = msg.mediaHeight / msg.mediaWidth;
                }
                msg.cachedMediaHeight =
                    ChatMediaHeight([strongSelf resolvedMediaMaxBubbleWidth],
                                    msg.mediaWidth,
                                    msg.mediaHeight);

                NSInteger row = [strongSelf.messages indexOfObject:msg];
                if (row != NSNotFound) {
                    NSIndexPath *ip = [NSIndexPath indexPathForRow:row inSection:0];
                    [strongSelf.tableView reloadRowsAtIndexPaths:@[ip]
                                                 withRowAnimation:UITableViewRowAnimationNone];
                    if ([strongSelf isNearBottom]) {
                        [strongSelf scrollToBottomAnimated:NO];
                    }
                }

                [PPBlurHashGenerator generateBlurHashFromImage:displayImage
                                                    completion:^(NSString * _Nullable hash) {
                    if (hash.length > 0) {
                        msg.blurHash = hash;
                    }
                }];

                [strongSelf performImageSendForMessage:msg image:imageToSend];
            });
        }
    });
}

- (void)performImageSendForMessage:(ChatMessageModel *)msg image:(UIImage *)image
{
    if (!msg || !image) return;

    __weak typeof(self) weakSelf = self;
    dispatch_block_t sendImage = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        [strongSelf ensureThreadThen:^(NSString *threadID) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            [[ChManager sharedManager]
             sendImageMessage:image
             message:msg
             inThread:threadID
             progress:^(CGFloat progress) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    msg.isUploading = YES;
                    msg.status = ChatMessageStatusSending;
                    msg.isLocalPending = YES;
                    msg.transferProgress = MAX(0.0, MIN(progress, 1.0));

                    NSInteger row = [strongSelf.messages indexOfObject:msg];
                    if (row == NSNotFound) return;

                    NSIndexPath *ip = [NSIndexPath indexPathForRow:row inSection:0];
                    ChatImageMessageCell *cell =
                        (ChatImageMessageCell *)[strongSelf.tableView cellForRowAtIndexPath:ip];
                    if ([cell isKindOfClass:ChatImageMessageCell.class]) {
                        [cell updateUploadingState:msg];
                    }
                });
             }
             completion:^(NSError * _Nullable error) {
                if (error) {
                    [strongSelf handleSendFailureForMessage:msg
                                                      error:error
                                                retryAction:^{
                        [strongSelf performImageSendForMessage:msg image:image];
                    }];
                    return;
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    msg.isUploading = NO;
                    msg.isLocalPending = NO;
                    msg.transferProgress = 1.0;
                    msg.status = ChatMessageStatusSent;
                    [strongSelf updateMessageStatus:msg];

                    NSInteger row = [strongSelf.messages indexOfObject:msg];
                    if (row == NSNotFound) return;
                    NSIndexPath *ip = [NSIndexPath indexPathForRow:row inSection:0];
                    ChatImageMessageCell *cell =
                        (ChatImageMessageCell *)[strongSelf.tableView cellForRowAtIndexPath:ip];
                    if ([cell isKindOfClass:ChatImageMessageCell.class]) {
                        [cell updateUploadingState:msg];
                    }
                });
             }];
        }];
    };

    if (!PPChatRequiresBelowIOS26StorageCredentialPreflight()) {
        // iOS 26+ approved path: same image send flow, no compatibility preflight.
        sendImage();
        return;
    }

    PPChatEnsureBelowIOS26StorageCredentialReadiness(^(NSError * _Nullable authError) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (authError) {
            [strongSelf handleSendFailureForMessage:msg
                                              error:authError
                                        retryAction:^{
                [strongSelf performImageSendForMessage:msg image:image];
            }];
            return;
        }

        sendImage();
    });
}


- (ChatMessageModel *)buildVideoMessageWithURL:(NSURL *)videoURL
{
    ChatMessageModel *msg = [[ChatMessageModel alloc] init];
    msg.ID = [GM cleanID];
    if (![self pp_applyOutgoingIdentityToMessage:msg]) return nil;
    msg.timestamp = [NSDate date];
    msg.status = ChatMessageStatusSending;
    msg.messageType = ChatMessageTypeVideo;
    [self pp_applyPendingReplyToMessage:msg clearAfterApplying:YES];

    // 🔑 LOCAL VIDEO FIRST
    msg.fileURL = videoURL.absoluteString;
    msg.localVideoURL = videoURL;          // ⬅️ important
    msg.isUploading = YES;
    msg.isLocalPending = YES;
    msg.transferProgress = 0.0;

    // Extract size (for layout)
    AVAsset *asset = [AVAsset assetWithURL:videoURL];
    AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    if (track) {
        CGSize size =
        CGSizeApplyAffineTransform(track.naturalSize, track.preferredTransform);
        msg.mediaWidth  = fabs(size.width);
        msg.mediaHeight = fabs(size.height);
    }

    if(!msg.thumbnailImage)
    [self generateVideoThumbnail:videoURL completion:^(UIImage * _Nullable img) {
        if(img)
        {
            msg.thumbnailImage = img;
        }
    }];
    // Cache height immediately
    CGFloat maxWidth = [self resolvedMediaMaxBubbleWidth];
    msg.cachedMediaHeight =
        ChatMediaHeight(maxWidth, msg.mediaWidth, msg.mediaHeight);

    return msg;
}




 - (void)presentSourcePickerForMediaType:(NSString *)mediaType
{
    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:nil
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    BOOL isVideo = [mediaType isEqualToString:UTTypeMovie.identifier];
    NSString *cameraTitle = isVideo ? @"Record video" : @"Take photo";
    NSString *libraryTitle = isVideo ? kLang(@"VideoFile") : kLang(@"imageFile");

    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [sheet addAction:[UIAlertAction actionWithTitle:cameraTitle
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction * _Nonnull action) {
            [PPPermissionHelper requestCameraPermissionFromViewController:self
                                                              completion:^(BOOL granted) {
                if (granted) {
                    [self presentCameraForMediaType:mediaType];
                }
            }];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:libraryTitle
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction * _Nonnull action) {
        [self presentMediaPickerForType:mediaType];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    sheet.popoverPresentationController.sourceView = self.inputbar;
    sheet.popoverPresentationController.sourceRect = self.inputbar.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)presentCameraForMediaType:(NSString *)mediaType
{
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    picker.modalPresentationStyle = UIModalPresentationFullScreen;
    picker.videoQuality = UIImagePickerControllerQualityTypeMedium;
    picker.videoMaximumDuration = 120.0;

    if ([mediaType isEqualToString:UTTypeMovie.identifier]) {
        picker.mediaTypes = @[UTTypeMovie.identifier];
        picker.cameraCaptureMode = UIImagePickerControllerCameraCaptureModeVideo;
    } else {
        picker.mediaTypes = @[UTTypeImage.identifier];
        picker.cameraCaptureMode = UIImagePickerControllerCameraCaptureModePhoto;
    }

    [self presentViewController:picker animated:YES completion:nil];
}

- (void)presentImagePreviewWithImage:(UIImage *)image
{
    if (!image) return;

    PPMediaPreviewController *vc =
        [[PPMediaPreviewController alloc] initWithImage:image];

    __weak typeof(self) weakSelf = self;
    vc.onSendImage = ^(UIImage *previewImage) {
        [weakSelf sendImageFile:previewImage];
    };

    [self presentViewController:vc animated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info
{
    NSString *mediaType = info[UIImagePickerControllerMediaType];

    [picker dismissViewControllerAnimated:YES completion:^{
        if ([mediaType isEqualToString:UTTypeImage.identifier]) {
            UIImage *image = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
            [self presentImagePreviewWithImage:image];
            return;
        }

        if ([mediaType isEqualToString:UTTypeMovie.identifier]) {
            NSURL *videoURL = info[UIImagePickerControllerMediaURL];
            NSURL *localURL = [self copyVideoToTemp:videoURL];
            if (!localURL) {
                [PPHUD showError:kLang(@"SomethingWentWrong")];
                return;
            }
            [self presentVideoPreviewWithLocalURL:localURL];
        }
    }];
}

// iOS Photo/Video Picker Delegate
- (void)picker:(PHPickerViewController *)picker
didFinishPicking:(NSArray<PHPickerResult *> *)results
{

    [picker dismissViewControllerAnimated:YES completion:nil];

    if (results.count == 0) return;

    PHPickerResult *result = results.firstObject;
    NSItemProvider *provider = result.itemProvider;

    // IMAGE
    if ([provider hasItemConformingToTypeIdentifier:UTTypeImage.identifier]) {

        [provider loadObjectOfClass:UIImage.class
                  completionHandler:^(UIImage *image, NSError *error) {
            if (!image || error) return;

            dispatch_async(dispatch_get_main_queue(),
 ^{
                [self presentImagePreviewWithImage:image];
            });
        }];
        return;
    }

     
    // VIDEO
    if ([provider hasItemConformingToTypeIdentifier:UTTypeMovie.identifier]) {

        __weak typeof(self) weakSelf = self;

        [provider loadFileRepresentationForTypeIdentifier:UTTypeMovie.identifier
                                        completionHandler:^(NSURL *url, NSError *error) {

            if (!url || error) {
                NSLog(@"❌ Video load failed: %@", error);
                return;
            }

            // ⛔️ DO NOT TOUCH UI HERE (background thread)
            NSURL *localURL = [weakSelf copyVideoToTemp:url];
            if (!localURL) return;

            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf presentVideoPreviewWithLocalURL:localURL];
            });
        }];
    }
}
- (void)presentVideoPreviewWithLocalURL:(NSURL *)localURL
{
    PPMediaPreviewController *vc =
        [[PPMediaPreviewController alloc] initWithVideoURL:localURL];

    __weak typeof(self) weakSelf = self;

    vc.onSendVideo = ^(NSURL *url) {
        [weakSelf handleConfirmedVideoSendWithURL:url];
    };

    [self presentViewController:vc animated:YES completion:nil];
}

- (void)handleConfirmedVideoSendWithURL:(NSURL *)videoURL
{
    if (!videoURL) return;

    NSNumber *fileSizeValue = nil;
    NSError *fileError = nil;
    if ([videoURL getResourceValue:&fileSizeValue
                            forKey:NSURLFileSizeKey
                             error:&fileError] &&
        fileSizeValue.unsignedLongLongValue > (120ULL * 1024ULL * 1024ULL)) {
        [PPHUD showError:@"Video is too large. Please choose a smaller file."];
        return;
    }

    // 1️⃣ Build message ONCE
    ChatMessageModel *msg =
        [self buildVideoMessageWithURL:videoURL];
    if (!msg) return;

    __weak typeof(self) weakSelf = self;

    // 2️⃣ Insert immediately (spinner visible)
    dispatch_block_t beginVideoSend = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        [strongSelf ensureThreadThen:^(NSString *threadID) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            [strongSelf insertOutgoingMessageImmediately:msg];
            [[PPChatFeedbackManager shared] playFeedbackForEvent:PPChatFeedbackEventOutgoingSend];

            // 3️⃣ Generate thumbnail async (safe)
            [strongSelf generateVideoThumbnail:videoURL
                                    completion:^(UIImage *thumb) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;

                if (!thumb) return;

                msg.thumbnailImage = thumb;

                NSInteger row = [strongSelf.messages indexOfObject:msg];
                if (row == NSNotFound) return;

                NSIndexPath *ip =
                    [NSIndexPath indexPathForRow:row inSection:0];
                msg.status = ChatMessageStatusSending;
                ChatVideoMessageCell *cell =
                    (ChatVideoMessageCell *)
                    [strongSelf.tableView cellForRowAtIndexPath:ip];
                [strongSelf updateMessageStatus:msg];
                if ([cell isKindOfClass:ChatVideoMessageCell.class]) {
                    [cell updateThumbnail:thumb];
                }

                [ChManager.sharedManager uploadVideoThumbnail:thumb
                                                    messageID:msg.ID
                                                   completion:^(NSString * _Nonnull thumbURL) {
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (!strongSelf) return;
                    if (thumbURL.length > 0) {
                        msg.thumbnailURL = thumbURL;
                    }

                    // 4️⃣ Upload independently
                    [strongSelf uploadVideoMessage:msg];
                }];

            }];
        }];
    };

    if (!PPChatRequiresBelowIOS26StorageCredentialPreflight()) {
        // iOS 26+ approved path: same video send flow, no compatibility preflight.
        beginVideoSend();
        return;
    }

    PPChatEnsureBelowIOS26StorageCredentialReadiness(^(NSError * _Nullable authError) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (authError) {
            [strongSelf handleSendFailureForMessage:msg
                                              error:authError
                                        retryAction:^{
                [strongSelf handleConfirmedVideoSendWithURL:videoURL];
            }];
            return;
        }

        beginVideoSend();
    });     
}



- (void)insertOutgoingMessageImmediately:(ChatMessageModel *)msg
{
    if (!msg) return;
    BOOL shouldStickToBottom = [self isNearBottom];
    NSInteger index = self.messages.count;
    [self.messages addObject:msg];
    self.lastKnownStatuses[msg.ID] = @(msg.status);
    [self pp_updateChatEmptyStateAnimated:YES];

    NSIndexPath *ip =
        [NSIndexPath indexPathForRow:index inSection:0];

    [UIView performWithoutAnimation:^{
        [self.tableView beginUpdates];
        [self.tableView insertRowsAtIndexPaths:@[ip]
                              withRowAnimation:UITableViewRowAnimationNone];
        [self.tableView endUpdates];
    }];

    if (!self.didFinishInitialLoad) {
        self.didFinishInitialLoad = YES;
        [self setInitialLoadingVisible:NO];
    }

    if (shouldStickToBottom) {
        [self scrollToBottomAnimated:NO];
    }
}
 



// Deprecated: replaced by closure block with BlurHash

- (void)openVideoFullscreen:(ChatVideoMessageCell *)cell
                    message:(ChatMessageModel *)msg
{
    NSURL *url = [NSURL URLWithString:msg.fileURL];
    if (!url) return;

    CGRect fromFrame = [cell thumbnailFrameInWindow];

    PPFullscreenVideoController *vc =
    [[PPFullscreenVideoController alloc] initWithURL:url
                                           fromFrame:fromFrame];

    vc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:vc animated:YES completion:nil];
}


// Production-ready video upload with UI/main thread safety, duplicate guard, error handling, and single Firestore send
- (void)uploadVideoMessage:(ChatMessageModel *)msg
{
    if (!msg) return;

    if (!PPChatRequiresBelowIOS26StorageCredentialPreflight()) {
        // iOS 26+ approved path: preserve the existing upload implementation.
        [self pp_uploadVideoMessageApprovedIOS26Path:msg];
        return;
    }

    __weak typeof(self) weakSelf = self;
    PPChatEnsureBelowIOS26StorageCredentialReadiness(^(NSError * _Nullable authError) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (authError) {
            [strongSelf handleSendFailureForMessage:msg
                                              error:authError
                                        retryAction:^{
                [strongSelf uploadVideoMessage:msg];
            }];
            return;
        }

        [strongSelf pp_uploadVideoMessageApprovedIOS26Path:msg];
    });
}

- (void)pp_uploadVideoMessageApprovedIOS26Path:(ChatMessageModel *)msg
{
    if (!msg) return;

    NSURL *localURL = msg.localVideoURL;
    if (!localURL) {
        NSLog(@"❌ Video upload aborted: localURL missing");
        [self handleSendFailureForMessage:msg
                                    error:nil
                              retryAction:^{
            [self uploadVideoMessage:msg];
        }];
        return;
    }

    static NSMutableSet<NSString *> *activeUploads;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        activeUploads = [NSMutableSet set];
    });

    if ([activeUploads containsObject:msg.ID]) {
        NSLog(@"⛔️ Duplicate upload blocked for %@", msg.ID);
        return;
    }
    [activeUploads addObject:msg.ID];

    FIRStorageReference *ref =
    [[[FIRStorage storage] reference]
     child:[NSString stringWithFormat:@"chat_media/videos/%@.mp4", msg.ID]];

    FIRStorageMetadata *metadata = [FIRStorageMetadata new];
    metadata.contentType = @"video/mp4";
    msg.mimeType = metadata.contentType;
    FIRStorageUploadTask *task = [ref putFile:localURL metadata:metadata];

    msg.isUploading = YES;
    msg.isLocalPending = YES;
    msg.status = ChatMessageStatusSending;
    msg.transferProgress = 0;
    [self updateMessageStatus:msg];

    __weak typeof(self) weakSelf = self;
    [task observeStatus:FIRStorageTaskStatusProgress handler:^(FIRStorageTaskSnapshot *snap) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || snap.progress.totalUnitCount <= 0) return;

        CGFloat progress =
            (CGFloat)snap.progress.completedUnitCount /
            (CGFloat)snap.progress.totalUnitCount;

        msg.transferProgress = progress;

        dispatch_async(dispatch_get_main_queue(), ^{
            NSInteger row = [strongSelf.messages indexOfObject:msg];
            if (row == NSNotFound) return;

            NSIndexPath *ip = [NSIndexPath indexPathForRow:row inSection:0];
            ChatVideoMessageCell *cell =
                (ChatVideoMessageCell *)[strongSelf.tableView cellForRowAtIndexPath:ip];
            if (!cell) return;
            [cell setLoading:YES];
            [cell setProgress:progress];
        });
    }];

    [task observeStatus:FIRStorageTaskStatusFailure handler:^(FIRStorageTaskSnapshot *snap) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [activeUploads removeObject:msg.ID];
        [strongSelf handleSendFailureForMessage:msg
                                          error:snap.error
                                    retryAction:^{
            [strongSelf uploadVideoMessage:msg];
        }];
    }];

    [task observeStatus:FIRStorageTaskStatusSuccess handler:^(__unused FIRStorageTaskSnapshot *snap) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        [ref downloadURLWithCompletion:^(NSURL *URL, NSError *error) {
            if (!URL || error) {
                [activeUploads removeObject:msg.ID];
                [strongSelf handleSendFailureForMessage:msg
                                                  error:error
                                            retryAction:^{
                    [strongSelf uploadVideoMessage:msg];
                }];
                return;
            }

            msg.fileURL = URL.absoluteString;
            msg.isUploading = NO;
            msg.transferProgress = 1.0;

            [strongSelf ensureThreadThen:^(NSString *threadID) {
                [ChManager.sharedManager sendMessage:msg
                                            inThread:threadID
                                            senderID:msg.senderID
                                          completion:^(NSError * _Nullable sendError) {
                    if (sendError) {
                        [activeUploads removeObject:msg.ID];
                        [strongSelf handleSendFailureForMessage:msg
                                                          error:sendError
                                                    retryAction:^{
                            [strongSelf uploadVideoMessage:msg];
                        }];
                        return;
                    }

                    msg.status = ChatMessageStatusSent;
                    msg.isLocalPending = NO;
                    [strongSelf updateMessageStatus:msg];

                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSInteger row = [strongSelf.messages indexOfObject:msg];
                        if (row == NSNotFound) return;
                        NSIndexPath *ip = [NSIndexPath indexPathForRow:row inSection:0];
                        ChatVideoMessageCell *cell =
                            (ChatVideoMessageCell *)[strongSelf.tableView cellForRowAtIndexPath:ip];
                        if (!cell) return;
                        [cell setLoading:NO];
                        [cell setProgress:1.0];
                    });

                    [activeUploads removeObject:msg.ID];
                }];
            }];
        }];
    }];
}
//uploadVideoThumbnail

- (CGFloat)resolvedMediaMaxBubbleWidth
{
    CGFloat baseWidth = self.fixedMediaMaxWidth;
    if (baseWidth <= 0.5) {
        baseWidth = self.view.bounds.size.width;
    }
    if (baseWidth <= 0.5) {
        baseWidth = UIScreen.mainScreen.bounds.size.width;
    }
    return MAX(160.0, baseWidth * 0.72);
}

- (CGSize)bubbleSizeForMediaMessage:(ChatMessageModel *)msg
{
    CGFloat maxWidth = [self resolvedMediaMaxBubbleWidth];

    CGFloat ratio = msg.mediaAspectRatio;
    if (ratio <= 0 && msg.mediaWidth > 0 && msg.mediaHeight > 0) {
        ratio = msg.mediaHeight / msg.mediaWidth;
    }

    if (ratio <= 0) {
        CGFloat cached = msg.cachedMediaHeight;
        // Legacy compatibility: old cached values included extra chrome height.
        if (cached > 220.0) {
            cached -= 44.0;
        }
        CGFloat fallbackHeight =
            cached > 0 ? MAX(140.0, MIN(cached, 420.0)) : 240.0;
        return CGSizeMake(maxWidth, fallbackHeight);
    }

    ratio = MAX(0.35, MIN(ratio, 3.2));

    CGFloat width = maxWidth;
    CGFloat height = width * ratio;

    if (height > 420.0) {
        height = 420.0;
        width = MAX(140.0, MIN(maxWidth, height / ratio));
    } else if (height < 140.0) {
        height = 140.0;
        width = MAX(140.0, MIN(maxWidth, height / ratio));
    }

    return CGSizeMake(width, height);
}

- (CGFloat)heightForMediaMessage:(ChatMessageModel *)msg
{
    CGSize mediaSize = [self bubbleSizeForMediaMessage:msg];
    CGFloat replyChromeHeight = 0.0;
    if (msg.replyToMessageID.length > 0) {
        replyChromeHeight =
            UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory)
                ? 64.0
                : 56.0;
    }
    return mediaSize.height + replyChromeHeight + (PPChatBubblePad * 2.0);
}

// Helper: Copy video to temp directory
- (NSURL *)copyVideoToTemp:(NSURL *)sourceURL
{
    if (!sourceURL) return nil;

    NSString *fileName =
    [NSString stringWithFormat:@"video_%@.mp4", NSUUID.UUID.UUIDString];

    NSString *destPath =
    [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];

    NSURL *destURL = [NSURL fileURLWithPath:destPath];

    NSError *copyError = nil;
    [[NSFileManager defaultManager]
     copyItemAtURL:sourceURL
     toURL:destURL
     error:&copyError];

    if (copyError) {
        NSLog(@"❌ Failed to copy video to temp: %@", copyError.localizedDescription);
        return nil;
    }

    return destURL;
}

- (void)generateVideoThumbnail:(NSURL *)videoURL completion:(void (^_Nullable)(UIImage * _Nullable ))completion {

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        AVAsset *asset = [AVAsset assetWithURL:videoURL];
        AVAssetImageGenerator *generator =
            [[AVAssetImageGenerator alloc] initWithAsset:asset];

        generator.appliesPreferredTrackTransform = YES;

        CGImageRef imageRef =
            [generator copyCGImageAtTime:CMTimeMakeWithSeconds(0, 600)
                              actualTime:nil
                                   error:nil];

        UIImage *thumb = imageRef
            ? [UIImage imageWithCGImage:imageRef]
            : nil;

        if (imageRef) CGImageRelease(imageRef);

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(thumb);
        });
    });
}

- (void)onMicTapped {
    NSLog(@"🎙️ [Chat] Mic tapped");
    // TODO: Start voice recording
    //[self startVoiceRecording];
}

#pragma mark - Firebase Messaging


// Observe messages, but only if threadID exists

- (CGFloat)pp_activeComposerOcclusionHeight
{
    UIView *composer = [self pp_activeChatInputBarViewForLayout];
    if (!composer || !composer.superview || composer.hidden || CGRectIsEmpty(composer.bounds)) {
        return self.baseTableInsets.bottom;
    }

    CGRect composerFrame = [composer.superview convertRect:composer.frame toView:self.view];
    CGRect tableFrame = [self.tableView.superview convertRect:self.tableView.frame toView:self.view];
    CGFloat breatheRoom = 12.0;

    if (!CGRectIsEmpty(tableFrame) &&
        CGRectGetMaxY(tableFrame) <= CGRectGetMinY(composerFrame) + 2.0) {
        return MAX(self.baseTableInsets.bottom, self.baseTableInsets.bottom + breatheRoom);
    }

    CGFloat occlusion = CGRectGetHeight(self.view.bounds) - CGRectGetMinY(composerFrame);
    return MAX(self.baseTableInsets.bottom, ceil(MAX(0.0, occlusion)) + breatheRoom);
}

- (void)pp_applyTableViewBottomInsetForActiveComposer
{
    if (!self.tableView) return;

    CGFloat bottomInset = [self pp_activeComposerOcclusionHeight];
    UIEdgeInsets contentInset = self.tableView.contentInset;
    UIEdgeInsets indicatorInset = self.tableView.scrollIndicatorInsets;

    if (fabs(contentInset.bottom - bottomInset) > 0.5) {
        contentInset.bottom = bottomInset;
        self.tableView.contentInset = contentInset;
    }
    if (fabs(indicatorInset.bottom - bottomInset) > 0.5) {
        indicatorInset.bottom = bottomInset;
        self.tableView.scrollIndicatorInsets = indicatorInset;
    }
}

- (void)pp_scrollTableViewToBottomWithoutAnimation
{
    if (!self.tableView || self.tableView.bounds.size.height <= 0.0) return;

    UIEdgeInsets insets = self.tableView.adjustedContentInset;
    CGFloat minOffsetY = -insets.top;
    CGFloat targetY = self.tableView.contentSize.height
        - self.tableView.bounds.size.height
        + insets.bottom;
    targetY = MAX(minOffsetY, targetY);
    [self.tableView setContentOffset:CGPointMake(0.0, targetY) animated:NO];
}

- (void)scrollToBottomAnimated:(BOOL)animated
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.tableView) return;

        [self.view layoutIfNeeded];
        [self.tableView layoutIfNeeded];
        [self pp_applyTableViewBottomInsetForActiveComposer];

        if (self.tableView.bounds.size.height <= 0) {
            self.pendingBottomScrollAfterLayout = YES;
            return;
        }

        void (^applyBottomOffset)(BOOL) = ^(BOOL animatedOffset) {
            if (!animatedOffset) {
                [self pp_scrollTableViewToBottomWithoutAnimation];
                return;
            }
            UIEdgeInsets insets = self.tableView.adjustedContentInset;
            CGFloat minOffsetY = -insets.top;
            CGFloat targetY = self.tableView.contentSize.height
                - self.tableView.bounds.size.height
                + insets.bottom;
            targetY = MAX(minOffsetY, targetY);
            [self.tableView setContentOffset:CGPointMake(0.0, targetY) animated:YES];
        };

        applyBottomOffset(animated);
        self.pendingBottomScrollAfterLayout = NO;

        // Extra settles to absorb async relayout from media size updates.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (!self.isViewVisible) return;
            [self.view layoutIfNeeded];
            [self.tableView layoutIfNeeded];
            applyBottomOffset(NO);
        });

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.18 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (!self.isViewVisible) return;
            [self.view layoutIfNeeded];
            [self.tableView layoutIfNeeded];
            applyBottomOffset(NO);
            self.pendingBottomScrollAfterLayout = NO;
        });
    });
}

- (void)sendChatMessageText:(NSString *)text
{
    if (text.length == 0) return;

    ChatMessageModel *msg = [[ChatMessageModel alloc] init];
    msg.ID = [GM cleanID];
    msg.text = text;
    if (![self pp_applyOutgoingIdentityToMessage:msg]) return;
    msg.timestamp = [NSDate date];
    msg.status = ChatMessageStatusSending;
    msg.messageType = ChatMessageTypeText;
    msg.isLocalPending = YES;
    [self pp_applyPendingReplyToMessage:msg clearAfterApplying:YES];

    [self insertOutgoingMessageImmediately:msg];
    [[PPChatFeedbackManager shared] playFeedbackForEvent:PPChatFeedbackEventOutgoingSend];

    [self performSendTextMessage:msg];
}

- (void)performSendTextMessage:(ChatMessageModel *)msg
{
    if (!msg) return;

    __weak typeof(self) weakSelf = self;
    [self ensureThreadThen:^(NSString *threadID) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        [[ChManager sharedManager]
         sendMessage:msg
         inThread:threadID
         senderID:msg.senderID
         completion:^(NSError *error) {
            if (error) {
                [strongSelf handleSendFailureForMessage:msg
                                                  error:error
                                            retryAction:^{
                    [strongSelf performSendTextMessage:msg];
                }];
                return;
            }

            msg.status = ChatMessageStatusSent;
            msg.isLocalPending = NO;
            [strongSelf updateMessageStatus:msg];
         }];
    }];
}

- (void)handleSendFailureForMessage:(ChatMessageModel *)msg
                              error:(NSError * _Nullable)error
                        retryAction:(dispatch_block_t)retryAction
{
    if (!msg) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        msg.isUploading = NO;
        msg.transferProgress = 0.0f;
        msg.status = ChatMessageStatusSending;
        msg.isLocalPending = YES;
        [self updateMessageStatus:msg];

        NSInteger row = [self.messages indexOfObject:msg];
        if (row != NSNotFound) {
            NSIndexPath *ip = [NSIndexPath indexPathForRow:row inSection:0];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:ip];
            if ([cell isKindOfClass:ChatVideoMessageCell.class]) {
                [(ChatVideoMessageCell *)cell setLoading:NO];
            } else if ([cell isKindOfClass:ChatAudioMessageCell.class]) {
                [(ChatAudioMessageCell *)cell setLoading:NO];
            } else if ([cell isKindOfClass:ChatImageMessageCell.class]) {
                [(ChatImageMessageCell *)cell updateUploadingState:msg];
            }
        }

        NSLog(@"❌ [ChatUI] handleSendFailureForMessage — code=%ld domain=%@ desc=%@",
              (long)error.code, error.domain, error.localizedDescription);

        NSString *hudMessage = error.localizedDescription.length > 0
            ? error.localizedDescription
            : kLang(@"SomethingWentWrong");
        [PPHUD showError:hudMessage];

        if (self.isPresentingFailureAlert) return;
        self.isPresentingFailureAlert = YES;

        NSString *retryMessage = PPChatLocalizedStringOrFallback(@"chat_retry_send_message", @"SomethingWentWrong");
        NSString *alertMsg = error.localizedDescription.length > 0
            ? [NSString stringWithFormat:@"%@\n\n%@", error.localizedDescription, retryMessage]
            : retryMessage;

        UIAlertController *alert =
            [UIAlertController alertControllerWithTitle:PPChatLocalizedStringOrFallback(@"chat_message_failed_title", @"SomethingWentWrong")
                                                message:alertMsg
                                         preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:kLang(@"cancel")
                                                  style:UIAlertActionStyleCancel
                                                handler:^(__unused UIAlertAction * _Nonnull action) {
            self.isPresentingFailureAlert = NO;
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:kLang(@"KLang_Retry")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction * _Nonnull action) {
            self.isPresentingFailureAlert = NO;
            if (retryAction) retryAction();
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}


- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    // BOOL showTyping = self.isOtherUserTyping &&
    // self.shouldShowTypingIndicator; return self.messages.count + (showTyping
    // ? 1 : 0);
    return self.messages.count;
}

- (BOOL)pp_message:(ChatMessageModel *)message canGroupWithMessage:(ChatMessageModel *)other
{
    if (!message || !other || ![message.senderID isEqualToString:other.senderID]) return NO;
    if (!message.timestamp || !other.timestamp) return YES;
    return fabs([message.timestamp timeIntervalSinceDate:other.timestamp]) <= 5.0 * 60.0;
}

- (PPBubblePosition)bubblePositionForMessageAtIndex:(NSInteger)index {
    ChatMessageModel *current = self.messages[index];

    ChatMessageModel *prev = index > 0 ? self.messages[index - 1] : nil;
    ChatMessageModel *next = index < self.messages.count - 1 ? self.messages[index + 1] : nil;

    BOOL sameAsPrev = [self pp_message:current canGroupWithMessage:prev];
    BOOL sameAsNext = [self pp_message:current canGroupWithMessage:next];

    if (!sameAsPrev && !sameAsNext) return PPBubblePositionSingle;
    if (!sameAsPrev && sameAsNext)  return PPBubblePositionFirst;
    if (sameAsPrev && sameAsNext)   return PPBubblePositionMiddle;
    return PPBubblePositionLast;
}

 
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    __weak typeof(self) weakSelf = self;
    if (indexPath.row >= (NSInteger)self.messages.count) {
        NSLog(@"❌ [Chat] messages out of bounds: row=%ld count=%lu", (long)indexPath.row, (unsigned long)self.messages.count);
        return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    }
    ChatMessageModel *msg = self.messages[indexPath.row];
    BOOL isIncoming = ![msg.senderID
                        isEqualToString:UserManager.sharedManager.currentUser.ID];
   
   
   
    PPChatGroupPosition groupPos =
        [self groupPositionForMessageAtIndex:indexPath.row];

    if (msg.isDeleted) {
        ChatMessageCell *cell =
            [tableView dequeueReusableCellWithIdentifier:@"ChatMessageCell"
                                            forIndexPath:indexPath];
        [cell configureWithMessage:kLang(@"chat_message_unsent")
                              date:msg.timestamp
                        isIncoming:isIncoming
                          maxWidth:MAX_BUBBLE_WIDTH(self.view)
                            status:msg.status
                      messageModel:msg
                     groupPosition:groupPos];
        cell.delegate = self;
        [cell.bubbleView clearReplyPreview];
        [self pp_prepareInteractionsForCell:cell message:msg];
        return cell;
    }
    
    // 🔊 AUDIO MESSAGE
    switch (msg.messageType) {

        case ChatMessageTypeAudio: {
            ChatAudioMessageCell *cell =
            [tableView dequeueReusableCellWithIdentifier:@"ChatAudioMessageCell"
                                            forIndexPath:indexPath];

            ChatMessageModel *msg = self.messages[indexPath.row];
            BOOL isIncoming = ![msg.senderID
                                isEqualToString:UserManager.sharedManager.currentUser.ID];

     
            
            // Layout
            [cell setIncoming:isIncoming
                     maxWidth:MAX_BUBBLE_WIDTH(self.view)
                       status:msg.status msg:msg groupPosition:groupPos];

            // Initial UI state
            BOOL isPlaying =
            [self.audioController.currentMessageID isEqualToString:msg.ID];

            [cell applyPlaybackStateForMessageID:msg.ID
                                        progress:msg.transferProgress
                                        isPlaying:isPlaying
                                        duration:msg.mediaDuration];
            
            [cell setTotalDuration:msg.mediaDuration];
            [self pp_applyReplyPreviewForMessage:msg
                                     toAudioCell:cell
                                      isIncoming:isIncoming];

            [cell setBottomTimeText:msg.timestamp]; // e.g. "12:41 PM" or "0:05"
                                                    // 🔥 BLOCK WIRING (THIS SOLVES EVERYTHING)
            __weak typeof(self) weakSelf = self;
            cell.onScrubToProgress = ^(CGFloat progress) {
                // Only allow scrubbing on currently playing message
                if (![weakSelf.audioController.currentMessageID
                      isEqualToString:msg.ID]) {
                    return;
                }

                NSTimeInterval duration = weakSelf.audioController.playerDuration;
                NSTimeInterval newTime = duration * progress;

                // Seek safely
                [weakSelf.audioController seekToTime:newTime];

                // Update resume cache
                weakSelf.audioResumeTimes[msg.ID] = @(newTime);
            };
            __weak typeof(cell) weakCell = cell;
            cell.onPlayPauseTapped = ^{
                NSString *msgID = msg.ID;

                // 🔁 Same message → toggle
                if ([weakSelf.audioController.currentMessageID
                     isEqualToString:msgID]) {
                    [weakSelf.audioController togglePlayPause];
                    return;
                }

                // ⛔ Stop previous message & update its UI
                NSString *oldID = weakSelf.audioController.currentMessageID;
                if (oldID.length) {

                    // Save resume time
                    weakSelf.audioResumeTimes[oldID] =
                    @(weakSelf.audioController.currentPlaybackTime);

                    // Reset old cell button UI
                    NSInteger oldRow = [weakSelf.messages
                                        indexOfObjectPassingTest:^BOOL(ChatMessageModel *o,
                                                                       NSUInteger idx, BOOL *stop) {
                        return [o.ID isEqualToString:oldID];
                    }];

                    if (oldRow != NSNotFound) {
                        NSIndexPath *oldIP = [NSIndexPath indexPathForRow:oldRow
                                                                inSection:0];

                        ChatAudioMessageCell *oldCell =
                        (ChatAudioMessageCell *)[weakSelf.tableView
                                                 cellForRowAtIndexPath:oldIP];

                        if ([oldCell isKindOfClass:ChatAudioMessageCell.class]) {
                            [oldCell setPlaying:NO];
                        }
                    }
                }
                [weakCell setLoading:YES];
                // ▶️ Play new message
                [weakSelf prepareLocalAudioForMessage:msg
                                           completion:^(NSURL *localURL) {
                    if (!localURL) {
                        [weakCell setLoading:NO];
                        return;
                    }

                    NSTimeInterval resume =
                    weakSelf.audioResumeTimes[msgID].doubleValue;

                    [weakSelf.audioController
                     playMessageID:msgID
                     url:localURL];

                    if (resume > 0) {
                        [weakSelf.audioController
                         seekToTime:resume];
                    }
                }];
            };
            [self pp_prepareInteractionsForCell:cell message:msg];
            return cell;
        }
//1628 =
            
        case ChatMessageTypeImage: {
            ChatImageMessageCell *cell =
            [tableView dequeueReusableCellWithIdentifier:@"ChatImageMessageCell"
                                            forIndexPath:indexPath];
            CGSize mediaSize = [self bubbleSizeForMediaMessage:msg];
            
            PPChatGroupPosition groupPos =
                [self groupPositionForMessageAtIndex:indexPath.row];
            
            [cell configureWithImageURL:msg.fileURL
                             isIncoming:isIncoming
                               maxWidth:mediaSize.width
                               message:msg
                         groupPosition:groupPos];
            cell.delegate = self;
            [self pp_applyReplyPreviewForMessage:msg
                                      toImageCell:cell
                                       isIncoming:isIncoming];
            [self pp_prepareInteractionsForCell:cell message:msg];
            return cell;
        }

        case ChatMessageTypeVideo: {
            ChatVideoMessageCell *cell =
            [tableView dequeueReusableCellWithIdentifier:@"ChatVideoMessageCell"
                                            forIndexPath:indexPath];
            __weak typeof(cell) weakCell = cell;
            CGSize mediaSize = [self bubbleSizeForMediaMessage:msg];
           
            
            [cell configureWithMessage:msg
                            isIncoming:isIncoming
                              maxWidth:mediaSize.width
                         groupPosition:groupPos];
            [self pp_applyReplyPreviewForMessage:msg
                                      toVideoCell:cell
                                       isIncoming:isIncoming];
        
            cell.onPlayTapped = ^{
                __strong typeof(weakCell) cell = weakCell;
                [weakSelf openVideoFullscreen:cell message:msg];
            };
            cell.onViewTapped = ^{
                __strong typeof(weakCell) cell = weakCell;
                [weakSelf openVideoFullscreen:cell message:msg];
            };
            cell.onDownloadTapped = ^{
                [weakSelf pp_downloadVideoMessage:msg];
            };
            cell.onReplyRequested = ^{
                [weakSelf pp_selectReplyMessage:msg];
            };
            [self pp_prepareInteractionsForCell:cell message:msg];
            return cell;
        }

        case ChatMessageTypeText:
        default:
            break;
    }

    // 💬 TEXT MESSAGE (unchanged)
    ChatMessageCell *cell =
    [tableView dequeueReusableCellWithIdentifier:@"ChatMessageCell"
                                    forIndexPath:indexPath];

    [cell configureWithMessage:msg.text
                          date:msg.timestamp
                    isIncoming:isIncoming
                      maxWidth:MAX_BUBBLE_WIDTH(self.view)
                        status:msg.status messageModel:msg groupPosition:groupPos];
    cell.delegate = self;
    [self pp_applyReplyPreviewForMessage:msg
                                toBubble:cell.bubbleView
                              isIncoming:isIncoming];
    [self pp_prepareInteractionsForCell:cell message:msg];
    return cell;
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row >= (NSInteger)self.messages.count) return;
    ChatMessageModel *message = self.messages[indexPath.row];
    if (message.didAnimateInsert) return;
    message.didAnimateInsert = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        cell.contentView.alpha = 1.0;
        cell.contentView.transform = CGAffineTransformIdentity;
        return;
    }
    cell.contentView.alpha = 0.0;
    cell.contentView.transform = CGAffineTransformMakeTranslation(0.0, 4.0);
    [UIView animateWithDuration:0.22
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut |
                                UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        cell.contentView.alpha = 1.0;
        cell.contentView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (PPChatGroupPosition)groupPositionForMessageAtIndex:(NSInteger)index {
    ChatMessageModel *current = self.messages[index];

    ChatMessageModel *prev =
        (index > 0) ? self.messages[index - 1] : nil;
    ChatMessageModel *next =
        (index < self.messages.count - 1) ? self.messages[index + 1] : nil;

    BOOL sameAsPrev = [self pp_message:current canGroupWithMessage:prev];
    BOOL sameAsNext = [self pp_message:current canGroupWithMessage:next];

    if (!sameAsPrev && !sameAsNext) {
        return PPChatGroupPositionSingle;
    }
    if (!sameAsPrev && sameAsNext) {
        return PPChatGroupPositionFirst;
    }
    if (sameAsPrev && sameAsNext) {
        return PPChatGroupPositionMiddle;
    }
    return PPChatGroupPositionLast;
}

#pragma mark - Cleanup

- (void)dealloc {
    [self unregisterKeyboardNotifications];
    [self.typingController stop];
    [self unregisterAppStateObservers];
    [self.messageListener remove];
    self.messageListener = nil;
    [self.userStatusListener remove];
    self.userStatusListener = nil;
    [self stopAllRecordingUpdates];
    [self stopSilenceDetection];
    [self stopPreviewDisplayLink];
    [self.previewPlayer stop];
    self.previewPlayer = nil;

    if (self.authListenerHandle) {
        [[FIRAuth auth]
         removeAuthStateDidChangeListener:self.authListenerHandle];
        self.authListenerHandle = 0;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupEditorNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(editorDidFinish:)
                                                 name:@"PPEditorBridgeDidFinish"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(editorDidCancel:)
                                                 name:@"PPEditorBridgeDidCancel"
                                               object:nil];
}
#pragma mark - Editor Notifications

- (void)editorDidFinish:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    UIImage *editedImage = userInfo[@"image"];
    
    if (!editedImage) {
        // Try to get from URL
        NSURL *fileURL = userInfo[@"url"];
        if (fileURL) {
            NSData *imageData = [NSData dataWithContentsOfURL:fileURL];
            editedImage = [UIImage imageWithData:imageData];
        }
    }
    
    if (!editedImage) return;
    [self sendImageFile:editedImage];
     
}

- (void)editorDidCancel:(NSNotification *)notification {
    
}

/*
 - (void)addNewMessage:(ChatMessageModel *)message {
 if (!message)
 return;

 [self.messages addObject:message];
 NSIndexPath *indexPath =
 [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
 [self.tableView beginUpdates];
 [self.tableView insertRowsAtIndexPaths:@[ indexPath ]
 withRowAnimation:UITableViewRowAnimationFade];
 [self.tableView endUpdates];
 [self.tableView scrollToRowAtIndexPath:indexPath
 atScrollPosition:UITableViewScrollPositionBottom
 animated:YES];
 } */

// Crash fix: handle typing indicator cell
- (CGFloat)tableView:(UITableView *)tableView
heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row >= self.messages.count) {
        NSLog(@"❌ ChMessaging heightForRow: indexPath.row %ld out of bounds (messages.count=%lu)", (long)indexPath.row, (unsigned long)self.messages.count);
        return 44.0;
    }
    ChatMessageModel *message = self.messages[indexPath.row];
    NSNumber *cachedHeight = self.cachedHeights[message.ID];

    if (cachedHeight != nil && message.replyToMessageID.length == 0) {
        return cachedHeight.floatValue;
    }
     
    // 🔊 Audio÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷÷
    
    
    if (message.isDeleted) {
        return [self heightForTextMessage:message];
    }

    if (message.messageType == ChatMessageTypeAudio) {
        BOOL accessibilitySize =
            UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
        if (message.replyToMessageID.length > 0) {
            return accessibilitySize ? 150.0 : 138.0;
        }
        return accessibilitySize ? 86.0 : 78.0;
    }

    // 🖼 Media
    if (message.isImageMessage || message.isVideoMessage) {
        return [self heightForMediaMessage:message];
    }
 
        
    // Calculate height
    CGFloat height = [self calculateHeightForMessage:message atIndexPath:indexPath];
        
    // Cache the result
    if (message.ID.length > 0 && message.replyToMessageID.length == 0) {
        self.cachedHeights[message.ID] = @(height);
    }
 
    return height;
}

    - (CGFloat)calculateHeightForMessage:(ChatMessageModel *)message
                            atIndexPath:(NSIndexPath *)indexPath
    {
        CGFloat baseHeight = 44.0;
        
        switch (message.messageType) {
            case ChatMessageTypeAudio:
                baseHeight = 60.0;
                break;
                
            case ChatMessageTypeImage:
            case ChatMessageTypeVideo:
                baseHeight = message.cachedMediaHeight > 0 ? message.cachedMediaHeight : 240.0;
                break;
                
            case ChatMessageTypeText:
                baseHeight = [self heightForTextMessage:message];
                break;
                
             
                
            default:
                baseHeight = 44.0;
                break;
        }
        
        // Add spacing
    return baseHeight + [self spacingForRowAtIndexPath:indexPath];
}


- (CGFloat)spacingForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0) {
        return 10.0; // top padding of chat
    }

    if (indexPath.row >= self.messages.count || indexPath.row < 1) {
        NSLog(@"❌ ChMessaging spacing: indexPath.row %ld out of bounds or < 1 (messages.count=%lu)", (long)indexPath.row, (unsigned long)self.messages.count);
        return 5.0;
    }
    ChatMessageModel *current = self.messages[indexPath.row];
    ChatMessageModel *prev    = self.messages[indexPath.row - 1];

    BOOL sameSender = [self pp_message:current canGroupWithMessage:prev];

    BOOL sameType =
        current.messageType == prev.messageType;

    // 🔹 Same sender, same block → tight spacing
    if (sameSender && sameType) {
        return 1.5;
    }

    // 🔹 New block (sender changed OR type changed)
    return sameSender ? 3.0 : 6.0;
}


- (CGFloat)heightForTextMessage:(ChatMessageModel *)message
{
    // Calculate text height using boundingRectWithSize.
    CGFloat maxBubbleWidth = [UIScreen mainScreen].bounds.size.width * 0.8;
    CGFloat textWidth = MAX(64.0, maxBubbleWidth - 32.0);
    UIFont *baseFont = [GM fontWithSize:16] ?: [UIFont systemFontOfSize:16.0];
    UIFont *font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:baseFont maximumPointSize:22.0];
    NSString *text = message.isDeleted
        ? kLang(@"chat_message_unsent")
        : (message.text.length > 0 ? message.text : @" ");

    CGRect textRect = [text boundingRectWithSize:CGSizeMake(textWidth, CGFLOAT_MAX)
                                         options:NSStringDrawingUsesLineFragmentOrigin
                                      attributes:@{NSFontAttributeName: font}
                                         context:nil];
    CGFloat textHeight = MAX(ceil(textRect.size.height), ceil(font.lineHeight));
    CGFloat cellHeight = textHeight + 36.0;
    if (message.replyToMessageID.length > 0) {
        cellHeight += 51.0;
    }
    
    BOOL isSingleLine = (ceil(textRect.size.height) <= ceil(font.lineHeight + 1.0)) && (message.replyToMessageID.length == 0);
    if (isSingleLine) {
        return 40.0 + (PPChatBubblePad * 2.0);
    }
    
    return MAX(cellHeight, 44.0) + (PPChatBubblePad * 2.0);
}

- (CGFloat)tableView:(UITableView *)tableView
estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 48.0; // safe estimate
}
- (void)updateMessageStatusToSent:(ChatMessageModel *)message {
    FIRDocumentReference *msgRef = [[[FIRFirestore firestore]
                                     collectionWithPath:@"Chats"] documentWithPath:message.ID];

    [msgRef updateData:@{@"status" : @(ChatMessageStatusSent)}];
    message.status = ChatMessageStatusSent;
    [self updateMessageStatus:message];
}
#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if ([gestureRecognizer isKindOfClass:UIPanGestureRecognizer.class]) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint velocity = [pan velocityInView:pan.view ?: self.view];

        if ([gestureRecognizer.name isEqualToString:PPChatReplyPanName]) {
            UITableViewCell *cell = [self pp_cellContainingView:pan.view];
            ChatMessageModel *message = [self pp_messageForCell:cell];
            if (!message || message.isDeleted) {
                return NO;
            }

            CGFloat replyDirection = [self pp_replyPanPhysicalDirectionForMessage:message];
            CGFloat directionalVelocity = velocity.x * replyDirection;
            if (directionalVelocity <= 0.0 || fabs(velocity.x) <= fabs(velocity.y) * 1.12) {
                return NO;
            }

            CGPoint location = [pan locationInView:pan.view];
            UIView *hitView = [pan.view hitTest:location withEvent:nil];
            UIView *candidate = hitView;
            while (candidate && candidate != pan.view) {
                if ([candidate isKindOfClass:UIControl.class]) return NO;
                for (UIGestureRecognizer *nested in candidate.gestureRecognizers ?: @[]) {
                    if (nested != pan && [nested isKindOfClass:UIPanGestureRecognizer.class]) {
                        return NO;
                    }
                }
                candidate = candidate.superview;
            }
            return YES;
        }

        // The presentation-dismiss gesture remains vertical-only.
        return fabs(velocity.y) > fabs(velocity.x);
    }

    return YES;
}

#pragma mark - Premium Modal Chat Header

- (BOOL)pp_shouldAttachPremiumModalChatHeader
{
    BOOL isSheet =
        self.sheetPresentationController != nil ||
        self.navigationController.sheetPresentationController != nil;
    return [self isPresentedModally] || (self.didCaptureNotificationHandoff && isSheet);
}

- (CGFloat)pp_premiumModalChatHeaderTopPadding
{
    BOOL isSheet =
        self.sheetPresentationController != nil ||
        self.navigationController.sheetPresentationController != nil;
    return isSheet ? 24.0 : 10.0;
}

- (UIButton *)pp_premiumModalHeaderButtonWithSystemName:(NSString *)systemName
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.adjustsImageWhenHighlighted = NO;
    button.tintColor = AppPrimaryTextClr;
    button.backgroundColor = PPChatPremiumHeaderControlSurfaceColor();
    button.layer.cornerRadius = 21.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    UIImageSymbolConfiguration *symbolConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:15.5 weight:UIImageSymbolWeightSemibold];
    UIImage *image = [PPSYSImage(systemName) imageWithConfiguration:symbolConfig];
    [button setImage:image forState:UIControlStateNormal];
    [self pp_addPremiumModalHeaderPressMotionToControl:button];
    return button;
}

- (void)pp_addPremiumModalHeaderPressMotionToControl:(UIControl *)control
{
    [control addTarget:self
                action:@selector(pp_premiumModalHeaderControlTouchDown:)
      forControlEvents:UIControlEventTouchDown];
    [control addTarget:self
                action:@selector(pp_premiumModalHeaderControlRelease:)
      forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
}

- (void)pp_premiumModalHeaderControlTouchDown:(UIControl *)control
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        control.alpha = 0.82;
        return;
    }

    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        control.transform = CGAffineTransformMakeScale(0.96, 0.96);
        control.alpha = 0.86;
    } completion:nil];
}

- (void)pp_premiumModalHeaderControlRelease:(UIControl *)control
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        control.alpha = 1.0;
        return;
    }

    [UIView animateWithDuration:0.18
                          delay:0.0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.4
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        control.transform = CGAffineTransformIdentity;
        control.alpha = 1.0;
    } completion:nil];
}

- (void)pp_setupPremiumModalChatHeaderIfNeeded
{
    if (self.premiumModalHeaderView) {
        return;
    }

    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.backgroundColor = UIColor.clearColor;
    header.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    header.clipsToBounds = YES;
    header.layer.cornerRadius = PPChatPremiumModalHeaderCornerRadius;
    header.layer.cornerCurve = kCACornerCurveContinuous;

    PPHeroGlassBackgroundView *glassBackground = [PPHeroGlassBackgroundView new];
    glassBackground.translatesAutoresizingMaskIntoConstraints = NO;
    glassBackground.accentStyle = PPHeroGlassAccentStyleBar;
    glassBackground.accentColorOverride = [PPChatsFunc chatNeutralAccentColor];
    glassBackground.clipsToBounds = YES;
    glassBackground.layer.cornerRadius = PPChatPremiumModalHeaderCornerRadius;
    glassBackground.layer.cornerCurve = kCACornerCurveContinuous;
    [header insertSubview:glassBackground atIndex:0];

    UIView *surfaceOverlay = [[UIView alloc] init];
    surfaceOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    surfaceOverlay.userInteractionEnabled = NO;
    surfaceOverlay.backgroundColor = PPChatPremiumHeaderSurfaceOverlayColor();
    surfaceOverlay.layer.cornerRadius = PPChatPremiumModalHeaderCornerRadius;
    surfaceOverlay.layer.cornerCurve = kCACornerCurveContinuous;
    surfaceOverlay.clipsToBounds = YES;
    [header insertSubview:surfaceOverlay aboveSubview:glassBackground];

    UIButton *closeButton = [self pp_premiumModalHeaderButtonWithSystemName:@"xmark"];
    closeButton.accessibilityLabel = kLang(@"Close");
    [closeButton addTarget:self action:@selector(handleCloseTapped) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeButton];

    UIButton *moreButton = [self pp_premiumModalHeaderButtonWithSystemName:@"ellipsis"];
    moreButton.accessibilityLabel = kLang(@"more");
    moreButton.showsMenuAsPrimaryAction = YES;
    moreButton.menu = [self pp_chatActionsMenu];
    [header addSubview:moreButton];

    UIControl *profileControl = [[UIControl alloc] init];
    profileControl.translatesAutoresizingMaskIntoConstraints = NO;
    profileControl.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    profileControl.accessibilityTraits = UIAccessibilityTraitButton;
    [profileControl addTarget:self
                       action:@selector(pp_handlePremiumModalChatHeaderProfileTap)
             forControlEvents:UIControlEventTouchUpInside];
    [self pp_addPremiumModalHeaderPressMotionToControl:profileControl];
    [header addSubview:profileControl];

    UIImageView *avatarView = [[UIImageView alloc] init];
    avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    avatarView.contentMode = UIViewContentModeScaleAspectFill;
    avatarView.clipsToBounds = YES;
    avatarView.layer.cornerRadius = 25.0;
    avatarView.layer.cornerCurve = kCACornerCurveContinuous;
    [profileControl addSubview:avatarView];

    UIView *statusDot = [[UIView alloc] init];
    statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    statusDot.backgroundColor = UIColor.systemGreenColor;
    statusDot.layer.cornerRadius = 6.0;
    statusDot.hidden = YES;
    [profileControl addSubview:statusDot];

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.font = [GM boldFontWithSize:17.0];
    nameLabel.textColor = UIColor.labelColor;
    nameLabel.numberOfLines = 1;
    nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    nameLabel.minimumScaleFactor = 0.82;
    nameLabel.adjustsFontSizeToFitWidth = YES;
    nameLabel.textAlignment = Language.alignmentForCurrentLanguage;

    UILabel *statusLabel = [[UILabel alloc] init];
    statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    statusLabel.font = [GM MidFontWithSize:12.5];
    statusLabel.textColor = PPChatPremiumHeaderSecondaryTextColor();
    statusLabel.numberOfLines = 1;
    statusLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    statusLabel.minimumScaleFactor = 0.82;
    statusLabel.adjustsFontSizeToFitWidth = YES;
    statusLabel.textAlignment = Language.alignmentForCurrentLanguage;

    UIStackView *labelsStack = [[UIStackView alloc] initWithArrangedSubviews:@[nameLabel, statusLabel]];
    labelsStack.translatesAutoresizingMaskIntoConstraints = NO;
    labelsStack.axis = UILayoutConstraintAxisVertical;
    labelsStack.alignment = UIStackViewAlignmentFill;
    labelsStack.spacing = 1.0;
    [profileControl addSubview:labelsStack];

    [self.view addSubview:header];

    self.premiumModalHeaderTopConstraint =
        [header.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor
                                         constant:[self pp_premiumModalChatHeaderTopPadding]];
    self.premiumModalHeaderHeightConstraint =
        [header.heightAnchor constraintEqualToConstant:78.0];

    [NSLayoutConstraint activateConstraints:@[
        self.premiumModalHeaderTopConstraint,
        [header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:14.0],
        [header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-14.0],
        self.premiumModalHeaderHeightConstraint,

        [glassBackground.topAnchor constraintEqualToAnchor:header.topAnchor],
        [glassBackground.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [glassBackground.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],
        [glassBackground.bottomAnchor constraintEqualToAnchor:header.bottomAnchor],

        [surfaceOverlay.topAnchor constraintEqualToAnchor:header.topAnchor],
        [surfaceOverlay.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [surfaceOverlay.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],
        [surfaceOverlay.bottomAnchor constraintEqualToAnchor:header.bottomAnchor],

        [closeButton.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:14.0],
        [closeButton.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [closeButton.widthAnchor constraintEqualToConstant:42.0],
        [closeButton.heightAnchor constraintEqualToConstant:42.0],

        [moreButton.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-14.0],
        [moreButton.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [moreButton.widthAnchor constraintEqualToConstant:42.0],
        [moreButton.heightAnchor constraintEqualToConstant:42.0],

        [profileControl.leadingAnchor constraintEqualToAnchor:closeButton.trailingAnchor constant:10.0],
        [profileControl.trailingAnchor constraintEqualToAnchor:moreButton.leadingAnchor constant:-10.0],
        [profileControl.topAnchor constraintEqualToAnchor:header.topAnchor constant:9.0],
        [profileControl.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-9.0],

        [avatarView.leadingAnchor constraintEqualToAnchor:profileControl.leadingAnchor],
        [avatarView.centerYAnchor constraintEqualToAnchor:profileControl.centerYAnchor],
        [avatarView.widthAnchor constraintEqualToConstant:50.0],
        [avatarView.heightAnchor constraintEqualToConstant:50.0],

        [statusDot.widthAnchor constraintEqualToConstant:12.0],
        [statusDot.heightAnchor constraintEqualToConstant:12.0],
        [statusDot.trailingAnchor constraintEqualToAnchor:avatarView.trailingAnchor constant:-1.0],
        [statusDot.bottomAnchor constraintEqualToAnchor:avatarView.bottomAnchor constant:-1.0],

        [labelsStack.leadingAnchor constraintEqualToAnchor:avatarView.trailingAnchor constant:13.0],
        [labelsStack.trailingAnchor constraintEqualToAnchor:profileControl.trailingAnchor],
        [labelsStack.centerYAnchor constraintEqualToAnchor:profileControl.centerYAnchor]
    ]];

    self.premiumModalHeaderView = header;
    self.premiumModalHeaderGlassBackgroundView = glassBackground;
    self.premiumModalHeaderCloseButton = closeButton;
    self.premiumModalHeaderMoreButton = moreButton;
    self.premiumModalHeaderProfileControl = profileControl;
    self.premiumModalHeaderAvatarView = avatarView;
    self.premiumModalHeaderStatusDotView = statusDot;
    self.premiumModalHeaderNameLabel = nameLabel;
    self.premiumModalHeaderStatusLabel = statusLabel;

    if (!UIAccessibilityIsReduceMotionEnabled()) {
        header.alpha = 0.0;
        header.transform = CGAffineTransformMakeTranslation(0.0, -12.0);
    }

    [self pp_applyPremiumModalChatHeaderTheme];
}

- (void)pp_applyPremiumModalChatHeaderTheme
{
    if (!self.premiumModalHeaderView) {
        return;
    }

    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    self.premiumModalHeaderView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.premiumModalHeaderProfileControl.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.premiumModalHeaderView.layer.cornerRadius = PPChatPremiumModalHeaderCornerRadius;
    self.premiumModalHeaderGlassBackgroundView.accentStyle = PPHeroGlassAccentStyleBar;
    self.premiumModalHeaderGlassBackgroundView.clipsToBounds = YES;
    self.premiumModalHeaderGlassBackgroundView.layer.cornerRadius = PPChatPremiumModalHeaderCornerRadius;
    self.premiumModalHeaderGlassBackgroundView.accentColorOverride = [PPChatsFunc chatNeutralAccentColor];
    [self.premiumModalHeaderGlassBackgroundView reapplyPalette];
    self.premiumModalHeaderGlassBackgroundView.layer.cornerRadius = PPChatPremiumModalHeaderCornerRadius;

    NSArray<UIButton *> *buttons = @[self.premiumModalHeaderCloseButton, self.premiumModalHeaderMoreButton];
    for (UIButton *button in buttons) {
        button.tintColor = AppPrimaryTextClr;
        button.backgroundColor = PPChatPremiumHeaderControlSurfaceColor();
        [button pp_setBorderColor:PPChatPremiumHeaderBorderColor()];
    }

    [self.premiumModalHeaderAvatarView pp_setBorderColor:
        dark ? [[UIColor whiteColor] colorWithAlphaComponent:0.18] : [[UIColor whiteColor] colorWithAlphaComponent:0.76]];
    [self.premiumModalHeaderStatusDotView pp_setBorderColor:
        dark ? [UIColor colorWithWhite:0.10 alpha:1.0] : UIColor.whiteColor];
    self.premiumModalHeaderNameLabel.textColor = UIColor.labelColor;
    self.premiumModalHeaderStatusLabel.textColor = PPChatPremiumHeaderSecondaryTextColor();
    self.premiumModalHeaderNameLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.premiumModalHeaderStatusLabel.textAlignment = Language.alignmentForCurrentLanguage;
}

- (void)pp_updatePremiumModalChatHeaderShadowPath
{
    if (!self.premiumModalHeaderView ||
        CGRectIsEmpty(self.premiumModalHeaderView.bounds)) {
        return;
    }

    UIBezierPath *path =
        [UIBezierPath bezierPathWithRoundedRect:self.premiumModalHeaderView.bounds
                                   cornerRadius:PPChatPremiumModalHeaderCornerRadius];
    self.premiumModalHeaderView.layer.shadowPath = path.CGPath;
}

- (void)pp_bringChatHeaderToFront
{
    if (self.navBottomBlurView.superview && !self.navBottomBlurView.hidden) {
        [self.view bringSubviewToFront:self.navBottomBlurView];
    }
    if (self.chatHeaderView.superview && !self.chatHeaderView.hidden) {
        [self.view bringSubviewToFront:self.chatHeaderView];
    }
    if (self.premiumModalHeaderView.superview && !self.premiumModalHeaderView.hidden) {
        [self.view bringSubviewToFront:self.premiumModalHeaderView];
    }
}

- (void)pp_updatePremiumModalChatHeaderContentAnimated:(BOOL)animated
{
    if (!self.premiumModalHeaderView) {
        return;
    }

    UserModel *user = self.threadOtherUser ?: self.chatThread.otherUser;
    NSString *displayName = @"";
    if ([user respondsToSelector:@selector(PPBestDisplayName)]) {
        displayName = [user PPBestDisplayName] ?: @"";
    }
    if (displayName.length == 0) {
        displayName = user.UserName ?: @"";
    }
    if (displayName.length == 0) {
        displayName = kLang(@"Chat");
    }

    NSString *statusText = @"";
    BOOL showOnlineDot = NO;
    if (user.isOnline) {
        statusText = kLang(@"chat.online");
        showOnlineDot = YES;
    } else if (user.lastSeen) {
        statusText = [ChManager formattedLastSeen:user.lastSeen] ?: @"";
    } else {
        statusText = kLang(@"chat.offline");
    }

    self.premiumModalHeaderNameLabel.text = displayName;
    self.premiumModalHeaderProfileControl.accessibilityLabel =
        statusText.length > 0
            ? [NSString stringWithFormat:@"%@, %@", displayName, statusText]
            : displayName;

    void (^statusUpdate)(void) = ^{
        self.premiumModalHeaderStatusLabel.text = statusText;
        self.premiumModalHeaderStatusDotView.hidden = !showOnlineDot;
        self.premiumModalHeaderStatusDotView.alpha = showOnlineDot ? 1.0 : 0.0;
    };

    if (animated && ![self.premiumModalHeaderStatusLabel.text isEqualToString:statusText]) {
        [UIView transitionWithView:self.premiumModalHeaderStatusLabel
                          duration:0.18
                           options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionBeginFromCurrentState
                        animations:statusUpdate
                        completion:nil];
    } else {
        statusUpdate();
    }

    self.premiumModalHeaderMoreButton.menu = [self pp_chatActionsMenu];

    NSString *userID = user.ID ?: @"";
    NSString *avatarURL = user.UserImageUrl.absoluteString ?: @"";
    BOOL shouldRefreshAvatar =
        ![self.premiumModalHeaderAvatarUserID isEqualToString:userID] ||
        ![self.premiumModalHeaderAvatarURLString isEqualToString:avatarURL];
    if (!shouldRefreshAvatar) {
        return;
    }

    self.premiumModalHeaderAvatarUserID = userID;
    self.premiumModalHeaderAvatarURLString = avatarURL;

    if (PPChatPremiumHeaderUsesSupportLogo(user)) {
        self.premiumModalHeaderAvatarView.image = PPChatPremiumHeaderSupportLogoImage();
        self.premiumModalHeaderAvatarView.contentMode = UIViewContentModeScaleAspectFit;
        self.premiumModalHeaderAvatarView.backgroundColor = UIColor.whiteColor;
        return;
    }

    UIImage *placeholder = [PPModernAvatarRenderer avatarImageForName:displayName size:50.0];
    self.premiumModalHeaderAvatarView.image = placeholder;
    self.premiumModalHeaderAvatarView.contentMode = UIViewContentModeScaleAspectFill;
    self.premiumModalHeaderAvatarView.backgroundColor = UIColor.clearColor;
    if (avatarURL.length > 0) {
        [[PPImageLoaderManager shared] setImageOnImageView:self.premiumModalHeaderAvatarView
                                                       url:avatarURL
                                               placeholder:placeholder
                                           transitionStyle:PPImageTransitionStyleCrossDissolve
                                                complation:nil];
    }
}

- (void)pp_updatePremiumModalChatHeaderInsets
{
    if (!self.tableView) {
        return;
    }

    UIEdgeInsets insets = self.tableView.contentInset;
    UIEdgeInsets indicatorInsets = self.tableView.scrollIndicatorInsets;
    CGFloat desiredTop = self.baseTableInsets.top;

    if (self.premiumModalHeaderView.superview && !self.premiumModalHeaderView.hidden) {
        CGRect headerFrame = self.premiumModalHeaderView.frame;
        if (!CGRectIsEmpty(headerFrame)) {
            desiredTop = MAX(desiredTop, CGRectGetMaxY(headerFrame) + 10.0);
        }
    }

    if (fabs(insets.top - desiredTop) > 0.5) {
        insets.top = desiredTop;
        self.tableView.contentInset = insets;
    }
    if (fabs(indicatorInsets.top - desiredTop) > 0.5) {
        indicatorInsets.top = desiredTop;
        self.tableView.scrollIndicatorInsets = indicatorInsets;
    }
}

- (void)pp_updatePremiumModalChatHeaderVisibility
{
    if (![self pp_shouldAttachPremiumModalChatHeader]) {
        [self.premiumModalHeaderGlassBackgroundView stopAnimations];
        self.premiumModalHeaderView.hidden = YES;
        self.didAnimatePremiumModalHeader = NO;
        [self pp_updatePremiumModalChatHeaderInsets];
        return;
    }

    [self pp_setupPremiumModalChatHeaderIfNeeded];
    self.premiumModalHeaderView.hidden = NO;
    self.premiumModalHeaderTopConstraint.constant = [self pp_premiumModalChatHeaderTopPadding];
    [self pp_applyPremiumModalChatHeaderTheme];
    [self pp_updatePremiumModalChatHeaderContentAnimated:NO];
    [self.premiumModalHeaderView layoutIfNeeded];
    [self.premiumModalHeaderGlassBackgroundView startAnimations];
    [self pp_bringChatHeaderToFront];
    [self pp_updatePremiumModalChatHeaderInsets];
    [self pp_animatePremiumModalChatHeaderIfNeeded];
}

- (void)pp_animatePremiumModalChatHeaderIfNeeded
{
    if (!self.premiumModalHeaderView ||
        self.didAnimatePremiumModalHeader ||
        !self.premiumModalHeaderView.window) {
        return;
    }

    self.didAnimatePremiumModalHeader = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.premiumModalHeaderView.alpha = 1.0;
        self.premiumModalHeaderView.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.42
                          delay:0.04
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.28
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.premiumModalHeaderView.alpha = 1.0;
        self.premiumModalHeaderView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_handlePremiumModalChatHeaderProfileTap
{
    [self pp_openStoryForCurrentChatUser];
}

- (void)pp_clearPremiumModalNavigationItems
{
    self.navigationItem.titleView = nil;
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.leftBarButtonItems = nil;
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.rightBarButtonItems = nil;
}

- (UIMenu *)pp_chatActionsMenu
{
    NSMutableArray<UIAction *> *actions = [NSMutableArray new];
    __weak typeof(self) weakSelf = self;

    BOOL isPinned = self.chatThread.isPinned;
    if (!isPinned) {
        UIAction *pinAction =
        [PPMenuHelper actionWithTitle:kLang(@"chat.pin")
                    systemImageName:@"pin"
                               font:[GM MidFontWithSize:16]
                              color:AppPrimaryTextClr
                            handler:^(__kindof UIAction * _Nonnull act) {
            [weakSelf handlePinThread];
        }];
        [actions addObject:pinAction];
    }

    BOOL isMuted = self.chatThread.isMuted;
    NSString *muteTitle = isMuted ? kLang(@"chat.unmute") : kLang(@"chat.mute");
    NSString *muteIcon = isMuted ? @"bell" : @"bell.slash";
    UIAction *muteAction =
    [PPMenuHelper actionWithTitle:muteTitle
                systemImageName:muteIcon
                           font:[GM MidFontWithSize:16]
                          color:AppPrimaryTextClr
                        handler:^(__kindof UIAction * _Nonnull act) {
        [weakSelf handleMuteThread];
    }];
    [actions addObject:muteAction];

    BOOL isBinned = self.chatThread.isBinned;
    NSString *binTitle = isBinned ? kLang(@"chat.unbin") : kLang(@"chat.bin");
    UIAction *binAction =
    [PPMenuHelper actionWithTitle:binTitle
                systemImageName:@"trash"
                           font:[GM MidFontWithSize:16]
                          color:UIColor.systemRedColor
                        handler:^(__kindof UIAction * _Nonnull act) {
        [weakSelf handleBinThread];
    }];
    [actions addObject:binAction];

    NSString *reportTitle =
        self.chatThread.isReportedByMe ? kLang(@"chat.reported") : kLang(@"chat.report");
    UIAction *reportAction =
    [PPMenuHelper actionWithTitle:reportTitle
                systemImageName:@"exclamationmark.triangle"
                           font:[GM MidFontWithSize:16]
                          color:UIColor.systemRedColor
                        handler:^(__kindof UIAction * _Nonnull act) {
        [weakSelf presentReportConfirmation];
    }];
    if (self.chatThread.isReportedByMe) {
        reportAction.attributes = UIMenuElementAttributesDisabled;
    }
    [actions addObject:reportAction];

    return [UIMenu menuWithChildren:actions];
}

- (void)configureBackUX
{
    // 🔹 Hide default back button always
    //self.navigationItem.hidesBackButton = YES;

    if ([self pp_shouldAttachPremiumModalChatHeader]) {
        [self pp_clearPremiumModalNavigationItems];
        if (self.navigationController.presentingViewController &&
            self.navigationController.viewControllers.firstObject == self) {
            [self.navigationController setNavigationBarHidden:YES animated:NO];
        }
        [self pp_updatePremiumModalChatHeaderVisibility];
        self.navigationController.interactivePopGestureRecognizer.enabled = YES;
        self.navigationController.interactivePopGestureRecognizer.delegate =
            (id<UIGestureRecognizerDelegate>)self;
        return;

    } else {
        [self pp_updatePremiumModalChatHeaderVisibility];
        // 🔹 Pushed → enable swipe back, no button
        self.navigationController.interactivePopGestureRecognizer.enabled = YES;
        self.navigationController.interactivePopGestureRecognizer.delegate =
            (id<UIGestureRecognizerDelegate>)self;
    }
}

- (void)pp_attachStoryTapToHeader:(UIView *)header
{
    if (!header) {
        return;
    }
    header.userInteractionEnabled = YES;
    NSArray<UIGestureRecognizer *> *existingGestures = [header.gestureRecognizers copy] ?: @[];
    for (UIGestureRecognizer *recognizer in existingGestures) {
        if ([recognizer isKindOfClass:[UITapGestureRecognizer class]]) {
            [header removeGestureRecognizer:recognizer];
        }
    }
    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_handleChatHeaderStoryTap:)];
    tap.numberOfTapsRequired = 1;
    [header addGestureRecognizer:tap];
}

- (void)pp_handleChatHeaderStoryTap:(UITapGestureRecognizer *)gesture
{
    if (gesture.state != UIGestureRecognizerStateEnded) {
        return;
    }
    [self pp_openStoryForCurrentChatUser];
}

- (void)pp_openStoryForCurrentChatUser
{
    if (self.isOpeningHeaderStory || self.presentedViewController) {
        return;
    }
    NSString *targetUserID = self.threadOtherUser.ID.length > 0
        ? self.threadOtherUser.ID
        : self.chatThread.otherUser.ID;
    if (targetUserID.length == 0) {
        [PPHUD showInfo:kLang(@"story_unavailable")];
        return;
    }

    self.isOpeningHeaderStory = YES;
    [PPHUD showLoading:kLang(@"story_loading")];

    __weak typeof(self) weakSelf = self;
    [[PPStoriesManager shared] fetchStoriesForUserID:targetUserID
                                          completion:^(NSArray<PPStory *> *stories, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            self.isOpeningHeaderStory = NO;
            [PPHUD dismiss];

            if (error) {
                [PPHUD showInfo:kLang(@"story_load_failed")];
                return;
            }
            PPStory *story = stories.firstObject;
            if (stories.count == 0 || story.items.count == 0) {
                [PPHUD showInfo:kLang(@"story_no_items")];
                return;
            }

            PPStoryPlayerViewController *player =
                [[PPStoryPlayerViewController alloc] initWithStories:stories startIndex:0];
            player.modalPresentationStyle = UIModalPresentationFullScreen;
            [self presentViewController:player animated:YES completion:nil];
        });
    }];
}

- (void)presentReportConfirmation
{
    if (self.chatThread.isReportedByMe) {
        [PPHUD showInfo:kLang(@"chat.report.already")];
        return;
    }
    UIAlertController *alert =
    [UIAlertController alertControllerWithTitle:kLang(@"chat.report.title")
                                        message:kLang(@"chat.report.message")
                                 preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = kLang(@"chat.report.reason.placeholder");
    }];

    UIAlertAction *report =
    [UIAlertAction actionWithTitle:kLang(@"chat.report.confirm")
                             style:UIAlertActionStyleDestructive
                           handler:^(UIAlertAction * _Nonnull action) {
        NSString *reason = alert.textFields.firstObject.text ?: @"";
        [self handleReportThreadWithReason:reason];
    }];

    UIAlertAction *cancel =
    [UIAlertAction actionWithTitle:kLang(@"chat.cancel")
                             style:UIAlertActionStyleCancel
                           handler:nil];

    [alert addAction:cancel];
    [alert addAction:report];
    [self presentViewController:alert animated:YES completion:nil];
}
#pragma mark - Chat Menu Action Handlers

- (void)handleMuteThread
{
    BOOL nextMuted = !self.chatThread.isMuted;
    [PPHUD showLoading];
    __weak typeof(self) weakSelf = self;
    [[ChManager sharedManager] muteThreadWithID:self.chatThread.ID
                                         muted:nextMuted
                                     completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [PPHUD dismiss];
            if (error) {
                [PPHUD showError:kLang(@"SomethingWentWrong")];
                return;
            }
            weakSelf.chatThread.isMuted = nextMuted;
            NSString *myUID = UserManager.sharedManager.currentUser.ID ?: @"";
            if (myUID.length) {
                NSMutableArray *arr = [weakSelf.chatThread.mutedBy mutableCopy] ?: [NSMutableArray array];
                if (nextMuted && ![arr containsObject:myUID]) {
                    [arr addObject:myUID];
                } else if (!nextMuted) {
                    [arr removeObject:myUID];
                }
                weakSelf.chatThread.mutedBy = [arr copy];
            }
            [PPHUD showSuccess: nextMuted ? kLang(@"chat.muted") : kLang(@"chat.unmuted")];
            [weakSelf pp_updatePremiumModalChatHeaderContentAnimated:YES];
        });
    }];
}

- (void)handlePinThread
{
    NSLog(@"📌 Pin thread %@", self.chatThread.ID);
    // TODO: update pinned state
}


- (void)handleReportThreadWithReason:(NSString *)reason
{
    if (self.chatThread.isReportedByMe) {
        [PPHUD showInfo:kLang(@"chat.report.already")];
        return;
    }
    [PPHUD showLoading];
    __weak typeof(self) weakSelf = self;
    [[ChManager sharedManager] reportThread:self.chatThread
                                     reason:reason
                                 completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [PPHUD dismiss];
            if (error) {
                [PPHUD showError:kLang(@"SomethingWentWrong")];
                return;
            }
            weakSelf.chatThread.isReportedByMe = YES;
            NSString *myUID = UserManager.sharedManager.currentUser.ID ?: @"";
            if (myUID.length) {
                NSMutableArray *arr = [weakSelf.chatThread.reportedBy mutableCopy] ?: [NSMutableArray array];
                if (![arr containsObject:myUID]) {
                    [arr addObject:myUID];
                }
                weakSelf.chatThread.reportedBy = [arr copy];
            }
            [PPHUD showSuccess:kLang(@"chat.report.success")];
            [weakSelf pp_updatePremiumModalChatHeaderContentAnimated:YES];
        });
    }];
}

- (void)handleBinThread
{
    BOOL nextBinned = !self.chatThread.isBinned;
    NSString *title = nextBinned ? kLang(@"chat.bin.confirm.title") : kLang(@"chat.unbin.confirm.title");
    NSString *message = nextBinned ? kLang(@"chat.bin.confirm.message") : kLang(@"chat.unbin.confirm.message");
    NSString *actionTitle = nextBinned ? kLang(@"chat.bin.confirm.action") : kLang(@"chat.unbin");

    UIAlertController *alert =
    [UIAlertController alertControllerWithTitle:title
                                        message:message
                                 preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *confirm =
    [UIAlertAction actionWithTitle:actionTitle
                             style:UIAlertActionStyleDestructive
                           handler:^(UIAlertAction * _Nonnull action) {
        [PPHUD showLoading];
        __weak typeof(self) weakSelf = self;
        [[ChManager sharedManager] binThreadWithID:self.chatThread.ID
                                           binned:nextBinned
                                       completion:^(NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [PPHUD dismiss];
                if (error) {
                    [PPHUD showError:kLang(@"SomethingWentWrong")];
                    return;
                }
                weakSelf.chatThread.isBinned = nextBinned;
                NSString *myUID = UserManager.sharedManager.currentUser.ID ?: @"";
                if (myUID.length) {
                    NSMutableArray *arr = [weakSelf.chatThread.binnedBy mutableCopy] ?: [NSMutableArray array];
                    if (nextBinned && ![arr containsObject:myUID]) {
                        [arr addObject:myUID];
                    } else if (!nextBinned) {
                        [arr removeObject:myUID];
                    }
                    weakSelf.chatThread.binnedBy = [arr copy];
                }
                [PPHUD showSuccess: nextBinned ? kLang(@"chat.binned") : kLang(@"chat.unbinned")];

                // If binned, close chat and refresh list
                if (nextBinned) {
                    [[NSNotificationCenter defaultCenter]
                     postNotificationName:@"forceReloadThreads"
                     object:nil];
                    [weakSelf handleCloseTapped];
                }
            });
        }];
    }];

    UIAlertAction *cancel =
    [UIAlertAction actionWithTitle:kLang(@"chat.cancel")
                             style:UIAlertActionStyleCancel
                           handler:nil];
    [alert addAction:confirm];
    [alert addAction:cancel];

    // iPad safety
    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    if (popover) {
        if (self.premiumModalHeaderMoreButton.superview && !self.premiumModalHeaderMoreButton.hidden) {
            popover.sourceView = self.premiumModalHeaderMoreButton;
            popover.sourceRect = self.premiumModalHeaderMoreButton.bounds;
        } else if (self.navigationItem.rightBarButtonItem) {
            popover.barButtonItem = self.navigationItem.rightBarButtonItem;
        } else {
            popover.sourceView = self.view;
            popover.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                            CGRectGetMidY(self.view.bounds),
                                            1.0,
                                            1.0);
        }
    }

    [self presentViewController:alert animated:YES completion:nil];
}




- (void)handleCloseTapped
{
    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // 🔥 CRITICAL: neutralize tab bar safe area
   


    if (self.keepsBottomNavigationVisibleForNotificationHandoff) {
        [self pp_applyNotificationHandoffBottomNavigationVisibilityAnimated:animated];
    } else {
        [[NSNotificationCenter defaultCenter]
               postNotificationName:PPHideSystemTabBarNotification
                             object:nil];
    }
    
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.tableView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
  
   
    
    //[self.chatHeaderView configureWithUser:self.threadOtherUser];
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    IQKeyboardManager *manager = [IQKeyboardManager sharedManager];

    // Save previous state
    self.previousIQEnabled = manager.enable;
    self.previousToolbarEnabled = manager.enableAutoToolbar;

    // Disable toolbar (keep manager enabled)
    manager.enableAutoToolbar = NO;
    
    [self.view bringSubviewToFront:self.typingIndicatorView];
        [self.view bringSubviewToFront:[self pp_activeChatInputBarViewForLayout]];
    [self pp_updateChatEmptyStateAnimated:NO];
     
    
    [self setupNavBottomBlur];
    
    [self configureBackUX];
    [self pp_bringChatHeaderToFront];
}

- (void)setupTopView {

  
    NSString *presenceUserID = [self resolvedOtherUserPresenceID];
    if (presenceUserID.length > 0) {
        [self observeUserStatus:presenceUserID];
    }
}

- (void)observeUserStatus:(NSString *)userID {
    if (!userID.length)
        return;

    FIRDocumentReference *userRef = [[FIRFirestore.firestore
                                      collectionWithPath:@"UserPresence"] documentWithPath:userID];

    [self.userStatusListener remove];
    __weak typeof(self) weakSelf = self;
    self.userStatusListener = [userRef
     addSnapshotListener:^(FIRDocumentSnapshot *snapshot, NSError *error) {
        if (error || !snapshot.exists)
            return;

        NSDictionary *data = snapshot.data;
        if (!data) return;
        BOOL isOnline = [data[@"online"] boolValue];
        id rawLastSeen = data[@"lastSeen"];
        NSDate *lastSeen = nil;
        if ([rawLastSeen isKindOfClass:FIRTimestamp.class]) {
            lastSeen = [(FIRTimestamp *)rawLastSeen dateValue];
        } else if ([rawLastSeen isKindOfClass:NSDate.class]) {
            lastSeen = rawLastSeen;
        }

        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.threadOtherUser.isOnline = isOnline;
        strongSelf.threadOtherUser.lastSeen = lastSeen;
        [strongSelf pp_updatePremiumModalChatHeaderContentAnimated:YES];
    }];
}
 

 
 
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // 🔄 restore normal behavior
      self.additionalSafeAreaInsets = UIEdgeInsetsZero;

    [[NSNotificationCenter defaultCenter]
           postNotificationName:PPShowSystemTabBarNotification
                         object:nil];
    
    self.isViewVisible = NO;
    [ChManager sharedManager].activeThreadID = nil;
    
    IQKeyboardManager *manager = [IQKeyboardManager sharedManager];

    // Restore previous state
    manager.enable = self.previousIQEnabled;
    manager.enableAutoToolbar = self.previousToolbarEnabled;
    [self stopAllRecordingUpdates];
    [self setInitialLoadingVisible:NO];
    [self.typingController stop];
    [self.messageListener remove];
    self.messageListener = nil;
    self.isObservingMessages = NO;
    self.didMarkMessagesAsRead = NO;
    [self.userStatusListener remove];
    self.userStatusListener = nil;
    
    [self unregisterKeyboardNotifications];
    [self unregisterAppStateObservers];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"PPEditorBridgeDidFinish" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"PPEditorBridgeDidCancel" object:nil];
    [self.premiumModalHeaderGlassBackgroundView stopAnimations];
    
    if (self.authListenerHandle) {
        [[FIRAuth auth] removeAuthStateDidChangeListener:self.authListenerHandle];
        self.authListenerHandle = 0;
    }
    

}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [Styling addLiquidGlassBorderToView:self.typingIndicatorView cornerRadius:22];
    //[Styling addLiquidGlassBorderToView:self.self.navBottomBlurView cornerRadius:0 color:[UIColor.secondaryLabelColor colorWithAlphaComponent:0.3]];
    [Styling addLiquidGlassBorderToView:self.bottomFillBlurView cornerRadius:0 color:[UIColor.secondaryLabelColor colorWithAlphaComponent:0.3]];
    self.navBottomBlurView.hidden = NO;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.showsHorizontalScrollIndicator = NO;
    [self pp_bringChatHeaderToFront];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat baseWidth = self.view.bounds.size.width > 0
        ? self.view.bounds.size.width
        : UIScreen.mainScreen.bounds.size.width;
    CGFloat targetMaxWidth = MAX(160.0, baseWidth * 0.72);
    [self pp_updateInputBarBottomConstraintsForCurrentState];
    [self pp_applyTableViewBottomInsetForActiveComposer];
    BOOL shouldKeepBottomPinned =
        self.isViewVisible && self.didFinishInitialLoad && [self isNearBottom];

    if (fabs(self.fixedMediaMaxWidth - targetMaxWidth) > 0.5) {
        self.fixedMediaMaxWidth = targetMaxWidth;
        [self.cachedHeights removeAllObjects];
        if (shouldKeepBottomPinned) {
            self.pendingBottomScrollAfterLayout = YES;
        }
        [UIView performWithoutAnimation:^{
            [self.tableView beginUpdates];
            [self.tableView endUpdates];
        }];
    }

    if (self.initialLoadIndicator.isAnimating &&
        (self.didFinishInitialLoad || self.messages.count > 0)) {
        [self setInitialLoadingVisible:NO];
    }

    if (self.pendingBottomScrollAfterLayout &&
        self.isViewVisible &&
        self.didFinishInitialLoad &&
        self.messages.count > 0) {
        [self scrollToBottomAnimated:NO];
    }

    [self pp_updatePremiumModalChatHeaderShadowPath];
    [self pp_updatePremiumModalChatHeaderInsets];
    [self pp_updateChatEmptyStateAnimated:NO];
    [self pp_animatePremiumModalChatHeaderIfNeeded];
    [self pp_bringChatHeaderToFront];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self pp_applyPremiumModalChatHeaderTheme];
    [self pp_applyPremiumEmptyStateTheme];
    if (self.replyingToMessage) {
        self.swiftUIInputBarHeightConstraint.constant = [self pp_expandedSwiftUIComposerHeight];
        [self.view setNeedsLayout];
    }
}

- (NSInteger)resolvedChatBackgroundIndex
{
    // Priority:
    // 1. Per-thread stored preference
    // 2. User default
    // 3. Fallback random

    NSNumber *stored = self.chatThread.chatBackgroundIndex;

    if (stored) {
        return stored.integerValue;
    }

    NSInteger saved =
        [[NSUserDefaults standardUserDefaults]
         integerForKey:@"pp.chat.bg.default"];

    if (saved > 0) {
        return saved;
    }

    return -1;
}



- (void)applyChatBackground:(NSInteger)index
{
    __weak typeof(self) weakSelf = self;

    [[PPChatBackgroundManager shared]
     fetchChatBackgroundAtIndex:index
     completion:^(UIImage *image) {

        if (!image) return;

        [UIView transitionWithView:weakSelf.chatBackgroundImageView
                          duration:0.25
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            weakSelf.chatBackgroundImageView.image = image;
        } completion:nil];
    }];
}


- (void)presentChatBackgroundPicker
{
    NSInteger current = self.chatThread.chatBackgroundIndex.integerValue ?: 1;

    PPChatBackgroundPickerController *vc =
        [[PPChatBackgroundPickerController alloc]
         initWithSelectedIndex:current
         selection:^(NSInteger selectedIndex) {

        [self applyChatBackground:selectedIndex];
        [self persistChatBackground:selectedIndex];
            [[NSUserDefaults standardUserDefaults]
             setInteger:selectedIndex forKey:@"pp.chat.bg.default"];
            
    }];

    [self presentViewController:vc animated:YES completion:nil];
}


- (void)persistChatBackground:(NSInteger)index
{
    self.chatThread.chatBackgroundIndex = @(index);

    [[[[FIRFirestore firestore]
      collectionWithPath:@"Chats"]
      documentWithPath:self.chatThread.ID]
    updateData:@{ @"chatBackgroundIndex": @(index) }];
}

- (void)loadChatBackground
{
    NSInteger bgIndex = [self resolvedChatBackgroundIndex];

    if(bgIndex == -1)return;
    __weak typeof(self) weakSelf = self;
    [[PPChatBackgroundManager shared] fetchChatBackgroundAtIndex:bgIndex completion:^(UIImage *image) {

        if (!image) return;

        [UIView transitionWithView:weakSelf.chatBackgroundImageView
                          duration:0.25
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            weakSelf.chatBackgroundImageView.image = image;
        } completion:nil];
        
    }];
}

- (void)setupChatBackground
{
    if (self.chatBackgroundContainer) return;

    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.clipsToBounds = YES;
    container.userInteractionEnabled = NO;
    container.backgroundColor = PPChatAmbientBackgroundColor(self.traitCollection);

    UIImageView *imageView = [[UIImageView alloc] init];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.alpha = 0.08;

    [container addSubview:imageView];
    [self.view insertSubview:container atIndex:0];

    [NSLayoutConstraint activateConstraints:@[
        [container.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [container.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [container.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [container.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [imageView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [imageView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [imageView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [imageView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];

    self.chatBackgroundContainer = container;
    self.chatBackgroundImageView = imageView;

    [self pp_setupBackgroundGlows];
}

- (void)pp_setupBackgroundGlows {
    if (!self.chatBackgroundContainer) return;

    UIView *glow2 = [UIView new];
    glow2.translatesAutoresizingMaskIntoConstraints = NO;
    glow2.backgroundColor = [bageColor colorWithAlphaComponent:0.75];
    glow2.layer.cornerRadius = 140.0;
    glow2.clipsToBounds = YES;
    [self.chatBackgroundContainer addSubview:glow2];

    UIView *glow3 = [UIView new];
    glow3.translatesAutoresizingMaskIntoConstraints = NO;
    glow3.backgroundColor = [AppPrimaryClrShiner colorWithAlphaComponent:0.04];
    glow3.layer.cornerRadius = 110.0;
    glow3.clipsToBounds = YES;
    [self.chatBackgroundContainer addSubview:glow3];

    UIBlurEffect *blurEffect;
    if (@available(iOS 13.0, *)) {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    } else {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.alpha = 0.3;
    [self.chatBackgroundContainer addSubview:blurView];

    [NSLayoutConstraint activateConstraints:@[
        [glow2.centerXAnchor constraintEqualToAnchor:self.chatBackgroundContainer.trailingAnchor constant:-20.0],
        [glow2.centerYAnchor constraintEqualToAnchor:self.chatBackgroundContainer.centerYAnchor],
        [glow2.widthAnchor constraintEqualToConstant:280.0],
        [glow2.heightAnchor constraintEqualToConstant:280.0],

        [glow3.centerXAnchor constraintEqualToAnchor:self.chatBackgroundContainer.leadingAnchor constant:100.0],
        [glow3.centerYAnchor constraintEqualToAnchor:self.chatBackgroundContainer.bottomAnchor constant:-120.0],
        [glow3.widthAnchor constraintEqualToConstant:220.0],
        [glow3.heightAnchor constraintEqualToConstant:220.0],

        [blurView.topAnchor constraintEqualToAnchor:self.chatBackgroundContainer.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:self.chatBackgroundContainer.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:self.chatBackgroundContainer.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:self.chatBackgroundContainer.bottomAnchor]
    ]];
}

// MARK: - Custom Nav Bottom Blur


// MARK: - Custom Nav Bottom Blur
- (void)setupNavBottomBlur
{
    if (self.navBottomBlurView) return;


    self.navBottomBlurView = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleFixed configType:PPButtonConfigrationGlass];
    self.navBottomBlurView.configuration.background.cornerRadius = 0;
    // Optional tint (kept neutral)
    self.navBottomBlurView.alpha = 0.0;
    [self.view addSubview:self.navBottomBlurView];
    self.navBottomBlurView.backgroundColor =  UIColor.clearColor;
    self.navBottomBlurView.configuration.background.backgroundColor =  UIColor.clearColor;
    self.navBottomBlurView.configuration.baseBackgroundColor =  UIColor.clearColor;
    
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    [NSLayoutConstraint activateConstraints:@[
        [self.navBottomBlurView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.navBottomBlurView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.navBottomBlurView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.navBottomBlurView.bottomAnchor constraintEqualToAnchor:safe.topAnchor]
    ]];
    [self pp_bringChatHeaderToFront];
}


- (void)onOtherUserTypingChanged:(BOOL)isTyping {

    if (!self.isViewVisible) {
        [self.typingIndicatorView stopAnimating];
        return;
    }

    isTyping
    ? [self.typingIndicatorView startAnimating]
    : [self.typingIndicatorView stopAnimating];
}


// === Modern Composer Actions ===
- (void)fetchInitForDidLoad {
    self.threadOtherUser = [ChatThreadModel resolveOtherUserFromThread:self.chatThread];
    if (!self.threadOtherUser && self.chatThread.otherUser.ID.length > 0) {
        self.threadOtherUser = self.chatThread.otherUser;
    }
    if (self.threadOtherUser.ID.length > 0) {
        self.chatThread.otherUser = self.threadOtherUser;
    }
    
    NSLog(@"self.threadOtherUser %@",self.threadOtherUser.ID);
    
    NSLayoutYAxisAnchor *topAnchor =
        self.chatHeaderView
            ? self.chatHeaderView.bottomAnchor
            : self.view.safeAreaLayoutGuide.topAnchor;
 
    
    self.typingIndicatorView = [[TypingIndicatorView alloc] init];
    self.typingIndicatorView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.typingIndicatorView];
    [NSLayoutConstraint activateConstraints:@[
        [self.typingIndicatorView.centerXAnchor
         constraintEqualToAnchor:self.view.centerXAnchor constant:0],
        [self.typingIndicatorView.topAnchor
         constraintEqualToAnchor:topAnchor
         constant:12],
    ]];
    
   
    NSString *otherUserID = [self resolvedOtherUserID];
    if (otherUserID.length > 0) {
        self.typingController =
        [[ChTypingController alloc] initWithThreadID:self.chatThread.ID
                                            myUserID:UserManager.sharedManager.currentUser.ID
                                         otherUserID:otherUserID];
    } else {
        self.typingController = nil;
        NSLog(@"⚠️ [Chat] Typing controller skipped because otherUserID is missing");
    }

    __weak typeof(self) weakSelf = self;
    self.typingController.onTypingChanged = ^(BOOL isTyping) {
        NSLog(@"⌨️ OTHER USER TYPING = %@", isTyping ? @"YES" : @"NO");

        if (!weakSelf.isKeyboardVisible && ![weakSelf isNearBottom]) {
            [weakSelf.typingIndicatorView stopAnimating];
            return;
        }

        isTyping
        ? [weakSelf.typingIndicatorView startAnimating]
        : [weakSelf.typingIndicatorView stopAnimating];
    };

    // Correct lifecycle: only attach typing if thread exists
    if (self.chatThread.ID.length > 0) {
        [self.typingController attachThreadID:self.chatThread.ID];
    }
    
    
    // constraints here (see section 3)
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self
                                   action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.tableView addGestureRecognizer:tap];
    
}

	-(void)viewDidAppear:(BOOL)animated
	{
	    [super viewDidAppear:animated];
	    self.isViewVisible = YES;
	    [ChManager sharedManager].activeThreadID = self.chatThread.ID;
        [self pp_applyNotificationHandoffBottomNavigationVisibilityAnimated:animated];
	    [self pp_animatePremiumModalChatHeaderIfNeeded];
	    [self pp_bringChatHeaderToFront];
    // ✅ Handoff finished
    [ChManager sharedManager].isHandlingNotificationHandoff = NO;

    if (!self.didFinishInitialLoad) {
        [self setInitialLoadingVisible:YES];
    }

    __weak typeof(self) weakSelf = self;
    [self ensureThreadThen:^(NSString *threadID) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (threadID.length > 0) {
            [ChManager sharedManager].activeThreadID = threadID;
        }
        [strongSelf startObservingMessagesIfNeeded];
    }];

    [self activateRealtimeAfterInitialLoadIfNeeded];

    // If messages were already loaded before first appearance, force settle at bottom.
    if (self.didFinishInitialLoad && self.messages.count > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self scrollToBottomAnimated:NO];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [self scrollToBottomAnimated:NO];
            });
        });
    }
    
     
}
- (void)playIncomingMessageFeedback
{
    [[PPChatFeedbackManager shared]
     playFeedbackForEvent:PPChatFeedbackEventIncomingActiveChat];
}
#pragma mark - Keyboard Handling (Bottom Sheet Safe)

- (void)registerForKeyboardNotifications {
    if (self.keyboardObserversAdded) return;
    self.keyboardObserversAdded = YES;

    // Will-change-frame covers both presentation and dismissal. Observing the
    // show/hide notifications as well produces duplicate inset/scroll passes.
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(handleKeyboardNotification:)
     name:UIKeyboardWillChangeFrameNotification
     object:nil];
}

- (void)unregisterKeyboardNotifications {
    if (!self.keyboardObserversAdded) return;
    self.keyboardObserversAdded = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)handleKeyboardWillShow:(NSNotification *)note {
    self.isKeyboardVisible = YES;
    [self handleKeyboardNotification:note];
}

- (void)handleKeyboardWillHide:(NSNotification *)note {
    [self handleKeyboardNotification:note];
}
 

- (void)keyboardWillChangeFrame:(NSNotification *)note
{
    [self handleKeyboardNotification:note];
}

- (void)handleKeyboardNotification:(NSNotification *)note
{
    if (!self.isViewLoaded || !self.tableView) return;

    NSDictionary *info = note.userInfo;

    CGRect endFrame =
        [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];

    NSTimeInterval duration =
        [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];

    UIViewAnimationCurve curve =
        [info[UIKeyboardAnimationCurveUserInfoKey] integerValue];

    CGRect keyboardFrameInView = [self.view convertRect:endFrame fromView:nil];
    CGRect keyboardIntersection = CGRectIntersection(self.view.bounds, keyboardFrameInView);
    CGFloat rawKeyboardHeight = CGRectIsNull(keyboardIntersection)
        ? 0.0
        : MAX(0.0, CGRectGetHeight(keyboardIntersection));

    // ✅ IMPORTANT: subtract safe-area only
    CGFloat keyboardHeight =
        MAX(0, rawKeyboardHeight - self.view.safeAreaInsets.bottom);

    BOOL shouldKeepBottomPinned = [self isNearBottom];
    CGFloat previousOffsetY = self.tableView.contentOffset.y;
    self.currentKeyboardHeight = rawKeyboardHeight;
    self.isKeyboardVisible = rawKeyboardHeight > 0.5;

    self.inputBarBottomConstraint.constant = self.isKeyboardVisible
        ? -(keyboardHeight + 8.0)
        : [self pp_restingInputBarBottomConstant];
    self.swiftUIInputBarBottomConstraint.constant = self.isKeyboardVisible
        ? -(keyboardHeight + 8.0)
        : [self pp_restingSwiftUIInputBarBottomConstant];

    UIViewAnimationOptions options =
        UIViewAnimationOptionBeginFromCurrentState |
        UIViewAnimationOptionAllowUserInteraction |
        (UIViewAnimationOptions)(curve << 16);

    [UIView animateWithDuration:duration
                          delay:0
                        options:options
                     animations:^{
        [self.view layoutIfNeeded];
        [self pp_applyTableViewBottomInsetForActiveComposer];

        if (shouldKeepBottomPinned) {
            [self pp_scrollTableViewToBottomWithoutAnimation];
        } else {
            UIEdgeInsets insets = self.tableView.adjustedContentInset;
            CGFloat minOffsetY = -insets.top;
            CGFloat maxOffsetY = MAX(minOffsetY,
                                     self.tableView.contentSize.height - self.tableView.bounds.size.height + insets.bottom);
            CGFloat preservedOffsetY = MIN(MAX(previousOffsetY, minOffsetY), maxOffsetY);
            [self.tableView setContentOffset:CGPointMake(0.0, preservedOffsetY) animated:NO];
        }
    } completion:^(__unused BOOL finished) {
        if (shouldKeepBottomPinned) {
            [self pp_scrollTableViewToBottomWithoutAnimation];
        }
    }];
}










- (void)prepareLocalAudioForMessage:(ChatMessageModel *)msg
                         completion:(void (^)(NSURL *localURL))completion {
    if (!msg.fileURL.length) {
        completion(nil);
        return;
    }

    // Already local
    if ([msg.fileURL hasPrefix:@"file://"]) {
        completion([NSURL URLWithString:msg.fileURL]);
        return;
    }

    NSString *fileName = [NSString stringWithFormat:@"chat_%@.m4a", msg.ID];

    NSString *localPath =
        [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];

    NSURL *localURL = [NSURL fileURLWithPath:localPath];

    // Cached?
    if ([[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
        completion(localURL);
        return;
    }

    NSLog(@"⬇️ [Audio] Downloading remote audio…");

    NSURLSessionDownloadTask *task = [[NSURLSession sharedSession]
        downloadTaskWithURL:[NSURL URLWithString:msg.fileURL]
          completionHandler:^(NSURL *location, NSURLResponse *response,
                              NSError *error) {
            if (error) {
                NSLog(@"❌ [Audio] Download failed: %@",
                      error.localizedDescription);
                dispatch_async(dispatch_get_main_queue(), ^{
                  completion(nil);
                });
                return;
            }

            NSLog(@"✅ [Audio] Download succeeded");
            [[NSFileManager defaultManager] moveItemAtURL:location
                                                    toURL:localURL
                                                    error:nil];

            dispatch_async(dispatch_get_main_queue(), ^{
              completion(localURL);
            });
          }];
    [task resume];
}


- (void)observeMessages
{
    if (self.isObservingMessages || !self.chatThread.ID.length) return;
    if (self.messagePageLimit <= 0) self.messagePageLimit = PPChatInitialMessagePageLimit;
    self.isObservingMessages = YES;

    FIRCollectionReference *ref =
    [[[[FIRFirestore firestore]
       collectionWithPath:@"Chats"]
      documentWithPath:self.chatThread.ID]
     collectionWithPath:@"Messages"];

    __weak typeof(self) weakSelf = self;

    FIRQuery *query = [[ref queryOrderedByField:@"timestamp"] queryLimitedToLast:self.messagePageLimit];

    self.messageListener =
    [query addSnapshotListener:^(FIRQuerySnapshot *snapshot, NSError *error) {

        if (error || !snapshot) {
            NSLog(@"❌ [Chat] Snapshot error: %@", error.localizedDescription);
            [weakSelf setInitialLoadingVisible:NO];
            weakSelf.isExpandingMessagePage = NO;
            weakSelf.previousContentHeightBeforeExpansion = 0.0;
            weakSelf.previousContentOffsetYBeforeExpansion = 0.0;
            weakSelf.isObservingMessages = NO;
            [weakSelf.messageListener remove];
            weakSelf.messageListener = nil;
            [weakSelf scheduleMessageResubscribe];
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            // =========================
            // INITIAL LOAD
            // =========================
            if (!self.didFinishInitialLoad) {

	                [self.messages removeAllObjects];
	                [self.lastKnownStatuses removeAllObjects];
	                [self.cachedHeights removeAllObjects];

                for (FIRDocumentSnapshot *doc in snapshot.documents) {
                    ChatMessageModel *msg =
                    [self pp_messageModelFromSnapshot:doc];

                    [self.messages addObject:msg];
                    self.lastKnownStatuses[msg.ID] = @(msg.status);
                }

                self.didFinishInitialLoad = YES;
                [self.tableView reloadData];
                [self.tableView layoutIfNeeded];
                if (self.isExpandingMessagePage && self.previousContentHeightBeforeExpansion > 0.0) {
                    CGFloat newContentHeight = self.tableView.contentSize.height;
                    CGFloat delta = MAX(0.0, newContentHeight - self.previousContentHeightBeforeExpansion);
                    [self.tableView setContentOffset:CGPointMake(0.0, self.previousContentOffsetYBeforeExpansion + delta)
                                            animated:NO];
                    self.isExpandingMessagePage = NO;
                    self.previousContentHeightBeforeExpansion = 0.0;
                    self.previousContentOffsetYBeforeExpansion = 0.0;
                } else {
                    [self scrollToBottomAnimated:NO];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)),
                                   dispatch_get_main_queue(), ^{
                        [self scrollToBottomAnimated:NO];
                    });
                }
                [self setInitialLoadingVisible:NO];
                [self pp_updateChatEmptyStateAnimated:YES];
                [self activateRealtimeAfterInitialLoadIfNeeded];

                NSLog(@"✅ [Chat] Initial load complete (%lu)",
                      (unsigned long)self.messages.count);
                return;
            }

            // =========================
            // INCREMENTAL CHANGES
            // =========================
            for (FIRDocumentChange *change in snapshot.documentChanges) {

                NSString *msgID = change.document.documentID;

                NSInteger index =
                [self.messages indexOfObjectPassingTest:^BOOL(ChatMessageModel *obj,
                                                              NSUInteger idx,
                                                              BOOL *stop) {
                    return [obj.ID isEqualToString:msgID];
                }];

                if (change.type == FIRDocumentChangeTypeAdded) {

                    // 🔒 DEDUPLICATION GUARD
                    if (index != NSNotFound) {
	                        // Already exists → just update fields
	                        ChatMessageModel *existing = self.messages[index];
	                        BOOL wasDeleted = existing.isDeleted;
	                        [existing updateFromDictionary:change.document.data];
	                        [self.cachedHeights removeObjectForKey:existing.ID];
	                        if (wasDeleted != existing.isDeleted) {
	                            NSIndexPath *path = [NSIndexPath indexPathForRow:index inSection:0];
	                            [self.tableView reloadRowsAtIndexPaths:@[path]
	                                                  withRowAnimation:UITableViewRowAnimationFade];
	                        }
	                        continue;
                    }

                    // New message
                    ChatMessageModel *msg =
                    [self pp_messageModelFromSnapshot:change.document];

                    BOOL shouldStickToBottom = [self isNearBottom];
                    NSInteger insertIndex =
                        MIN((NSInteger)change.newIndex, (NSInteger)self.messages.count);
                    [self.messages insertObject:msg atIndex:insertIndex];
                    self.lastKnownStatuses[msg.ID] = @(msg.status);

                    NSIndexPath *ip =
                    [NSIndexPath indexPathForRow:insertIndex
                                       inSection:0];

                    [self.tableView insertRowsAtIndexPaths:@[ip]
                                          withRowAnimation:UITableViewRowAnimationNone];

                    if (self.isViewVisible &&
                        [msg.senderID isEqualToString:self.threadOtherUser.ID]) {
                        [[PPChatFeedbackManager shared]
                         playFeedbackForEvent:PPChatFeedbackEventIncomingActiveChat];
                        [self markThreadMessagesAsReadIfNeeded];
                    }

                    if (shouldStickToBottom) {
                        [self scrollToBottomAnimated:YES];
                    }
                }

                else if (change.type == FIRDocumentChangeTypeModified) {

                    if (index == NSNotFound) {
                        ChatMessageModel *missing =
                            [self pp_messageModelFromSnapshot:change.document];
                        NSInteger insertIndex =
                            MIN((NSInteger)change.newIndex, (NSInteger)self.messages.count);
                        [self.messages insertObject:missing atIndex:insertIndex];
                        self.lastKnownStatuses[missing.ID] = @(missing.status);
                        NSIndexPath *ip = [NSIndexPath indexPathForRow:insertIndex inSection:0];
                        [self.tableView insertRowsAtIndexPaths:@[ip]
                                              withRowAnimation:UITableViewRowAnimationNone];
                        continue;
                    }

	                    ChatMessageModel *msg = self.messages[index];
	                    BOOL wasDeleted = msg.isDeleted;
	                    [msg updateFromDictionary:change.document.data];
	                    [self.cachedHeights removeObjectForKey:msg.ID];
	                    if (wasDeleted != msg.isDeleted) {
	                        NSIndexPath *path = [NSIndexPath indexPathForRow:index inSection:0];
	                        [self.tableView reloadRowsAtIndexPaths:@[path]
	                                              withRowAnimation:UITableViewRowAnimationFade];
	                    }

                    NSNumber *prev = self.lastKnownStatuses[msg.ID];
                    NSNumber *curr = @(msg.status);

                    if (![prev isEqualToNumber:curr]) {
                        self.lastKnownStatuses[msg.ID] = curr;

                        if (msg.status == ChatMessageStatusRead &&
                            [msg.senderID isEqualToString:UserManager.sharedManager.currentUser.ID]) {
                            [[PPChatFeedbackManager shared]
                             playFeedbackForEvent:PPChatFeedbackEventMessageRead];
                        }

                        NSIndexPath *ip =
                        [NSIndexPath indexPathForRow:index inSection:0];

                        UITableViewCell *cell =
                        [self.tableView cellForRowAtIndexPath:ip];

                        if ([cell conformsToProtocol:@protocol(ChatMessageStatusUpdatable)]) {
                            [(id<ChatMessageStatusUpdatable>)cell updateMessageStatus:msg];
                        }
                    }

                    NSInteger newIndex = (NSInteger)change.newIndex;
                    if (newIndex != NSNotFound &&
                        newIndex >= 0 &&
                        newIndex < (NSInteger)self.messages.count &&
                        newIndex != index) {
                        [self.messages removeObjectAtIndex:index];
                        [self.messages insertObject:msg atIndex:newIndex];
                        NSIndexPath *fromIP = [NSIndexPath indexPathForRow:index inSection:0];
                        NSIndexPath *toIP = [NSIndexPath indexPathForRow:newIndex inSection:0];
                        [self.tableView moveRowAtIndexPath:fromIP toIndexPath:toIP];
                    }
                }

                else if (change.type == FIRDocumentChangeTypeRemoved) {
                    if (index == NSNotFound) continue;
	                    ChatMessageModel *msg = self.messages[index];
	                    [self.lastKnownStatuses removeObjectForKey:msg.ID];
	                    [self.cachedHeights removeObjectForKey:msg.ID];
                    [self.messages removeObjectAtIndex:index];
                    NSIndexPath *ip = [NSIndexPath indexPathForRow:index inSection:0];
                    [self.tableView deleteRowsAtIndexPaths:@[ip]
                                          withRowAnimation:UITableViewRowAnimationFade];
                }
            }
            [self pp_updateChatEmptyStateAnimated:YES];
        });
    }];
}

- (void)applyStatusUpdateForMessage:(ChatMessageModel *)msg
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSInteger index =
        [self.messages indexOfObjectPassingTest:^BOOL(ChatMessageModel *obj, NSUInteger idx, BOOL *stop) {
            return [obj.ID isEqualToString:msg.ID];
        }];

        if (index == NSNotFound) return;

        NSIndexPath *ip = [NSIndexPath indexPathForRow:index inSection:0];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:ip];

        if ([cell respondsToSelector:@selector(updateMessageStatus:)]) {
            [(id)cell updateMessageStatus:msg];
        }
    });
}
- (void)updateMessageStatus:(ChatMessageModel *)msg
{
    if (!msg || !msg.ID.length) return;

    dispatch_async(dispatch_get_main_queue(), ^{

        NSInteger row =
        [self.messages indexOfObjectPassingTest:^BOOL(ChatMessageModel *obj,
                                                      NSUInteger idx,
                                                      BOOL *stop) {
            return [obj.ID isEqualToString:msg.ID];
        }];

        if (row == NSNotFound) return;

        NSIndexPath *ip = [NSIndexPath indexPathForRow:row inSection:0];

        UITableViewCell *cell =
        [self.tableView cellForRowAtIndexPath:ip];

        // 🔹 If cell is offscreen → DO NOTHING
        // It WILL update correctly in cellForRow
        if (!cell) return;

        // 🔥 Unified, safe, future-proof
        if ([cell conformsToProtocol:@protocol(ChatMessageStatusUpdatable)]) {
            [(id<ChatMessageStatusUpdatable>)cell updateMessageStatus:msg];
        }
    });
}


@end
