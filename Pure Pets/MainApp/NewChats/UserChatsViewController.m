//
//  UserChatsViewController.m
//  Pure Pets
//
//  Created by Mohamed Ahmed on 26/07/2025.
//  Refactored 2026 – Modern Chat Inbox
//

#import "UserChatsViewController.h"

#import "ChatPresenceManager.h"
#import "PPEmptyStateHelper.h"
#import "PPImageLoaderManager.h"
#import "PPOverlayCoordinator.h"
#import "PPHUD.h"
#import "Pure_Pets-Swift.h" // PPChatCellBridge (Swift) replaces ChCell
#import "PPChatsFunc.h"
#import "PPSelectOptionViewController.h"
#import "PPStoriesViewController.h"

#import <FirebaseAuth/FirebaseAuth.h>
#import <UIKit/UIKit.h>

static const CGFloat PPChatStoriesHeaderHiddenHeight = 8.0;
static const CGFloat PPChatStoriesHeaderVisibleHeight = 208.0;
static const CGFloat PPChatListContentTopInset = 10.0;
static const CGFloat PPChatListContentBottomInset = 128.0;
static const CGFloat PPChatListEstimatedRowHeight = 84.0;
static const CGFloat PPChatInboxHeaderSideInset = 18.0;
static const CGFloat PPChatInboxHeaderTopInset = 8.0;
static const CGFloat PPChatInboxComposeButtonSize = 44.0;

@interface UserChatsViewController ()
<UITableViewDelegate, UITableViewDataSource, UITableViewDataSourcePrefetching>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<ChatThreadModel *> *threads;
@property (nonatomic, strong) id<FIRListenerRegistration> threadsListener;
@property (nonatomic, copy) NSString *observedChatIdentity;
@property (nonatomic, strong) id presenceToken;
@property (nonatomic, strong) PPEmptyStateConfig *config;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UIView *tableHeaderContainer;
@property (nonatomic, strong) UIView *inboxHeaderView;
@property (nonatomic, strong) UIView *inboxAccentRailView;
@property (nonatomic, strong) UILabel *inboxEyebrowLabel;
@property (nonatomic, strong) UILabel *inboxTitleLabel;
@property (nonatomic, strong) UILabel *inboxSummaryLabel;
@property (nonatomic, strong) UIButton *composeButton;
@property (nonatomic, strong) UIView *storiesHeaderContainer;
@property (nonatomic, strong) PPStoriesViewController *storiesViewController;
@property (nonatomic, strong) NSMutableSet<NSString *> *resolvingOtherUserIDs;
@property (nonatomic, strong) NSMutableSet<NSString *> *animatedThreadIDs;
@property (nonatomic, strong) PPChatCellBridge *chatCellBridge;
@property (nonatomic, assign) BOOL storiesHeaderVisible;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL isObserving;
@property (nonatomic, assign) BOOL isPerformingLocalMutation;
@property (nonatomic, assign) CGFloat storiesHeaderHeight;
@property (nonatomic, assign) UserChatsState state;
@property (nonatomic, strong) NSError *loadError;
@property (nonatomic, assign) BOOL didRunHeaderEntrance;
@property (nonatomic, assign) BOOL didRunListEntrance;
@property (nonatomic, assign) BOOL didAppear;
@property (nonatomic, assign) BOOL willAppear;
@end

@implementation UserChatsViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.didAppear = NO;
    self.willAppear = NO;
    
    self.threads = @[];
    self.isLoading = YES;
    self.state = UserChatsStateLoading;
    self.resolvingOtherUserIDs = [NSMutableSet set];
    self.animatedThreadIDs = [NSMutableSet set];
    self.chatCellBridge = [PPChatCellBridge new];

    [self pp_configureAppearance];
    [self pp_configureTableView];
    [self pp_configureInboxHeader];
    [self pp_configureStoriesHeader];
    [self pp_configureEmptyState];
    [self pp_configureLoadingIndicator];
    [self pp_registerNotifications];
    [self pp_updateEmptyState];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if(self.willAppear) return;
    [self startObservingChats];
    [self.storiesViewController startObservingStories];
    [self handleUnreadUpdate];
    [self.chatCellBridge collapseExpanded];
    self.willAppear = YES;
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if(self.didAppear) return;
    [self startObservingOnlineStatus];
    [self pp_runHeaderEntranceIfNeeded];
    [self pp_scheduleListEntranceIfNeeded];
    self.didAppear = YES;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    if (self.storiesHeaderContainer) {
        CGFloat height = self.storiesHeaderVisible
            ? [self pp_storiesVisibleHeight]
            : PPChatStoriesHeaderHiddenHeight;
        [self pp_applyStoriesHeaderHeight:height];
    }
    [self pp_layoutTableHeaderIfNeeded];
    [self pp_applyPremiumBottomContentInset];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self stopObservingChats];
    [self.storiesViewController stopObservingStories];

    if (self.presenceToken) {
        [[ChatPresenceManager shared] removePresenceObserver:self.presenceToken];
        self.presenceToken = nil;
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    BOOL contentSizeChanged = !previousTraitCollection ||
        ![previousTraitCollection.preferredContentSizeCategory
          isEqualToString:self.traitCollection.preferredContentSizeCategory];
    if (contentSizeChanged) {
        if (self.storiesHeaderVisible) {
            [self pp_applyStoriesHeaderHeight:[self pp_storiesVisibleHeight]];
        } else {
            [self pp_layoutTableHeaderIfNeeded];
        }
        [self.tableView setNeedsLayout];
    }
}

- (void)pp_reduceMotionStatusDidChange:(NSNotification *)notification {
    (void)notification;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.inboxHeaderView.transform = CGAffineTransformIdentity;
        self.composeButton.transform = CGAffineTransformIdentity;
        self.inboxAccentRailView.transform = CGAffineTransformIdentity;
        // PPExpandableChatCell handles Reduce Motion internally;
        // no entrance replay needed.
    }
    [self pp_updateEmptyState];
}

- (void)dealloc {
    [self stopObservingChats];

    if (self.presenceToken) {
        [[ChatPresenceManager shared] removePresenceObserver:self.presenceToken];
        self.presenceToken = nil;
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"UnreadCountsUpdated"
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"forceReloadThreads"
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIAccessibilityReduceMotionStatusDidChangeNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"LanguageDidChangeNotification"
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:PPLanguageDidChangeNotification
                                                  object:nil];
}

#pragma mark - Setup

- (void)pp_configureAppearance {
    self.view.backgroundColor = self.shouldHideStories
        ? UIColor.clearColor
        : [PPChatsFunc chatCanvasBackgroundColor];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
}

- (void)pp_configureTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.prefetchDataSource = self;
    self.tableView.prefetchingEnabled = YES;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = PPChatListEstimatedRowHeight;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.delaysContentTouches = NO;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.contentInset = UIEdgeInsetsMake(PPChatListContentTopInset, 0.0, PPChatListContentBottomInset, 0.0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
    self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAlways;
    self.tableView.tableFooterView = [UIView new];
    self.tableView.accessibilityIdentifier = @"userChatsTableView";
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:PPChatCellBridge.reuseID];

    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }

    [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)pp_applyPremiumBottomContentInset
{
    if (!self.tableView) {
        return;
    }
    UIEdgeInsets contentInset = self.tableView.contentInset;
    contentInset.top = PPChatListContentTopInset;
    contentInset.bottom = MAX(contentInset.bottom, PPChatListContentBottomInset);
    self.tableView.contentInset = contentInset;

    UIEdgeInsets indicatorInset = self.tableView.scrollIndicatorInsets;
    indicatorInset.top = PPChatListContentTopInset;
    indicatorInset.bottom = MAX(indicatorInset.bottom, PPChatListContentBottomInset);
    self.tableView.scrollIndicatorInsets = indicatorInset;
}

