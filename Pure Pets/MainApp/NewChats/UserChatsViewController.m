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
#import "PPSelectOptionViewController.h"
#import "PPStoriesViewController.h"

#import <FirebaseAuth/FirebaseAuth.h>
#import <UIKit/UIKit.h>

static const CGFloat PPChatStoriesHeaderHiddenHeight = 8.0;
static const CGFloat PPChatStoriesHeaderVisibleHeight = 208.0;
static const CGFloat PPChatListContentTopInset = 10.0;
static const CGFloat PPChatListContentBottomInset = 128.0;
static const CGFloat PPChatListEstimatedRowHeight = 84.0;

@interface UserChatsViewController ()
<UITableViewDelegate, UITableViewDataSource, UITableViewDataSourcePrefetching>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<ChatThreadModel *> *threads;
@property (nonatomic, strong) id<FIRListenerRegistration> threadsListener;
@property (nonatomic, strong) id presenceToken;
@property (nonatomic, strong) PPEmptyStateConfig *config;
@property (nonatomic, strong) UIView *storiesHeaderContainer;
@property (nonatomic, strong) PPStoriesViewController *storiesViewController;
@property (nonatomic, strong) NSMutableSet<NSString *> *resolvingOtherUserIDs;
@property (nonatomic, assign) BOOL storiesHeaderVisible;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL isObserving;
@property (nonatomic, assign) BOOL isPerformingLocalMutation;

@end

@implementation UserChatsViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.threads = @[];
    self.isLoading = YES;
    self.resolvingOtherUserIDs = [NSMutableSet set];

    [self pp_configureAppearance];
    [self pp_configureTableView];
    [self pp_configureStoriesHeader];
    [self pp_configureEmptyState];
    [self pp_registerNotifications];
    [self pp_updateEmptyState];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self startObservingChats];
    [self.storiesViewController startObservingStories];
    [self handleUnreadUpdate];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startObservingOnlineStatus];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    if (self.storiesHeaderContainer) {
        CGFloat height = self.storiesHeaderVisible ? PPChatStoriesHeaderVisibleHeight : PPChatStoriesHeaderHiddenHeight;
        [self pp_applyStoriesHeaderHeight:height];
    }
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
}

#pragma mark - Setup