- (void)pp_configureInboxHeader {
    if (self.shouldHideStories) {
        return;
    }

    self.tableHeaderContainer = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableHeaderContainer.backgroundColor = UIColor.clearColor;
    self.tableHeaderContainer.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.tableView.tableHeaderView = self.tableHeaderContainer;

    self.inboxHeaderView = [UIView new];
    self.inboxHeaderView.backgroundColor = UIColor.clearColor;
    self.inboxHeaderView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.inboxHeaderView.isAccessibilityElement = NO;
    [self.tableHeaderContainer addSubview:self.inboxHeaderView];

    self.inboxAccentRailView = [UIView new];
    self.inboxAccentRailView.backgroundColor = [PPChatsFunc chatNeutralAccentColor];
    self.inboxAccentRailView.layer.cornerRadius = 1.5;
    self.inboxAccentRailView.userInteractionEnabled = NO;
    [self.inboxHeaderView addSubview:self.inboxAccentRailView];

    self.inboxEyebrowLabel = [UILabel new];
    self.inboxEyebrowLabel.font =
        [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1]
         scaledFontForFont:([GM boldFontWithSize:11.5]
                            ?: [UIFont systemFontOfSize:11.5 weight:UIFontWeightSemibold])];
    self.inboxEyebrowLabel.adjustsFontForContentSizeCategory = YES;
    self.inboxEyebrowLabel.textColor = [[PPChatsFunc chatNeutralAccentColor] colorWithAlphaComponent:0.88];
    self.inboxEyebrowLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.inboxEyebrowLabel.text = kLang(@"notifications_hub_hero_eyebrow");
    self.inboxEyebrowLabel.isAccessibilityElement = NO;
    [self.inboxHeaderView addSubview:self.inboxEyebrowLabel];

    self.inboxTitleLabel = [UILabel new];
    self.inboxTitleLabel.font =
        [[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle1]
         scaledFontForFont:([GM boldFontWithSize:27.0]
                            ?: [UIFont systemFontOfSize:27.0 weight:UIFontWeightBold])];
    self.inboxTitleLabel.adjustsFontForContentSizeCategory = YES;
    self.inboxTitleLabel.textColor = UIColor.labelColor;
    self.inboxTitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.inboxTitleLabel.numberOfLines = 0;
    self.inboxTitleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    self.inboxTitleLabel.text = kLang(@"pet_chats_tab");
    [self.inboxHeaderView addSubview:self.inboxTitleLabel];

    self.inboxSummaryLabel = [UILabel new];
    self.inboxSummaryLabel.font =
        [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
         scaledFontForFont:([GM MidFontWithSize:14.0]
                            ?: [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline])];
    self.inboxSummaryLabel.adjustsFontForContentSizeCategory = YES;
    self.inboxSummaryLabel.textColor = UIColor.secondaryLabelColor;
    self.inboxSummaryLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.inboxSummaryLabel.numberOfLines = 0;
    [self.inboxHeaderView addSubview:self.inboxSummaryLabel];

    self.composeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.composeButton.tintColor = [PPChatsFunc chatNeutralAccentColor];
    self.composeButton.layer.cornerRadius = PPChatInboxComposeButtonSize * 0.5;
    self.composeButton.clipsToBounds = YES;
    UIImageSymbolConfiguration *symbolConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:16.0
                                                        weight:UIImageSymbolWeightSemibold];
    UIImage *composeImage = [UIImage systemImageNamed:@"square.and.pencil"
                                     withConfiguration:symbolConfig];
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *configuration = [UIButtonConfiguration glassButtonConfiguration];
        configuration.image = composeImage;
        self.composeButton.configuration = configuration;
    } else {
        self.composeButton.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.78];
        [self.composeButton setImage:composeImage forState:UIControlStateNormal];
    }
    [self.composeButton addTarget:self
                           action:@selector(startNewChat)
                 forControlEvents:UIControlEventTouchUpInside];
    self.composeButton.accessibilityLabel = kLang(@"empty_chats_button");
    self.composeButton.accessibilityHint = kLang(@"chat_inbox_compose_hint");
    [self.inboxHeaderView addSubview:self.composeButton];

    self.inboxHeaderView.accessibilityElements = @[
        self.inboxTitleLabel,
        self.inboxSummaryLabel,
        self.composeButton
    ];
    [self pp_updateInboxSummaryAnimated:NO];

    if (!UIAccessibilityIsReduceMotionEnabled()) {
        self.inboxHeaderView.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
        self.composeButton.transform = CGAffineTransformMakeScale(0.92, 0.92);
        self.inboxAccentRailView.transform = CGAffineTransformMakeScale(1.0, 0.08);
    }
}

- (void)pp_configureLoadingIndicator {
    self.loadingIndicator = [[UIActivityIndicatorView alloc]
                             initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.color = [PPChatsFunc chatNeutralAccentColor];
    self.loadingIndicator.accessibilityLabel = kLang(@"chat_inbox_loading");
    [self.view addSubview:self.loadingIndicator];
    [NSLayoutConstraint activateConstraints:@[
        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

- (void)pp_configureStoriesHeader {
    if (self.shouldHideStories) {
        return;
    }
    if (self.storiesViewController) {
        return;
    }

    CGFloat width = CGRectGetWidth(self.tableView.bounds);
    if (width <= 0.0) {
        width = CGRectGetWidth(self.view.bounds);
    }

    if (!self.tableHeaderContainer) {
        self.tableHeaderContainer = [[UIView alloc] initWithFrame:CGRectZero];
        self.tableHeaderContainer.backgroundColor = UIColor.clearColor;
        self.tableView.tableHeaderView = self.tableHeaderContainer;
    }

    self.storiesHeaderHeight = PPChatStoriesHeaderHiddenHeight;
    self.storiesHeaderContainer =
    [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, width, self.storiesHeaderHeight)];
    self.storiesHeaderContainer.backgroundColor = UIColor.clearColor;
    self.storiesHeaderContainer.clipsToBounds = NO;
    self.storiesHeaderContainer.layer.cornerRadius = 22;
    if (@available(iOS 13.0, *)) {
        self.storiesHeaderContainer.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.tableHeaderContainer addSubview:self.storiesHeaderContainer];

    PPStoriesViewController *storiesVC = [PPStoriesViewController new];
    storiesVC.sectionTitleLocalizationKey = @"chat_stories_title";

    __weak typeof(self) weakSelf = self;
    storiesVC.onStoriesChanged = ^(NSArray<PPStory *> *stories) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        BOOL hasIdentity = [self pp_currentChatIdentity].length > 0;
        BOOL shouldShowStories = hasIdentity || stories.count > 0;
        [self pp_setStoriesHeaderVisible:shouldShowStories animated:YES];
    };

    [self addChildViewController:storiesVC];
    storiesVC.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.storiesHeaderContainer addSubview:storiesVC.view];
    [NSLayoutConstraint activateConstraints:@[
        [storiesVC.view.leadingAnchor constraintEqualToAnchor:self.storiesHeaderContainer.leadingAnchor],
        [storiesVC.view.trailingAnchor constraintEqualToAnchor:self.storiesHeaderContainer.trailingAnchor],
        [storiesVC.view.topAnchor constraintEqualToAnchor:self.storiesHeaderContainer.topAnchor],
        [storiesVC.view.bottomAnchor constraintEqualToAnchor:self.storiesHeaderContainer.bottomAnchor]
    ]];
    [storiesVC didMoveToParentViewController:self];

    self.storiesViewController = storiesVC;
    [self pp_setStoriesHeaderVisible:NO animated:NO];
    [self.storiesViewController reloadStories];
}

- (void)pp_configureEmptyState {
    self.config = [PPEmptyStateConfig new];
    self.config.animationName = @"";
    self.config.isNetworkFile = NO;
    self.config.title = kLang(@"empty_chats_title");
    self.config.subTitle = kLang(@"empty_chats_subtitle");
    self.config.buttonTitle = kLang(@"empty_chats_button");
    self.config.target = self;
    self.config.action = @selector(startNewChat);
}

- (void)pp_registerNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleUnreadUpdate)
                                                 name:@"UnreadCountsUpdated"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_forceReloadThreadsNotification:)
                                                 name:@"forceReloadThreads"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_reduceMotionStatusDidChange:)
                                                 name:UIAccessibilityReduceMotionStatusDidChangeNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_languageDidChange:)
                                                 name:@"LanguageDidChangeNotification"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_languageDidChange:)
                                                 name:PPLanguageDidChangeNotification
                                               object:nil];
}

- (void)pp_languageDidChange:(NSNotification *)notification {
    (void)notification;

    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.tableView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.tableHeaderContainer.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.inboxHeaderView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.storiesHeaderContainer.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    self.inboxEyebrowLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.inboxEyebrowLabel.text = kLang(@"notifications_hub_hero_eyebrow");
    self.inboxTitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.inboxTitleLabel.text = kLang(@"pet_chats_tab");
    self.inboxSummaryLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.composeButton.accessibilityLabel = kLang(@"empty_chats_button");
    self.composeButton.accessibilityHint = kLang(@"chat_inbox_compose_hint");
    self.loadingIndicator.accessibilityLabel = kLang(@"chat_inbox_loading");

    [self pp_configureEmptyState];
    [self pp_updateInboxSummaryAnimated:NO];
    [self pp_updateEmptyState];
    [self pp_layoutTableHeaderIfNeeded];
    [self.tableView reloadData];
}

- (void)pp_forceReloadThreadsNotification:(NSNotification *)notification {
    (void)notification;
    [self forceReloadThreads];
}

#pragma mark - Stories Header

- (CGFloat)pp_storiesVisibleHeight {
    CGFloat width = CGRectGetWidth(self.tableView.bounds);
    if (width <= 0.0) {
        width = CGRectGetWidth(self.view.bounds);
    }
    if (width <= 0.0) {
        width = UIScreen.mainScreen.bounds.size.width;
    }

    CGFloat requiredHeight =
        [self.storiesViewController requiredContentHeightForWidth:width];
    return MAX(PPChatStoriesHeaderVisibleHeight, requiredHeight);
}

- (void)pp_setStoriesHeaderVisible:(BOOL)visible animated:(BOOL)animated {
    if (self.shouldHideStories) {
        return;
    }
    if (self.storiesHeaderVisible == visible && self.storiesViewController.view.hidden == !visible) {
        return;
    }

    self.storiesHeaderVisible = visible;
    CGFloat targetHeight = visible
        ? [self pp_storiesVisibleHeight]
        : PPChatStoriesHeaderHiddenHeight;

    void (^changes)(void) = ^{
        self.storiesViewController.view.hidden = NO;
        self.storiesViewController.view.alpha = visible ? 1.0 : 0.0;
        [self pp_applyStoriesHeaderHeight:targetHeight];
        [self.tableView layoutIfNeeded];
    };

    void (^completion)(BOOL) = ^(__unused BOOL finished) {
        self.storiesViewController.view.hidden = !visible;
    };

    if (animated) {
        [UIView animateWithDuration:0.24
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:changes
                         completion:completion];
    } else {
        changes();
        completion(YES);
    }
}

- (void)pp_applyStoriesHeaderHeight:(CGFloat)height {
    if (!self.storiesHeaderContainer) {
        return;
    }

    self.storiesHeaderHeight = height;
    [self pp_layoutTableHeaderIfNeeded];
}

- (void)pp_layoutTableHeaderIfNeeded {
    if (!self.tableHeaderContainer) {
        return;
    }

    CGFloat width = CGRectGetWidth(self.tableView.bounds);
    if (width <= 0.0) {
        width = CGRectGetWidth(self.view.bounds);
    }
    if (width <= 0.0) {
        width = UIScreen.mainScreen.bounds.size.width;
    }

    CGFloat nextY = 0.0;
    if (self.inboxHeaderView) {
        BOOL isRTL = [Language isRTL];
        BOOL usesAccessibilityLayout =
            UIContentSizeCategoryIsAccessibilityCategory(
                self.traitCollection.preferredContentSizeCategory);
        CGFloat headerWidth = MIN(MAX(0.0, width - (PPChatInboxHeaderSideInset * 2.0)), 720.0);
        CGFloat headerX = floor((width - headerWidth) * 0.5);
        CGFloat padding = PPSpaceBase;
        CGFloat actionX = isRTL
            ? padding
            : headerWidth - padding - PPChatInboxComposeButtonSize;
        self.composeButton.frame = CGRectMake(actionX,
                                              PPSpaceMD,
                                              PPChatInboxComposeButtonSize,
                                              PPChatInboxComposeButtonSize);

        CGFloat actionAllowance = PPChatInboxComposeButtonSize + PPSpaceMD;
        CGFloat textX = isRTL ? padding + actionAllowance : padding;
        CGFloat textWidth = MAX(0.0, headerWidth - (padding * 2.0) - actionAllowance);
        CGFloat eyebrowY = PPSpaceMD;
        CGFloat eyebrowHeight = MAX(self.inboxEyebrowLabel.font.lineHeight,
                                    ceil([self.inboxEyebrowLabel sizeThatFits:
                                          CGSizeMake(textWidth, CGFLOAT_MAX)].height));
        self.inboxEyebrowLabel.frame = CGRectMake(textX,
                                                  eyebrowY,
                                                  textWidth,
                                                  eyebrowHeight);

        CGFloat titleY = CGRectGetMaxY(self.inboxEyebrowLabel.frame) + PPSpaceXXS;
        if (usesAccessibilityLayout) {
            textX = padding;
            textWidth = MAX(0.0, headerWidth - (padding * 2.0));
            titleY = MAX(titleY, CGRectGetMaxY(self.composeButton.frame) + PPSpaceSM);
        }
        CGFloat titleHeight = MAX(self.inboxTitleLabel.font.lineHeight,
                                  ceil([self.inboxTitleLabel sizeThatFits:
                                        CGSizeMake(textWidth, CGFLOAT_MAX)].height));
        self.inboxTitleLabel.frame = CGRectMake(textX,
                                                titleY,
                                                textWidth,
                                                titleHeight);

        CGFloat summaryY = CGRectGetMaxY(self.inboxTitleLabel.frame) + PPSpaceXS;
        CGFloat summaryHeight = MAX(self.inboxSummaryLabel.font.lineHeight,
                                    ceil([self.inboxSummaryLabel sizeThatFits:
                                          CGSizeMake(textWidth, CGFLOAT_MAX)].height));
        self.inboxSummaryLabel.frame = CGRectMake(textX,
                                                  summaryY,
                                                  textWidth,
                                                  summaryHeight);

        CGFloat headerHeight = MAX(CGRectGetMaxY(self.inboxSummaryLabel.frame) + PPSpaceMD,
                                   CGRectGetMaxY(self.composeButton.frame) + PPSpaceMD);
        self.inboxHeaderView.frame = CGRectMake(headerX,
                                                PPChatInboxHeaderTopInset,
                                                headerWidth,
                                                headerHeight);
        CGFloat railX = isRTL ? headerWidth - 3.0 : 0.0;
        self.inboxAccentRailView.frame = CGRectMake(railX,
                                                    PPSpaceMD,
                                                    3.0,
                                                    MAX(0.0, headerHeight - (PPSpaceMD * 2.0)));
        nextY = CGRectGetMaxY(self.inboxHeaderView.frame) + PPSpaceSM;
    }

    if (self.storiesHeaderContainer) {
        self.storiesHeaderContainer.frame = CGRectMake(0.0,
                                                       nextY,
                                                       width,
                                                       self.storiesHeaderHeight);
        nextY = CGRectGetMaxY(self.storiesHeaderContainer.frame);
    }

    CGRect headerFrame = self.tableHeaderContainer.frame;
    BOOL sizeChanged = fabs(headerFrame.size.width - width) > 0.5 ||
        fabs(headerFrame.size.height - nextY) > 0.5;
    if (!sizeChanged) {
        return;
    }
    self.tableHeaderContainer.frame = CGRectMake(0.0, 0.0, width, nextY);
    self.tableView.tableHeaderView = self.tableHeaderContainer;
}

- (NSInteger)pp_totalUnreadCount {
    NSInteger unreadCount = 0;
    for (ChatThreadModel *thread in self.threads ?: @[]) {
        unreadCount += MAX(thread.unreadCount, 0);
    }
    return unreadCount;
}

- (NSString *)pp_pluralCategoryForCount:(NSInteger)count {
    if (![Language isRTL]) {
        return count == 1 ? @"one" : @"other";
    }

    NSInteger absoluteCount = labs(count);
    NSInteger moduloHundred = absoluteCount % 100;
    if (absoluteCount == 0) return @"zero";
    if (absoluteCount == 1) return @"one";
    if (absoluteCount == 2) return @"two";
    if (moduloHundred >= 3 && moduloHundred <= 10) return @"few";
    if (moduloHundred >= 11 && moduloHundred <= 99) return @"many";
    return @"other";
}

- (NSString *)pp_localizedCountPhraseWithPrefix:(NSString *)prefix
                                           count:(NSInteger)count
{
    NSString *category = [self pp_pluralCategoryForCount:count];
    NSString *key = [NSString stringWithFormat:@"%@_%@", prefix, category];
    NSString *localizedValue = kLang(key);
    BOOL includesNumber = [category isEqualToString:@"few"] ||
        [category isEqualToString:@"many"] ||
        [category isEqualToString:@"other"];
    return includesNumber
        ? [NSString stringWithFormat:localizedValue, (long)count]
        : localizedValue;
}