- (void)pp_configureAppearance {
    self.view.backgroundColor = AppBackgroundClr ;// PPBackgroundColorForIOS26(AppBackgroundClr);
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
    [self.tableView registerClass:ChCell.class forCellReuseIdentifier:ChCell.reuseID];

    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }

    [self pp_setupBackgroundGlows];
    [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)pp_setupBackgroundGlows {
    UIView *glow1 = [UIView new];
    glow1.translatesAutoresizingMaskIntoConstraints = NO;
    glow1.backgroundColor = [bageColor colorWithAlphaComponent:0.05];
    glow1.layer.cornerRadius = 88.0;
    glow1.clipsToBounds = YES;
    [self.view addSubview:glow1];

    UIView *glow2 = [UIView new];
    glow2.translatesAutoresizingMaskIntoConstraints = NO;
    glow2.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.018];
    glow2.layer.cornerRadius = 110.0;
    glow2.clipsToBounds = YES;
    [self.view addSubview:glow2];

    UIView *glow3 = [UIView new];
    glow3.translatesAutoresizingMaskIntoConstraints = NO;
    glow3.backgroundColor = [UIColor.systemOrangeColor colorWithAlphaComponent:0.024];
    glow3.layer.cornerRadius = 80.0;
    glow3.clipsToBounds = YES;
    [self.view addSubview:glow3];

    UIBlurEffect *blurEffect;
    if (@available(iOS 13.0, *)) {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    } else {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.alpha = 0.4;
    [self.view addSubview:blurView];

    [NSLayoutConstraint activateConstraints:@[
        [glow1.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18.0],
        [glow1.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:24.0],
        [glow1.widthAnchor constraintEqualToConstant:176.0],
        [glow1.heightAnchor constraintEqualToConstant:176.0],

        [glow2.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],
        [glow2.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-32.0],
        [glow2.widthAnchor constraintEqualToConstant:220.0],
        [glow2.heightAnchor constraintEqualToConstant:220.0],

        [glow3.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:28.0],
        [glow3.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-152.0],
        [glow3.widthAnchor constraintEqualToConstant:160.0],
        [glow3.heightAnchor constraintEqualToConstant:160.0],

        [blurView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
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

    self.storiesHeaderContainer =
    [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, width, PPChatStoriesHeaderHiddenHeight)];
    self.storiesHeaderContainer.backgroundColor = UIColor.clearColor;
    self.storiesHeaderContainer.clipsToBounds = NO;
    self.storiesHeaderContainer.layer.cornerRadius = 22;
    if (@available(iOS 13.0, *)) {
        self.storiesHeaderContainer.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.tableView.tableHeaderView = self.storiesHeaderContainer;

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
    self.config.animationName = @"chats2.json";
    self.config.isNetworkFile = YES;
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
                                             selector:@selector(forceReloadThreads)
                                                 name:@"forceReloadThreads"
                                               object:nil];
}

#pragma mark - Stories Header

- (void)pp_setStoriesHeaderVisible:(BOOL)visible animated:(BOOL)animated {
    if (self.shouldHideStories) {
        return;
    }
    if (self.storiesHeaderVisible == visible && self.storiesViewController.view.hidden == !visible) {
        return;
    }

    self.storiesHeaderVisible = visible;
    CGFloat targetHeight = visible ? PPChatStoriesHeaderVisibleHeight : PPChatStoriesHeaderHiddenHeight;

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

    CGFloat width = CGRectGetWidth(self.tableView.bounds);
    if (width <= 0.0) {
        width = CGRectGetWidth(self.view.bounds);
    }
    if (width <= 0.0) {
        width = UIScreen.mainScreen.bounds.size.width;
    }

    CGRect frame = self.storiesHeaderContainer.frame;
    BOOL sizeChanged = fabs(frame.size.height - height) > 0.5 || fabs(frame.size.width - width) > 0.5;
    if (!sizeChanged) {
        return;
    }

    frame.origin = CGPointZero;
    frame.size = CGSizeMake(width, height);
    self.storiesHeaderContainer.frame = frame;
    self.tableView.tableHeaderView = self.storiesHeaderContainer;
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

- (NSDate *)pp_activityDateForThread:(ChatThreadModel *)thread {
    if (![thread isKindOfClass:ChatThreadModel.class]) {
        return NSDate.distantPast;
    }

    NSDate *lastMessageAt = thread.lastMessageAt;
    NSDate *timestamp = thread.timestamp;
    if (lastMessageAt && timestamp) {
        return ([lastMessageAt compare:timestamp] == NSOrderedAscending) ? timestamp : lastMessageAt;
    }

    return lastMessageAt ?: (timestamp ?: NSDate.distantPast);
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
    [PPEmptyStateHelper updateEmptyStateForListView:(UICollectionView *)self.tableView
                                          dataCount:self.threads.count
                                             config:self.config];
}

- (void)pp_animatePromotedTopThreadCell {
    if (self.threads.count == 0) {
        return;
    }

    NSIndexPath *topIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:topIndexPath];
    if (!cell) {
        return;
    }

    cell.transform = CGAffineTransformMakeTranslation(0.0, -10.0);
    cell.alpha = 0.88;

    [UIView animateWithDuration:0.40
                          delay:0.0
         usingSpringWithDamping:0.80
          initialSpringVelocity:0.88
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        cell.transform = CGAffineTransformIdentity;
        cell.alpha = 1.0;
    } completion:nil];
}

- (void)pp_applyThreadsSnapshot:(NSArray<ChatThreadModel *> *)newThreads animated:(BOOL)animated {
    NSArray<ChatThreadModel *> *previousThreads = self.threads ?: @[];
    NSString *previousTopThreadID = previousThreads.firstObject.ID ?: @"";

    self.threads = newThreads ?: @[];

    if (!animated || previousThreads.count == 0 || self.threads.count == 0) {
        [self reloadTableAnimated];
        return;
    }

    NSString *newTopThreadID = self.threads.firstObject.ID ?: @"";
    BOOL promotedThreadChanged = newTopThreadID.length > 0 && ![newTopThreadID isEqualToString:previousTopThreadID];

    if (!promotedThreadChanged) {
        [self reloadTableAnimated];
        return;
    }

    [UIView transitionWithView:self.tableView
                      duration:0.24
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent
                    animations:^{
        [self.tableView reloadData];
    } completion:^(__unused BOOL finished) {
        [self pp_animatePromotedTopThreadCell];
    }];
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
    if (currentUserID.length == 0) {
        self.isLoading = NO;
        self.threads = @[];
        [self reloadTableAnimated];
        [self pp_updateEmptyState];
        return;
    }

    self.isObserving = YES;
    self.isLoading = YES;

    __weak typeof(self) weakSelf = self;
    self.threadsListener =
    [[ChManager sharedManager] observeChatThreadsWithUnreadCountsForUserID:currentUserID
                                                                completion:^(NSArray<ChatThreadModel *> *threads, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
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
        self.threads = @[];
        [self reloadTableAnimated];
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
    [self pp_applyThreadsSnapshot:sortedThreads animated:YES];
    [self pp_resolveMissingOtherUsersForThreads:self.threads];
    [self startObservingOnlineStatus];
    [self pp_updateEmptyState];
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

        ChCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        if ([cell isKindOfClass:ChCell.class]) {
            [cell applyPresenceOnline:online lastSeen:lastSeen];
        }
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
    ChCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    if (![cell isKindOfClass:ChCell.class]) {
        return;
    }

    [cell applyPresenceOnline:online lastSeen:lastSeen];
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
    ChCell *cell = [tableView dequeueReusableCellWithIdentifier:ChCell.reuseID forIndexPath:indexPath];
    ChatThreadModel *thread = [self pp_threadAtIndexPath:indexPath];
    if (thread) {
        [cell configureWithThread:thread];
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
                                            title:kLang(@"deleteCard")
                                          handler:^(__unused UIContextualAction *action,
                                                    __unused UIView *sourceView,
                                                    void (^completionHandler)(BOOL)) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            completionHandler(NO);
            return;
        }

        [self pp_deleteThreadAtIndexPath:indexPath completion:completionHandler];
    }];
    deleteAction.backgroundColor = UIColor.systemRedColor;

    UISwipeActionsConfiguration *configuration =
    [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
    configuration.performsFirstActionWithFullSwipe = NO;
    return configuration;
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
        [self pp_updateEmptyState];
    }];

    [[ChManager sharedManager] deleteChatThreadWithID:thread.ID
                                           completion:^(__unused NSError *error) {
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

    [PPOverlayCoordinator pp_openChatThread:thread fromVC:self];
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

    [PPOverlayCoordinator pp_openChatThread:thread fromVC:self];
}

- (void)pp_dismissPresentedStartChatPicker {
    [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)startNewChat {
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
            [PPOverlayCoordinator pp_openChatThread:thread fromVC:self];
        });
    }];
}

- (void)updateThreadAtindexPath:(NSIndexPath *)indexPath withOtherUserImage:(UIImage *)otherImage {
    (void)indexPath;
    (void)otherImage;
}

@end