- (void)pp_updateInboxSummaryAnimated:(BOOL)animated {
    if (!self.inboxSummaryLabel) {
        return;
    }

    NSInteger threadCount = self.threads.count;
    NSInteger unreadCount = [self pp_totalUnreadCount];
    NSString *summary = nil;
    if (self.loadError && threadCount > 0) {
        summary = kLang(@"chat_inbox_stale_summary");
    } else if (threadCount == 0) {
        summary = kLang(@"empty_chats_subtitle");
    } else {
        NSString *conversationPhrase =
            [self pp_localizedCountPhraseWithPrefix:@"chat_inbox_conversation"
                                              count:threadCount];
        NSString *activityPhrase = unreadCount > 0
            ? [self pp_localizedCountPhraseWithPrefix:@"chat_inbox_unread"
                                                count:unreadCount]
            : kLang(@"chat_inbox_all_caught_up");
        summary = [NSString stringWithFormat:kLang(@"chat_inbox_summary_join_format"),
                   activityPhrase,
                   conversationPhrase];
    }

    UIColor *accentColor = [PPChatsFunc chatNeutralAccentColor];
    void (^changes)(void) = ^{
        self.inboxSummaryLabel.text = summary ?: @"";
        self.inboxAccentRailView.backgroundColor = unreadCount > 0
            ? accentColor
            : UIColor.tertiaryLabelColor;
        self.inboxAccentRailView.alpha = unreadCount > 0 ? 1.0 : 0.58;
        [self pp_layoutTableHeaderIfNeeded];
    };

    if (animated && self.view.window && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView transitionWithView:self.inboxSummaryLabel
                          duration:0.20
                           options:(UIViewAnimationOptionTransitionCrossDissolve |
                                    UIViewAnimationOptionBeginFromCurrentState)
                        animations:changes
                        completion:nil];
    } else {
        changes();
    }
}

- (void)pp_runHeaderEntranceIfNeeded {
    if (self.didRunHeaderEntrance || !self.inboxHeaderView) {
        return;
    }
    self.didRunHeaderEntrance = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.inboxHeaderView.transform = CGAffineTransformIdentity;
        self.composeButton.transform = CGAffineTransformIdentity;
        self.inboxAccentRailView.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.34
                          delay:0.02
                        options:(UIViewAnimationOptionCurveEaseOut |
                                 UIViewAnimationOptionBeginFromCurrentState |
                                 UIViewAnimationOptionAllowUserInteraction)
                     animations:^{
        self.inboxHeaderView.transform = CGAffineTransformIdentity;
        self.composeButton.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.38
                          delay:0.08
                        options:(UIViewAnimationOptionCurveEaseOut |
                                 UIViewAnimationOptionBeginFromCurrentState |
                                 UIViewAnimationOptionAllowUserInteraction)
                     animations:^{
        self.inboxAccentRailView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_scheduleListEntranceIfNeeded {
    if (self.didRunListEntrance || self.threads.count == 0 || !self.view.window) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.didRunListEntrance || self.threads.count == 0 || !self.view.window) {
            return;
        }
        [self.tableView layoutIfNeeded];
        NSArray<NSIndexPath *> *visibleRows =
            [self.tableView.indexPathsForVisibleRows sortedArrayUsingSelector:@selector(compare:)];
        if (visibleRows.count == 0) {
            return;
        }

        self.didRunListEntrance = YES;
        // PPExpandableChatCell handles its own entrance transitions
        // via SwiftUI .transition(); no ordinal-based entrance needed.
    });
}

#pragma mark - Data Helpers

- (ChatThreadModel *)pp_threadAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath || indexPath.section != 0) {
        return nil;
    }

    if (indexPath.row < 0 || indexPath.row >= (NSInteger)self.threads.count) {
        return nil;
    }

    id candidate = self.threads[indexPath.row];
    return [candidate isKindOfClass:ChatThreadModel.class] ? candidate : nil;
}

- (NSString *)pp_currentChatIdentity {
    NSString *authUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (authUID.length > 0) {
        return authUID;
    }

    return [UserManager sharedManager].currentUser.ID ?: @"";
}

- (BOOL)pp_hasAuthenticatedSession {
    return [FIRAuth auth].currentUser != nil ||
        [UserManager sharedManager].isUserLoggedIn;
}

- (NSDate *)pp_activityDateForThread:(ChatThreadModel *)thread {
    if (![thread isKindOfClass:ChatThreadModel.class]) {
        return NSDate.distantPast;
    }

    NSDate *lastMessageAt = thread.lastMessageAt;
    NSDate *timestamp = thread.timestamp;

    BOOL hasValidLast = lastMessageAt && ![lastMessageAt isEqual:NSDate.distantPast];
    BOOL hasValidTs   = timestamp && ![timestamp isEqual:NSDate.distantPast];

    if (hasValidLast && hasValidTs) {
        return ([lastMessageAt compare:timestamp] == NSOrderedAscending) ? timestamp : lastMessageAt;
    }
    if (hasValidLast) return lastMessageAt;
    if (hasValidTs)   return timestamp;

    return NSDate.date;
}

- (NSArray<ChatThreadModel *> *)pp_sortedVisibleThreads:(NSArray<ChatThreadModel *> *)threads {
    if (threads.count <= 1) {
        return threads ?: @[];
    }

    return [threads sortedArrayUsingComparator:^NSComparisonResult(ChatThreadModel *first, ChatThreadModel *second) {
        NSDate *firstDate = [self pp_activityDateForThread:first];
        NSDate *secondDate = [self pp_activityDateForThread:second];
        NSComparisonResult compare = [secondDate compare:firstDate];
        if (compare != NSOrderedSame) {
            return compare;
        }
        return [first.ID ?: @"" compare:second.ID ?: @""];
    }];
}

- (void)pp_updateEmptyState {
    BOOL showsInitialLoading = self.state == UserChatsStateLoading && self.threads.count == 0;
    if (showsInitialLoading) {
        [self.loadingIndicator startAnimating];
        [PPEmptyStateHelper updateEmptyStateForListView:(UICollectionView *)self.tableView
                                              dataCount:1
                                                 config:self.config];
        self.tableView.accessibilityValue = kLang(@"chat_inbox_loading");
        return;
    }

    [self.loadingIndicator stopAnimating];
    self.tableView.accessibilityValue = nil;

    if (self.state == UserChatsStateError) {
        self.config.animationName = @"404.json";
        self.config.isNetworkFile = NO;
        self.config.title = kLang(@"load_error_title");
        self.config.subTitle = kLang(@"chat_inbox_load_error_subtitle");
        self.config.buttonTitle = kLang(@"empty_retry_button");
        self.config.action = @selector(forceReloadThreads);
    } else if (![self pp_hasAuthenticatedSession]) {
        self.config.animationName = @"";
        self.config.isNetworkFile = NO;
        self.config.title = kLang(@"chat_sign_in_required_title");
        self.config.subTitle = kLang(@"chat_sign_in_required_subtitle");
        self.config.buttonTitle = kLang(@"chat_sign_in_action");
        self.config.action = @selector(startNewChat);
    } else {
        self.config.animationName = @"";
        self.config.isNetworkFile = NO;
        self.config.title = kLang(@"empty_chats_title");
        self.config.subTitle = kLang(@"empty_chats_subtitle");
        self.config.buttonTitle = kLang(@"empty_chats_button");
        self.config.action = @selector(startNewChat);
    }

    [PPEmptyStateHelper updateEmptyStateForListView:(UICollectionView *)self.tableView
                                          dataCount:self.threads.count
                                             config:self.config];
    [self pp_updateInboxSummaryAnimated:NO];
}

- (NSString *)pp_contentSignatureForThread:(ChatThreadModel *)thread {
    if (![thread isKindOfClass:ChatThreadModel.class]) {
        return @"";
    }

    UserModel *user = [ChatThreadModel resolveOtherUserFromThread:thread] ?: thread.otherUser;
    NSString *userID = user.ID ?: @"";
    NSString *avatar = user.UserImageUrl.absoluteString ?: @"";
    NSString *name = user.UserName ?: @"";
    NSDate *activityDate = [self pp_activityDateForThread:thread];
    NSTimeInterval ts = activityDate ? activityDate.timeIntervalSince1970 : 0.0;

    return [NSString stringWithFormat:@"%@|%@|%.0f|%ld|%@|%@|%@|%d",
            thread.ID ?: @"",
            thread.lastMessage ?: @"",
            ts,
            (long)thread.unreadCount,
            userID,
            name,
            avatar,
            user.isVerified ? 1 : 0];
}

- (void)pp_applyThreadsSnapshot:(NSArray<ChatThreadModel *> *)newThreads animated:(BOOL)animated {
    NSArray<ChatThreadModel *> *oldThreads = self.threads ?: @[];
    NSArray<ChatThreadModel *> *incoming = newThreads ?: @[];

    // Capture old identity/order + content signatures BEFORE swapping the
    // data source so we can tell whether anything actually changed.
    NSMutableArray<NSString *> *oldIDsOrdered = [NSMutableArray arrayWithCapacity:oldThreads.count];
    NSMutableDictionary<NSString *, NSString *> *oldSignatures =
        [NSMutableDictionary dictionaryWithCapacity:oldThreads.count];
    for (ChatThreadModel *t in oldThreads) {
        NSString *tid = t.ID ?: @"";
        [oldIDsOrdered addObject:tid];
        oldSignatures[tid] = [self pp_contentSignatureForThread:t];
    }

    NSMutableArray<NSString *> *newIDsOrdered = [NSMutableArray arrayWithCapacity:incoming.count];
    for (ChatThreadModel *t in incoming) {
        [newIDsOrdered addObject:(t.ID ?: @"")];
    }

    self.threads = incoming;
    [self pp_updateInboxSummaryAnimated:animated];

    // ─────────────────────────────────────────────────────────────
    // First load or empty → full reload (no diff needed)
    // ─────────────────────────────────────────────────────────────
    if (oldThreads.count == 0 || !self.tableView.window) {
        [self reloadTableAnimated];
        [self pp_scheduleListEntranceIfNeeded];
        return;
    }

    // ─────────────────────────────────────────────────────────────
    // Fast path: identity + order unchanged.
    // Reconfigure ONLY the rows whose content actually changed. This makes
    // returning from the messaging screen (nothing changed) a true no-op,
    // and keeps a quick-reply send from rebuilding the whole list. The row
    // that is currently expanded is never reconfigured, so its live composer
    // and send feedback are not torn down mid-interaction.
    // ─────────────────────────────────────────────────────────────
    if ([oldIDsOrdered isEqualToArray:newIDsOrdered]) {
        NSMutableArray<NSIndexPath *> *changedPaths = [NSMutableArray array];
        for (NSUInteger i = 0; i < incoming.count; i++) {
            ChatThreadModel *thread = incoming[i];
            NSString *tid = thread.ID ?: @"";
            NSString *newSig = [self pp_contentSignatureForThread:thread];
            if ([newSig isEqualToString:oldSignatures[tid]]) {
                continue; // unchanged → leave the existing cell untouched
            }
            if ([self.chatCellBridge isExpanded:tid]) {
                continue; // active expanded row manages its own live state
            }
            [changedPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
        }

        if (changedPaths.count == 0) {
            [self pp_scheduleListEntranceIfNeeded];
            return; // nothing to do — no reload, no animation
        }

        [UIView performWithoutAnimation:^{
            if (@available(iOS 15.0, *)) {
                [self.tableView reconfigureRowsAtIndexPaths:changedPaths];
            } else {
                [self.tableView reloadRowsAtIndexPaths:changedPaths
                                      withRowAnimation:UITableViewRowAnimationNone];
            }
        }];
        [self pp_scheduleListEntranceIfNeeded];
        return;
    }

    // ─────────────────────────────────────────────────────────────
    // Structural change: inserts / deletes / reordering.
    // A quick reply normally changes one conversation's activity date. Model
    // that as a real row move so the visible UIHostingConfiguration—and its
    // in-flight SwiftUI reply state—travels with the same conversation ID.
    if (oldIDsOrdered.count == newIDsOrdered.count && oldIDsOrdered.count > 0) {
        NSSet<NSString *> *oldIDSet = [NSSet setWithArray:oldIDsOrdered];
        NSSet<NSString *> *newIDSet = [NSSet setWithArray:newIDsOrdered];
        BOOL hasUniqueStableIDs = oldIDSet.count == oldIDsOrdered.count &&
                                  newIDSet.count == newIDsOrdered.count;

        if (hasUniqueStableIDs && [oldIDSet isEqualToSet:newIDSet]) {
            // The parent-thread update normally changes exactly one thread:
            // the sender of the quick reply. Prefer that identity when an
            // adjacent swap could be expressed as a move in either direction.
            NSMutableArray<NSString *> *changedThreadIDs = [NSMutableArray array];
            for (ChatThreadModel *thread in incoming) {
                NSString *threadID = thread.ID ?: @"";
                NSString *newSignature = [self pp_contentSignatureForThread:thread];
                if (![newSignature isEqualToString:oldSignatures[threadID]]) {
                    [changedThreadIDs addObject:threadID];
                }
            }

            NSUInteger moveFrom = NSNotFound;
            NSUInteger moveTo = NSNotFound;
            NSString *preferredThreadID = changedThreadIDs.count == 1
            ? changedThreadIDs.firstObject
            : nil;

            if (preferredThreadID.length > 0) {
                NSUInteger preferredSource = [oldIDsOrdered indexOfObject:preferredThreadID];
                NSUInteger preferredDestination = [newIDsOrdered indexOfObject:preferredThreadID];
                if (preferredSource != NSNotFound && preferredDestination != NSNotFound) {
                    NSMutableArray<NSString *> *candidateOrder = [oldIDsOrdered mutableCopy];
                    [candidateOrder removeObjectAtIndex:preferredSource];
                    [candidateOrder insertObject:preferredThreadID atIndex:preferredDestination];
                    if ([candidateOrder isEqualToArray:newIDsOrdered]) {
                        moveFrom = preferredSource;
                        moveTo = preferredDestination;
                    }
                }
            }

            // If multiple threads changed, find a single physical move that
            // still produces the observed order. The changed rows below are
            // refreshed by their own stable identity, never by source index.
            if (moveFrom == NSNotFound) {
                for (NSUInteger source = 0; source < oldIDsOrdered.count; source++) {
                    NSString *threadID = oldIDsOrdered[source];
                    NSMutableArray<NSString *> *candidateOrder = [oldIDsOrdered mutableCopy];
                    [candidateOrder removeObjectAtIndex:source];

                    for (NSUInteger destination = 0; destination <= candidateOrder.count; destination++) {
                        [candidateOrder insertObject:threadID atIndex:destination];
                        BOOL matchesIncomingOrder = [candidateOrder isEqualToArray:newIDsOrdered];
                        [candidateOrder removeObjectAtIndex:destination];

                        if (matchesIncomingOrder) {
                            moveFrom = source;
                            moveTo = destination;
                            break;
                        }
                    }

                    if (moveFrom != NSNotFound) {
                        break;
                    }
                }
            }

            if (moveFrom != NSNotFound && moveTo != NSNotFound && moveFrom != moveTo) {
                NSIndexPath *sourcePath = [NSIndexPath indexPathForRow:moveFrom inSection:0];
                NSIndexPath *destinationPath = [NSIndexPath indexPathForRow:moveTo inSection:0];
                NSMutableArray<NSIndexPath *> *changedPaths = [NSMutableArray array];
                for (NSString *threadID in changedThreadIDs) {
                    NSUInteger row = [newIDsOrdered indexOfObject:threadID];
                    if (row != NSNotFound) {
                        [changedPaths addObject:[NSIndexPath indexPathForRow:row inSection:0]];
                    }
                }
                if (changedPaths.count == 0) {
                    [changedPaths addObject:destinationPath];
                }

                [UIView performWithoutAnimation:^{
                    [self.tableView performBatchUpdates:^{
                        [self.tableView moveRowAtIndexPath:sourcePath toIndexPath:destinationPath];
                    } completion:^(__unused BOOL finished) {
                        // Reconfigure only the identities whose content changed
                        // after their cells have moved into their final rows.
                        [UIView performWithoutAnimation:^{
                            if (@available(iOS 15.0, *)) {
                                [self.tableView reconfigureRowsAtIndexPaths:changedPaths];
                            } else {
                                [self.tableView reloadRowsAtIndexPaths:changedPaths
                                                     withRowAnimation:UITableViewRowAnimationNone];
                            }
                        }];
                    }];
                }];

                [self pp_scheduleListEntranceIfNeeded];
                return;
            }

            // A complex pure reorder cannot be safely represented by
            // reconfiguring rows in place: that would bind a hosted cell's
            // @State to a different conversation. Reload without animation
            // rather than displaying mismatched or reflected cell content.
            [UIView performWithoutAnimation:^{
                [self.tableView reloadData];
                [self.tableView layoutIfNeeded];
            }];
            [self pp_scheduleListEntranceIfNeeded];
            return;
        }
    }

    // Insertions/deletions are safe to batch only when the conversations that
    // remain keep their relative order. Otherwise use the non-animated safe
    // fallback above instead of rebinding UIHostingConfiguration state.
    NSMutableOrderedSet<NSString *> *oldIDs = [NSMutableOrderedSet orderedSetWithArray:oldIDsOrdered];
    NSMutableOrderedSet<NSString *> *newIDs = [NSMutableOrderedSet orderedSetWithArray:newIDsOrdered];
    if (oldIDs.count != oldIDsOrdered.count || newIDs.count != newIDsOrdered.count) {
        [UIView performWithoutAnimation:^{
            [self.tableView reloadData];
            [self.tableView layoutIfNeeded];
        }];
        [self pp_scheduleListEntranceIfNeeded];
        return;
    }

    NSMutableArray<NSString *> *oldSharedIDs = [NSMutableArray array];
    NSMutableArray<NSString *> *newSharedIDs = [NSMutableArray array];
    for (NSString *threadID in oldIDsOrdered) {
        if ([newIDs containsObject:threadID]) {
            [oldSharedIDs addObject:threadID];
        }
    }
    for (NSString *threadID in newIDsOrdered) {
        if ([oldIDs containsObject:threadID]) {
            [newSharedIDs addObject:threadID];
        }
    }
    if (![oldSharedIDs isEqualToArray:newSharedIDs]) {
        [UIView performWithoutAnimation:^{
            [self.tableView reloadData];
            [self.tableView layoutIfNeeded];
        }];
        [self pp_scheduleListEntranceIfNeeded];
        return;
    }

    NSMutableArray<NSIndexPath *> *deletePaths = [NSMutableArray array];
    NSMutableArray<NSIndexPath *> *insertPaths = [NSMutableArray array];
    NSMutableArray<NSIndexPath *> *reconfigurePaths = [NSMutableArray array];

    // Deleted rows: in old but not in new
    for (NSUInteger i = 0; i < oldIDs.count; i++) {
        if (![newIDs containsObject:oldIDs[i]]) {
            [deletePaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
        }
    }

    // Inserted rows: in new but not in old
    for (NSUInteger i = 0; i < newIDs.count; i++) {
        if (![oldIDs containsObject:newIDs[i]]) {
            [insertPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
        }
    }

    // If the diff is too complex (large structural change), fall back to full reload.
    if (deletePaths.count + insertPaths.count > oldIDs.count) {
        [self reloadTableAnimated];
        [self pp_scheduleListEntranceIfNeeded];
        return;
    }

    // Rows that exist in both can refresh in place because their relative
    // identity/order is unchanged in this path.
    for (NSUInteger i = 0; i < newIDs.count; i++) {
        if ([oldIDs containsObject:newIDs[i]]) {
            [reconfigurePaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
        }
    }

    [UIView performWithoutAnimation:^{
        [self.tableView performBatchUpdates:^{
            if (deletePaths.count > 0) {
                [self.tableView deleteRowsAtIndexPaths:deletePaths
                                     withRowAnimation:UITableViewRowAnimationNone];
            }
            if (insertPaths.count > 0) {
                [self.tableView insertRowsAtIndexPaths:insertPaths
                                     withRowAnimation:UITableViewRowAnimationNone];
            }
        } completion:^(__unused BOOL finished) {
            // Reconfigure existing rows to update content without full reload.
            // Their identity has not changed, so no SwiftUI host is rebound to
            // a different conversation while a reply is in progress.
            if (reconfigurePaths.count > 0) {
                if (@available(iOS 15.0, *)) {
                    [self.tableView reconfigureRowsAtIndexPaths:reconfigurePaths];
                } else {
                    [self.tableView reloadRowsAtIndexPaths:reconfigurePaths
                                         withRowAnimation:UITableViewRowAnimationNone];
                }
            }
        }];
    }];

    [self pp_scheduleListEntranceIfNeeded];
}

- (NSString *)pp_otherUserIDForThread:(ChatThreadModel *)thread {
    if (![thread isKindOfClass:ChatThreadModel.class]) {
        return @"";
    }

    NSString *currentUserID = [self pp_currentChatIdentity];
    for (NSString *candidate in thread.memberIDs) {
        if (![candidate isKindOfClass:NSString.class]) {
            continue;
        }

        if (candidate.length > 0 && ![candidate isEqualToString:currentUserID]) {
            return candidate;
        }
    }

    return @"";
}

- (NSArray<NSString *> *)pp_avatarURLsForIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    NSMutableOrderedSet<NSString *> *orderedURLs = [NSMutableOrderedSet orderedSet];

    for (NSIndexPath *indexPath in indexPaths) {
        ChatThreadModel *thread = [self pp_threadAtIndexPath:indexPath];
        UserModel *user = [ChatThreadModel resolveOtherUserFromThread:thread] ?: thread.otherUser;
        NSString *avatarURL = user.UserImageUrl.absoluteString ?: @"";
        if (avatarURL.length > 0) {
            [orderedURLs addObject:avatarURL];
        }
    }

    return orderedURLs.array;
}

#pragma mark - Observing

- (void)startObservingChats {
    if (self.isObserving) {
        return;
    }

    NSString *currentUserID = [self pp_currentChatIdentity];
    BOOL hasAuthenticatedSession = [self pp_hasAuthenticatedSession];
    if (currentUserID.length == 0 || !hasAuthenticatedSession) {
        self.isLoading = NO;
        self.state = UserChatsStateEmpty;
        self.loadError = nil;
        self.observedChatIdentity = nil;
        self.threads = @[];
        self.didRunListEntrance = NO;
        [self.animatedThreadIDs removeAllObjects];
        [self reloadTableAnimated];
        [self pp_updateEmptyState];
        return;
    }

    if (self.observedChatIdentity.length > 0 &&
        ![self.observedChatIdentity isEqualToString:currentUserID]) {
        self.threads = @[];
        self.didRunListEntrance = NO;
        [self.animatedThreadIDs removeAllObjects];
        [self reloadTableAnimated];
    }

    self.isObserving = YES;
    self.isLoading = YES;
    self.observedChatIdentity = currentUserID;
    self.loadError = nil;
    self.state = self.threads.count > 0 ? UserChatsStateLoaded : UserChatsStateLoading;
    [self pp_updateEmptyState];

    __weak typeof(self) weakSelf = self;
    self.threadsListener =
    [[ChManager sharedManager] observeChatThreadsWithUnreadCountsForUserID:currentUserID
                                                                completion:^(NSArray<ChatThreadModel *> *threads, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            NSString *liveIdentity = [self pp_currentChatIdentity];
            if (!self.isObserving ||
                ![self.observedChatIdentity isEqualToString:currentUserID] ||
                ![liveIdentity isEqualToString:currentUserID]) {
                if (![liveIdentity isEqualToString:currentUserID]) {
                    [self stopObservingChats];
                    self.threads = @[];
                    self.loadError = nil;
                    self.state = UserChatsStateEmpty;
                    [self reloadTableAnimated];
                    [self pp_updateEmptyState];
                }
                return;
            }

            [self pp_handleObservedThreads:threads error:error];
        });
    }];
}

- (void)stopObservingChats {
    [self.threadsListener remove];
    self.threadsListener = nil;
    self.isObserving = NO;
}

- (void)forceReloadThreads {
    [self stopObservingChats];
    self.loadError = nil;
    [self startObservingChats];
}

- (void)pp_handleObservedThreads:(NSArray<ChatThreadModel *> *)threads
                           error:(NSError *)error
{
    if (self.isPerformingLocalMutation) {
        self.isPerformingLocalMutation = NO;
        return;
    }

    self.isLoading = NO;

    if (error) {
        BOOL hasAuthenticatedSession = [self pp_hasAuthenticatedSession];
        if (!hasAuthenticatedSession) {
            self.threads = @[];
            self.observedChatIdentity = nil;
            self.loadError = nil;
            self.state = UserChatsStateEmpty;
            [self reloadTableAnimated];
            [self pp_updateEmptyState];
            return;
        }
        self.loadError = error;
        self.state = self.threads.count > 0 ? UserChatsStateLoaded : UserChatsStateError;
        if (self.threads.count > 0) {
            [PPHUD showError:kLang(@"chat_inbox_stale_summary")];
            [self pp_updateInboxSummaryAnimated:YES];
        }
        [self pp_updateEmptyState];
        return;
    }

    NSMutableArray<ChatThreadModel *> *visibleThreads = [NSMutableArray array];
    for (ChatThreadModel *thread in threads) {
        if (thread.isBinned) {
            continue;
        }
        [visibleThreads addObject:thread];
    }

    NSArray<ChatThreadModel *> *sortedThreads = [self pp_sortedVisibleThreads:visibleThreads.copy];
    self.loadError = nil;
    self.state = sortedThreads.count > 0 ? UserChatsStateLoaded : UserChatsStateEmpty;
    [self pp_applyThreadsSnapshot:sortedThreads animated:YES];
    [self pp_resolveMissingOtherUsersForThreads:self.threads];
    [self startObservingOnlineStatus];
    [self pp_updateEmptyState];
    [self pp_scheduleListEntranceIfNeeded];
}

- (void)pp_resolveMissingOtherUsersForThreads:(NSArray<ChatThreadModel *> *)threads {
    for (ChatThreadModel *thread in threads) {
        UserModel *resolvedUser = [ChatThreadModel resolveOtherUserFromThread:thread];
        if (resolvedUser.ID.length > 0) {
            thread.otherUser = resolvedUser;
            continue;
        }

        NSString *otherUserID = [self pp_otherUserIDForThread:thread];
        if (otherUserID.length == 0 || [self.resolvingOtherUserIDs containsObject:otherUserID]) {
            continue;
        }

        [self.resolvingOtherUserIDs addObject:otherUserID];

        __weak typeof(self) weakSelf = self;
        [UsrMgr getOtherUserModelFromFirestoreWithUID:otherUserID completion:^(UserModel *user, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) {
                    return;
                }

                [self.resolvingOtherUserIDs removeObject:otherUserID];
                if (error || !user) {
                    return;
                }

                NSMutableArray<NSIndexPath *> *reloadPaths = [NSMutableArray array];
                for (NSInteger row = 0; row < self.threads.count; row++) {
                    ChatThreadModel *model = self.threads[row];
                    NSString *modelOtherUserID = [self pp_otherUserIDForThread:model];
                    if ([modelOtherUserID isEqualToString:otherUserID]) {
                        model.otherUser = user;
                        [reloadPaths addObject:[NSIndexPath indexPathForRow:row inSection:0]];
                    }
                }

                if (reloadPaths.count == 0) {
                    return;
                }

                [UIView performWithoutAnimation:^{
                    [self.tableView reloadRowsAtIndexPaths:reloadPaths
                                          withRowAnimation:UITableViewRowAnimationNone];
                }];
                [self startObservingOnlineStatus];
            });
        }];
    }
}

- (void)startObservingOnlineStatus {
    NSMutableOrderedSet<NSString *> *userIDsSet = [NSMutableOrderedSet orderedSet];
    for (ChatThreadModel *thread in self.threads) {
        UserModel *user = [ChatThreadModel resolveOtherUserFromThread:thread] ?: thread.otherUser;
        if (user.ID.length > 0) {
            [userIDsSet addObject:user.ID];
        }
    }

    NSArray<NSString *> *userIDs = userIDsSet.array;
    if (userIDs.count == 0) {
        if (self.presenceToken) {
            [[ChatPresenceManager shared] removePresenceObserver:self.presenceToken];
            self.presenceToken = nil;
        }
        return;
    }

    [[ChatPresenceManager shared] startObservingUsers:userIDs];

    if (self.presenceToken) {
        [self pp_refreshVisiblePresenceState];
        return;
    }

    __weak typeof(self) weakSelf = self;
    self.presenceToken =
    [[ChatPresenceManager shared] addPresenceObserver:^(NSString *userID) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        [self pp_applyPresenceUpdateForUserID:userID];
    }];
}

- (void)pp_refreshVisiblePresenceState {
    NSArray<NSIndexPath *> *visibleRows = self.tableView.indexPathsForVisibleRows ?: @[];
    for (NSIndexPath *indexPath in visibleRows) {
        ChatThreadModel *thread = [self pp_threadAtIndexPath:indexPath];
        UserModel *user = [ChatThreadModel resolveOtherUserFromThread:thread] ?: thread.otherUser;
        if (user.ID.length == 0) {
            continue;
        }

        BOOL online = [[ChatPresenceManager shared] isUserOnline:user.ID];
        NSDate *lastSeen = [[ChatPresenceManager shared] lastSeenForUser:user.ID];
        user.isOnline = online;
        user.lastSeen = lastSeen;

        // PPExpandableChatCell reads presence from the snapshot at
        // configure time.  Reload the row to pick up new state.
        [self.tableView reloadRowsAtIndexPaths:@[indexPath]
                              withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (void)pp_applyPresenceUpdateForUserID:(NSString *)userID {
    NSInteger row = [self indexForThreadWithUserID:userID];
    if (row == NSNotFound) {
        return;
    }

    ChatThreadModel *thread = self.threads[row];
    UserModel *user = [ChatThreadModel resolveOtherUserFromThread:thread] ?: thread.otherUser;
    BOOL online = [[ChatPresenceManager shared] isUserOnline:userID];
    NSDate *lastSeen = [[ChatPresenceManager shared] lastSeenForUser:userID];
    user.isOnline = online;
    user.lastSeen = lastSeen;
    thread.otherUser = user;

    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
    // PPExpandableChatCell reads presence from the snapshot at
    // configure time.  Reload the row to pick up new state.
    [self.tableView reloadRowsAtIndexPaths:@[indexPath]
                          withRowAnimation:UITableViewRowAnimationNone];
}

- (NSInteger)indexForThreadWithUserID:(NSString *)uid {
    for (NSInteger row = 0; row < self.threads.count; row++) {
        ChatThreadModel *thread = self.threads[row];
        UserModel *user = [ChatThreadModel resolveOtherUserFromThread:thread] ?: thread.otherUser;
        if ([user.ID isEqualToString:uid]) {
            return row;
        }
    }
    return NSNotFound;
}

#pragma mark - Notifications

- (void)handleUnreadUpdate {
    NSDictionary<NSString *, NSNumber *> *liveUnreadCounts = [ChManager sharedManager].liveUnreadCounts ?: @{};
    NSDictionary<NSString *, ChatMessageModel *> *latestUnreadMessages = [ChManager sharedManager].latestUnreadMessages ?: @{};
    
    if (self.threads.count == 0) {
        return;
    }

    BOOL anyChanges = NO;
    NSMutableArray<NSIndexPath *> *reloadPaths = [NSMutableArray array];
    for (NSInteger row = 0; row < self.threads.count; row++) {
        ChatThreadModel *thread = self.threads[row];
        NSInteger newCount = liveUnreadCounts[thread.ID].integerValue;
        
        ChatMessageModel *latestMsg = latestUnreadMessages[thread.ID];
        BOOL messageUpdated = NO;
        if (latestMsg) {
            NSString *lastMessageText = @"";
            if (latestMsg.isDeleted) {
                lastMessageText = kLang(@"chat_message_unsent");
            } else if (latestMsg.isTextMessage) {
                lastMessageText = latestMsg.text ?: @"";
            } else if (latestMsg.isAudioMessage) {
                lastMessageText = kLang(@"Audio message");
            } else if (latestMsg.isImageMessage) {
                lastMessageText = kLang(@"Image");
            } else if (latestMsg.isVideoMessage) {
                lastMessageText = kLang(@"Video");
            } else if (latestMsg.isFileMessage) {
                lastMessageText = kLang(@"File");
            }
            
            // Normalize preview text
            lastMessageText = [lastMessageText stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
            lastMessageText = [lastMessageText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (lastMessageText.length == 0) {
                lastMessageText = kLang(@"NewMessage");
            }
            
            if (![thread.lastMessage isEqualToString:lastMessageText]) {
                thread.lastMessage = lastMessageText;
                thread.lastMessageAt = latestMsg.timestamp;
                messageUpdated = YES;
            }
        }
        
        if (thread.unreadCount != newCount || messageUpdated) {
            thread.unreadCount = newCount;
            anyChanges = YES;
            [reloadPaths addObject:[NSIndexPath indexPathForRow:row inSection:0]];
        }
    }

    if (!anyChanges) {
        return;
    }

    // Sort and apply the snapshot so the order is updated if a new message has arrived
    NSArray<ChatThreadModel *> *sortedThreads = [self pp_sortedVisibleThreads:self.threads];
    [self pp_applyThreadsSnapshot:sortedThreads animated:YES];
    [self pp_updateInboxSummaryAnimated:YES];
}

#pragma mark - Table Refresh

- (void)reloadTableAnimated {
    [UIView performWithoutAnimation:^{
        [self.tableView reloadData];
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.threads.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:PPChatCellBridge.reuseID forIndexPath:indexPath];
    ChatThreadModel *thread = [self pp_threadAtIndexPath:indexPath];
    if (thread) {
        __weak typeof(self) weakSelf = self;
        [self.chatCellBridge configureCell:cell
                                     with:thread
                               onOpenChat:^(ChatThreadModel * _Nonnull chatThread) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self pp_openMessagingThread:chatThread];
        }];
    }
    return cell;
}

#pragma mark - UITableViewDelegate

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
{
    __weak typeof(self) weakSelf = self;
    UIContextualAction *deleteAction =
    [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                            title:kLang(@"Delete")
                                          handler:^(__unused UIContextualAction *action,
                                                    __unused UIView *sourceView,
                                                    void (^completionHandler)(BOOL)) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            completionHandler(NO);
            return;
        }

        completionHandler(NO);
        [self pp_presentDeleteConfirmationAtIndexPath:indexPath];
    }];
    deleteAction.backgroundColor = UIColor.systemRedColor;

    UISwipeActionsConfiguration *configuration =
    [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
    configuration.performsFirstActionWithFullSwipe = NO;
    return configuration;
}

- (void)pp_presentDeleteConfirmationAtIndexPath:(NSIndexPath *)indexPath {
    ChatThreadModel *thread = [self pp_threadAtIndexPath:indexPath];
    if (!thread) {
        return;
    }

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:kLang(@"chat_delete_thread_title")
                                            message:kLang(@"chat_delete_thread_message")
                                     preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel")
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Delete")
                                             style:UIAlertActionStyleDestructive
                                           handler:^(__unused UIAlertAction *action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        NSIndexPath *currentIndexPath = [self indexPathForChat:thread];
        if (currentIndexPath) {
            [self pp_deleteThreadAtIndexPath:currentIndexPath
                                  completion:^(__unused BOOL finished) {}];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)pp_deleteThreadAtIndexPath:(NSIndexPath *)indexPath
                        completion:(void (^)(BOOL finished))completion
{
    ChatThreadModel *thread = [self pp_threadAtIndexPath:indexPath];
    if (!thread) {
        completion(NO);
        return;
    }

    self.isPerformingLocalMutation = YES;

    NSMutableArray<ChatThreadModel *> *mutableThreads = [self.threads mutableCopy];
    [mutableThreads removeObjectAtIndex:indexPath.row];
    self.threads = mutableThreads.copy;

    [self.tableView performBatchUpdates:^{
        [self.tableView deleteRowsAtIndexPaths:@[indexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
    } completion:^(__unused BOOL finished) {
        self.state = self.threads.count > 0 ? UserChatsStateLoaded : UserChatsStateEmpty;
        [self pp_updateEmptyState];
        [self pp_updateInboxSummaryAnimated:YES];
    }];

    __weak typeof(self) weakSelf = self;
    [[ChManager sharedManager] deleteChatThreadWithID:thread.ID
                                           completion:^(NSError *error) {
        if (!error) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            self.isPerformingLocalMutation = NO;
            BOOL alreadyRestored = [self.threads indexOfObjectPassingTest:
                ^BOOL(ChatThreadModel *candidate, __unused NSUInteger idx, __unused BOOL *stop) {
                    return [candidate.ID isEqualToString:thread.ID];
                }] != NSNotFound;
            if (!alreadyRestored) {
                NSMutableArray<ChatThreadModel *> *restoredThreads = [self.threads mutableCopy];
                [restoredThreads addObject:thread];
                self.threads = [self pp_sortedVisibleThreads:restoredThreads.copy];
                self.state = UserChatsStateLoaded;
                [self reloadTableAnimated];
                [self pp_updateEmptyState];
                [self pp_updateInboxSummaryAnimated:YES];
            }
            [PPHUD showError:kLang(@"chat_delete_thread_failed")];
        });
    }];

    completion(YES);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    ChatThreadModel *thread = [self pp_threadAtIndexPath:indexPath];
    if (!thread) {
        [self reloadTableAnimated];
        return;
    }

    [self pp_openMessagingThread:thread];
}

- (void)tableView:(UITableView *)tableView prefetchRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    NSArray<NSString *> *avatarURLs = [self pp_avatarURLsForIndexPaths:indexPaths];
    if (avatarURLs.count == 0) {
        return;
    }

    [[PPImageLoaderManager shared] prefetchURLs:avatarURLs];
}

#pragma mark - Selection / Navigation

- (void)selectUser:(UserModel *)selectedUserClass vcName:(NSString *)vcName {
    (void)vcName;

    [[ChManager sharedManager] createOrGetChatThreadWithUser:selectedUserClass
                                                  completion:^(ChatThreadModel *chatThread, NSError *error) {
        if (error) {
            [PPHUD dismiss];
            return;
        }

        [PPHUD dismiss];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (!chatThread) {
                return;
            }

            chatThread.otherUser = selectedUserClass;

            UIViewController *presented = self.presentedViewController;
            if (presented) {
                if (presented.isBeingDismissed) {
                    // Picker is already dismissing itself — wait for the
                    // transition to finish, then open the chat.
                    id<UIViewControllerTransitionCoordinator> tc = self.transitionCoordinator;
                    if (tc) {
                        [tc animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> _Nonnull context) {
                            [self openChatWithThread:chatThread];
                        }];
                    } else {
                        // Fallback: transition coordinator already nil — safe to open now
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            [self openChatWithThread:chatThread];
                        });
                    }
                } else {
                    [self dismissViewControllerAnimated:YES completion:^{
                        [self openChatWithThread:chatThread];
                    }];
                }
                return;
            }

            [self openChatWithThread:chatThread];
        });
    }];
}

- (void)openChatWithThread:(ChatThreadModel *)thread {
    if (!thread) {
        return;
    }

    [self pp_openMessagingThread:thread];
}

- (void)pp_openMessagingThread:(ChatThreadModel *)thread {
    if (!thread) {
        return;
    }

    [self.chatCellBridge collapseExpanded];
    [PPOverlayCoordinator pp_openChatThread:thread
                               petAdContext:nil
                                     fromVC:self];
}

- (void)pp_dismissPresentedStartChatPicker {
    [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)startNewChat {
    if (![self pp_hasAuthenticatedSession]) {
        [UserManager showPromptOnTopController];
        return;
    }

    NSString *currentUID = [self pp_currentChatIdentity];
    NSArray<UserModel *> *options =
    [AppMgr.usersArray filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(UserModel *user, __unused NSDictionary *bindings) {
        return ![user.ID isEqualToString:currentUID];
    }]];

    __weak typeof(self) weakSelf = self;
    PPSelectOptionViewController *picker =
    [[PPSelectOptionViewController alloc] initWithCompletion:^(id selected) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || ![selected isKindOfClass:UserModel.class]) {
            return;
        }

        self.selectedUser = selected;
        [self selectUser:selected vcName:@"chats"];
    }];

    picker.allOptions = options;
    picker.filteredOptions = options;
    picker.parentForm = self;
    picker.imageLoaded = NO;
    picker.presentationStyle = PPSelectOptionPresentationSheet;
    picker.title = kLang(@"Select User");
    picker.view.backgroundColor = UIColor.systemBackgroundColor;
    picker.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    UIBarButtonItem *cancelItem =
    [[UIBarButtonItem alloc] initWithTitle:kLang(@"Cancel")
                                     style:UIBarButtonItemStylePlain
                                    target:self
                                    action:@selector(pp_dismissPresentedStartChatPicker)];
    [cancelItem setTitleTextAttributes:@{NSFontAttributeName: [Styling fontMedium:16]} forState:UIControlStateNormal];
    [cancelItem setTitleTextAttributes:@{NSFontAttributeName: [Styling fontMedium:16]} forState:UIControlStateHighlighted];
    picker.navigationItem.leftBarButtonItem = cancelItem;

    UINavigationController *navigationController =
    [[UINavigationController alloc] initWithRootViewController:picker];
    navigationController.modalPresentationStyle = UIModalPresentationPageSheet;
    navigationController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    navigationController.modalPresentationCapturesStatusBarAppearance = YES;
    navigationController.modalInPresentation = NO;
    navigationController.view.backgroundColor = UIColor.systemBackgroundColor;
    navigationController.navigationBar.tintColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    self.modalInPresentation = NO;
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithDefaultBackground];
        appearance.backgroundColor = UIColor.systemBackgroundColor;
        appearance.shadowColor = UIColor.clearColor;
        navigationController.navigationBar.standardAppearance = appearance;
        navigationController.navigationBar.scrollEdgeAppearance = appearance;
    }

    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = navigationController.sheetPresentationController;
        sheet.detents = @[
            [UISheetPresentationControllerDetent mediumDetent],
            [UISheetPresentationControllerDetent largeDetent]
        ];
        sheet.prefersGrabberVisible = YES;
        sheet.preferredCornerRadius = 28.0;
        sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
    }

    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)chat:(ChatThreadModel *)chat didUpdateOnlineStatus:(OnlineStatus)status {
    (void)status;

    NSIndexPath *indexPath = [self indexPathForChat:chat];
    if (!indexPath) {
        return;
    }

    [self.tableView reloadRowsAtIndexPaths:@[indexPath]
                          withRowAnimation:UITableViewRowAnimationNone];
}

- (NSIndexPath *)indexPathForChat:(ChatThreadModel *)chat {
    NSUInteger row = [self.threads indexOfObjectPassingTest:^BOOL(ChatThreadModel *candidate, NSUInteger idx, BOOL *stop) {
        (void)idx;
        return [candidate.ID isEqualToString:chat.ID];
    }];

    if (row == NSNotFound) {
        return nil;
    }

    return [NSIndexPath indexPathForRow:row inSection:0];
}

- (void)startChatWith:(UserModel *)user {
    [[ChManager sharedManager] createOrGetChatThreadWithUser:user
                                                  completion:^(ChatThreadModel *thread, NSError *error) {
        if (error || !thread) {
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_openMessagingThread:thread];
        });
    }];
}

- (void)updateThreadAtindexPath:(NSIndexPath *)indexPath withOtherUserImage:(UIImage *)otherImage {
    (void)indexPath;
    (void)otherImage;
}

@end
