
// UserChatsViewController.m
// Pure Pets
//
// Created by Mohamed Ahmed on 26/07/2025.
//
// UserChatsViewController.m
// UserChatsViewController.m
#import "UserChatsViewController.h"
#import "PPNavBarTitleView.h"
#import "PPStoriesViewController.h"
#import <AudioToolbox/AudioToolbox.h>
#import <UIKit/UIKit.h>
#import <FirebaseAuth/FirebaseAuth.h>
#import <math.h>
#import "ChatPresenceManager.h"
// UserDataProtocol,ReloadChatsDelegate,threadUpdateDelete>

static const CGFloat PPChatStoriesHeaderHiddenHeight = 8.0;
static const CGFloat PPChatStoriesHeaderVisibleHeight = 156.0;

@interface UserChatsViewController ()
<UITableViewDelegate, UITableViewDataSource, UITableViewDataSourcePrefetching>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) id presenceToken;
// Immutable data source for table safety
@property (nonatomic, strong) NSArray<ChatThreadModel *> *threads;

// Firestore listener lifecycle (single owner)
@property (nonatomic, strong) id<FIRListenerRegistration> threadsListener;
@property (nonatomic, strong) PPEmptyStateConfig *config;
// UI state
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL isPerformingLocalMutation;
@property (nonatomic, assign) BOOL isObserving;
@property (nonatomic, strong) UIView *storiesHeaderContainer;
@property (nonatomic, strong) PPStoriesViewController *storiesViewController;
@property (nonatomic, assign) BOOL storiesHeaderVisible;
@property (nonatomic, strong) NSMutableSet<NSString *> *resolvingOtherUserIDs;

@end

@implementation UserChatsViewController

#pragma mark - Message Feedback

- (ChatThreadModel * _Nullable)pp_threadAtIndexPath:(NSIndexPath * _Nullable)indexPath {
    if (!indexPath) return nil;
    if (indexPath.section != 0) return nil;

    NSArray<ChatThreadModel *> *snapshot = self.threads ?: @[];
    if (indexPath.row < 0 || indexPath.row >= (NSInteger)snapshot.count) {
        return nil;
    }

    id candidate = snapshot[indexPath.row];
    return [candidate isKindOfClass:ChatThreadModel.class] ? (ChatThreadModel *)candidate : nil;
}

- (NSDate *)pp_activityDateForThread:(ChatThreadModel *)thread
{
    if (![thread isKindOfClass:ChatThreadModel.class]) {
        return [NSDate distantPast];
    }
    NSDate *lastMessageAt = thread.lastMessageAt;
    NSDate *timestamp = thread.timestamp;
    if (lastMessageAt && timestamp) {
        return ([lastMessageAt compare:timestamp] == NSOrderedAscending) ? timestamp : lastMessageAt;
    }
    return lastMessageAt ?: (timestamp ?: [NSDate distantPast]);
}

- (NSArray<ChatThreadModel *> *)pp_sortedVisibleThreads:(NSArray<ChatThreadModel *> *)threads
{
    if (threads.count <= 1) return threads ?: @[];
    return [threads sortedArrayUsingComparator:^NSComparisonResult(ChatThreadModel *a, ChatThreadModel *b) {
        NSDate *dateA = [self pp_activityDateForThread:a];
        NSDate *dateB = [self pp_activityDateForThread:b];
        NSComparisonResult cmp = [dateB compare:dateA];
        if (cmp != NSOrderedSame) return cmp;
        NSString *idA = a.ID ?: @"";
        NSString *idB = b.ID ?: @"";
        return [idA compare:idB];
    }];
}

- (void)pp_animatePromotedTopThreadCell
{
    if (self.threads.count == 0) return;

    NSIndexPath *topIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:topIndexPath];
    if (!cell) return;

    cell.transform = CGAffineTransformMakeTranslation(0.0, -10.0);
    cell.alpha = 0.88;

    [UIView animateWithDuration:0.40
                          delay:0.0
         usingSpringWithDamping:0.78
          initialSpringVelocity:0.9
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        cell.transform = CGAffineTransformIdentity;
        cell.alpha = 1.0;
    } completion:nil];
}

- (void)pp_applyThreadsSnapshot:(NSArray<ChatThreadModel *> *)newThreads animated:(BOOL)animated
{
    NSArray<ChatThreadModel *> *previous = self.threads ?: @[];
    NSString *previousTopID = previous.firstObject.ID ?: @"";

    self.threads = newThreads ?: @[];

    if (!animated || previous.count == 0 || self.threads.count == 0) {
        [self reloadTableAnimated];
        return;
    }

    NSString *newTopID = self.threads.firstObject.ID ?: @"";
    BOOL topChanged = newTopID.length > 0 && ![newTopID isEqualToString:previousTopID];

    if (!topChanged) {
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

- (NSString *)pp_currentChatIdentity {
    NSString *authUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (authUID.length > 0) {
        return authUID;
    }
    return [UserManager sharedManager].currentUser.ID ?: @"";
}
 
-(void)dealloc {
    NSLog(@"💀 [ChatsListener] dealloc called. Listener=%@", self.threadsListener);
    [self.threadsListener remove];
    self.threadsListener = nil;
    [[ChatPresenceManager shared] removePresenceObserver:self.presenceToken];
    self.presenceToken = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"UnreadCountsUpdated"
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"forceReloadThreads"
                                                  object:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.isLoading = YES;
    self.threads = @[];
    self.resolvingOtherUserIDs = [NSMutableSet set];
    [self setupTableView];
    [self pp_setupStoriesHeader];
    [self emptyViewConfiger];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleUnreadUpdate)
                                                 name:@"UnreadCountsUpdated"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(forceReloadThreads)
                                                 name:@"forceReloadThreads"
                                               object:nil];
    
    
   
}

- (void)forceReloadThreads {
    [self stopObservingChats];
    [self startObservingChats];
}
#pragma mark - Unread Refresh

- (void)handleUnreadUpdate
{
    
     
}

- (void)emptyViewConfiger {

    _config = [PPEmptyStateConfig new];

    // Animation
    _config.animationName = @"chats2.json"; // or any chat-style animation
    _config.isNetworkFile = YES;

    // Text
    _config.title = kLang(@"empty_chats_title");
    _config.subTitle = kLang(@"empty_chats_subtitle");

    // Action
    _config.buttonTitle = kLang(@"empty_chats_button");
    _config.target = self;
    _config.action = @selector(startNewChat);

    // Optional: hide button if user is not allowed to chat yet
   //_config.isButtonHidden = NO;
}

- (void)setupTableView {
    self.tableView =
    [[UITableView alloc] initWithFrame:CGRectZero
                                 style:UITableViewStylePlain];

    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.prefetchDataSource = self;

    [self.tableView registerClass:[ChCell class]
           forCellReuseIdentifier:@"ChCell"];

    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.separatorColor = UIColor.separatorColor;

    self.tableView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:0.0];

    self.tableView.tableFooterView = [UIView new];
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.delaysContentTouches = NO;
    self.tableView.tableFooterView = [UIView new]; // hides last divider
    [self.view addSubview:self.tableView];

    self.tableView.separatorInset = UIEdgeInsetsZero;
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)pp_setupStoriesHeader
{
    if (self.storiesViewController) {
        return;
    }

    CGFloat width = CGRectGetWidth(self.tableView.bounds);
    if (width <= 0.0) {
        width = CGRectGetWidth(self.view.bounds);
    }

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, width, PPChatStoriesHeaderHiddenHeight)];
    header.backgroundColor = UIColor.clearColor;
    self.storiesHeaderContainer = header;
    self.tableView.tableHeaderView = header;

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
        [self pp_setStoriesHeaderVisible:shouldShowStories];
    };

    [self addChildViewController:storiesVC];
    storiesVC.view.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:storiesVC.view];
    [NSLayoutConstraint activateConstraints:@[
        [storiesVC.view.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [storiesVC.view.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],
        [storiesVC.view.topAnchor constraintEqualToAnchor:header.topAnchor],
        [storiesVC.view.bottomAnchor constraintEqualToAnchor:header.bottomAnchor]
    ]];
    [storiesVC didMoveToParentViewController:self];

    self.storiesViewController = storiesVC;
    [self pp_setStoriesHeaderVisible:NO];
    [self.storiesViewController reloadStories];
}

- (void)pp_setStoriesHeaderVisible:(BOOL)visible
{
    self.storiesHeaderVisible = visible;
    self.storiesViewController.view.hidden = !visible;

    CGFloat targetHeight = visible ? PPChatStoriesHeaderVisibleHeight : PPChatStoriesHeaderHiddenHeight;
    [self pp_applyStoriesHeaderHeight:targetHeight];
}

- (void)pp_applyStoriesHeaderHeight:(CGFloat)height
{
    if (!self.storiesHeaderContainer || !self.tableView) {
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

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    if (self.storiesHeaderContainer) {
        CGFloat currentHeight = self.storiesHeaderVisible ? PPChatStoriesHeaderVisibleHeight : PPChatStoriesHeaderHiddenHeight;
        [self pp_applyStoriesHeaderHeight:currentHeight];
    }
}

- (void)startObservingChats {
    if (self.isObserving) {
        NSLog(@"🟡 [ChatsListener] Already observing. Listener=%@", self.threadsListener);
        return;
    }
    NSLog(@"🟢 [ChatsListener] Starting observer. Existing listener=%@", self.threadsListener);
    self.isObserving = YES;
    NSString *currentUserID = [self pp_currentChatIdentity];
    if (currentUserID.length == 0) {
        self.isLoading = NO;
        [PPEmptyStateHelper updateEmptyStateForListView:(UICollectionView *)self.tableView
                                              dataCount:self.threads.count
                                                         config:self.config];
        return;
    }

    __weak typeof(self) weakSelf = self;
    self.threadsListener =
    [[ChManager sharedManager]
     observeChatThreadsWithUnreadCountsForUserID:currentUserID
     completion:^(NSArray<ChatThreadModel *> *threads, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }

            // 🔒 Block snapshot updates caused by local delete
            if (self.isPerformingLocalMutation) {
                self.isPerformingLocalMutation = NO;
                return;
            }

            self.isLoading = NO;

            if (error) {
                self.threads = @[];
                [self.tableView reloadData];
                [PPEmptyStateHelper updateEmptyStateForListView:(UICollectionView *)self.tableView
                                                      dataCount:self.threads.count
                                                         config:self.config];
                return;
            }

            // Filter out binned threads for this user
            NSMutableArray<ChatThreadModel *> *visible = [NSMutableArray array];
            for (ChatThreadModel *t in threads) {
                if (t.isBinned) continue;
                [visible addObject:t];
            }
            NSArray<ChatThreadModel *> *sortedVisible = [self pp_sortedVisibleThreads:visible.copy];
            [self pp_applyThreadsSnapshot:sortedVisible animated:YES];
            [self pp_resolveMissingOtherUsersForThreads:self.threads];
            [self startObservingOnlineStatus];

            [PPEmptyStateHelper updateEmptyStateForListView:(UICollectionView *)self.tableView
                                                  dataCount:self.threads.count
                                                     config:self.config];

            // Snapshot application handles the list animation/update.
        });
    }];
    NSLog(@"🟢 [ChatsListener] Listener attached: %@", self.threadsListener);
}

- (NSString *)pp_otherUserIDForThread:(ChatThreadModel *)thread
{
    if (![thread isKindOfClass:ChatThreadModel.class]) {
        return @"";
    }
    NSString *currentUserID = [self pp_currentChatIdentity];
    for (NSString *uid in thread.memberIDs) {
        if (![uid isKindOfClass:NSString.class]) {
            continue;
        }
        if (uid.length > 0 && ![uid isEqualToString:currentUserID]) {
            return uid;
        }
    }
    return @"";
}

- (void)pp_resolveMissingOtherUsersForThreads:(NSArray<ChatThreadModel *> *)threads
{
    for (ChatThreadModel *thread in threads) {
        UserModel *resolved = [ChatThreadModel resolveOtherUserFromThread:thread];
        if (resolved.ID.length > 0) {
            thread.otherUser = resolved;
            continue;
        }

        NSString *otherUserID = [self pp_otherUserIDForThread:thread];
        if (otherUserID.length == 0 || [self.resolvingOtherUserIDs containsObject:otherUserID]) {
            continue;
        }

        [self.resolvingOtherUserIDs addObject:otherUserID];
        __weak typeof(self) weakSelf = self;
        [UsrMgr getOtherUserModelFromFirestoreWithUID:otherUserID completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
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
                for (NSInteger i = 0; i < self.threads.count; i++) {
                    ChatThreadModel *model = self.threads[i];
                    NSString *modelOtherUserID = [self pp_otherUserIDForThread:model];
                    if ([modelOtherUserID isEqualToString:otherUserID]) {
                        model.otherUser = user;
                        [reloadPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
                    }
                }

                if (reloadPaths.count > 0) {
                    [self.tableView reloadRowsAtIndexPaths:reloadPaths
                                          withRowAnimation:UITableViewRowAnimationNone];
                    [self startObservingOnlineStatus];
                }
            });
        }];
    }
}

- (void)startObservingOnlineStatus {

    NSLog(@"🟢 [Presence] startObservingOnlineStatus called");

    NSMutableOrderedSet<NSString *> *userIDsSet = [NSMutableOrderedSet orderedSet];
    for (ChatThreadModel *thread in self.threads) {
        UserModel *u = [ChatThreadModel resolveOtherUserFromThread:thread];
        if (u.ID.length) {
            [userIDsSet addObject:u.ID];
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

    if (!self.presenceToken) {
        __weak typeof(self) weakSelf = self;
        self.presenceToken =
        [[ChatPresenceManager shared]
         addPresenceObserver:^(NSString *userID) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            NSLog(@"📡 [Presence] Change received for userID=%@", userID);

            NSInteger index = [strongSelf indexForThreadWithUserID:userID];
            if (index == NSNotFound) return;

            NSIndexPath *ip = [NSIndexPath indexPathForRow:index inSection:0];
            ChCell *cell = [strongSelf.tableView cellForRowAtIndexPath:ip];
            if (!cell) return;

            BOOL online =
                    [[ChatPresenceManager shared] isUserOnline:userID];

                NSDate *lastSeen =
                    [[ChatPresenceManager shared] lastSeenForUser:userID];

                [cell applyPresenceOnline:online lastSeen:lastSeen];
         }];
    }

    for (NSInteger i = 0; i < self.threads.count; i++) {
        ChatThreadModel *thread = self.threads[i];
        UserModel *u = [ChatThreadModel resolveOtherUserFromThread:thread];
        if (!u.ID.length) continue;

        NSIndexPath *ip = [NSIndexPath indexPathForRow:i inSection:0];
        ChCell *cell = [self.tableView cellForRowAtIndexPath:ip];
        if (![cell isKindOfClass:ChCell.class]) continue;

        BOOL online = [[ChatPresenceManager shared] isUserOnline:u.ID];
        NSDate *lastSeen = [[ChatPresenceManager shared] lastSeenForUser:u.ID];
        [cell applyPresenceOnline:online lastSeen:lastSeen];
    }
}


- (NSInteger)indexForThreadWithUserID:(NSString *)uid {
    for (NSInteger i = 0; i < self.threads.count; i++) {
        ChatThreadModel *t = self.threads[i];
        UserModel *u = [ChatThreadModel resolveOtherUserFromThread:t];
        if ([u.ID isEqualToString:uid]) return i;
    }
    return NSNotFound;
}


- (void)stopObservingChats {
    NSLog(@"🔴 [ChatsListener] Stopping observer. Current listener=%@", self.threadsListener);
    [self.threadsListener remove];
    self.threadsListener = nil;
    self.isObserving = NO;
}


- (void)reloadTableAnimated {
    [UIView performWithoutAnimation:^{
            [self.tableView reloadData];
        }];
}
 

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return self.threads.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    ChCell *cell =
    [tableView dequeueReusableCellWithIdentifier:@"ChCell" forIndexPath:indexPath];
    ChatThreadModel *thread = [self pp_threadAtIndexPath:indexPath];
    if (thread) {
        [cell configureWithThread:thread];
    } else {
        NSLog(@"⚠️ [ChatsUI] cellForRow stale indexPath=%ld total=%ld",
              (long)indexPath.row,
              (long)self.threads.count);
    }
     
    return cell;
}


- (UISwipeActionsConfiguration *)
tableView:(UITableView *)tableView
trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {

    UIContextualAction *deleteAction =
    [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                            title:kLang(@"deleteCard")
                                          handler:^(UIContextualAction *action,
                                                    UIView *sourceView,
                                                    void (^completionHandler)(BOOL)) {
        self.isPerformingLocalMutation = YES;
        ChatThreadModel *thread = [self pp_threadAtIndexPath:indexPath];
        if (!thread) {
            NSLog(@"⚠️ [ChatsUI] swipe delete ignored for stale indexPath=%ld total=%ld",
                  (long)indexPath.row,
                  (long)self.threads.count);
            self.isPerformingLocalMutation = NO;
            completionHandler(NO);
            return;
        }

        NSMutableArray *mutable = [self.threads mutableCopy];
        [mutable removeObjectAtIndex:indexPath.row];
        self.threads = [mutable copy];

        [tableView deleteRowsAtIndexPaths:@[indexPath]
                         withRowAnimation:UITableViewRowAnimationFade];
        [PPEmptyStateHelper updateEmptyStateForListView:(UICollectionView *)self.tableView
                                              dataCount:self.threads.count
                                                         config:self.config];

        [[ChManager sharedManager]
         deleteChatThreadWithID:thread.ID
         completion:^(NSError * _Nullable error) { NSLog(@"deleteChatThreadWithID Success"); }];

        completionHandler(YES);
    }];

    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
}

- (CGFloat)tableView:(UITableView *)tableView
    heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 80.0;
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = UIColor.clearColor;

    // 🔥 Chat-style divider inset (aligned with text)
    CGFloat leftInset = 82.0;
    cell.separatorInset = UIEdgeInsetsMake(0, leftInset, 0, 16);
    cell.layoutMargins  = UIEdgeInsetsMake(0, leftInset, 0, 16);

    // ❌ Remove separator for last cell
    if (indexPath.row == self.threads.count - 1) {
        cell.separatorInset = UIEdgeInsetsMake(0,
                                               tableView.bounds.size.width,
                                               0,
                                               0);
    }
}



- (void)tableView:(UITableView *)tableView
prefetchRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    // Future: avatar prefetch
}

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    ChatThreadModel *thread = [self pp_threadAtIndexPath:indexPath];
    if (!thread) {
        NSLog(@"⚠️ [ChatsUI] selection ignored for stale indexPath=%ld total=%ld",
              (long)indexPath.row,
              (long)self.threads.count);
        [tableView reloadData];
        return;
    }

    [PPOverlayCoordinator pp_openChatThread:thread fromVC:self];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self stopObservingChats];
    [self.storiesViewController stopObservingStories];
    
    
    [[ChatPresenceManager shared] removePresenceObserver:self.presenceToken];
    self.presenceToken = nil;
}
-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self startObservingChats];
    [self.storiesViewController startObservingStories];
    
    // 🔥 Ensure unread UI sync after dismissing messaging screen
       [self handleUnreadUpdate];
    
    UIButton *newChatButton = [self pp_ButtonWithSystemName:@"square.and.pencil" action:@selector(startNewChat)];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:newChatButton title:nil showBack:NO];
    
   
    
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self startObservingOnlineStatus];
}

-(void)selectUser:(UserModel *)selectedUserClass vcName:(NSString *)vcName
{
    
    [[ChManager sharedManager]
     createOrGetChatThreadWithUser:selectedUserClass
     completion:^(ChatThreadModel * _Nullable chatThread, NSError * _Nullable error) {

        if (error) {
            [PPHUD dismiss];
            NSLog(@"❌ Failed to create chat thread: %@", error.localizedDescription);
            return;
        }
        [PPHUD dismiss];
        // ⚠️ DO NOT present immediately if already presenting
        dispatch_async(dispatch_get_main_queue(), ^{

            if (self.presentedViewController) {
                [self dismissViewControllerAnimated:YES completion:^{
                    chatThread.otherUser = selectedUserClass;
                    [self openChatWithThread:chatThread];
                }];
            } else {
                chatThread.otherUser = selectedUserClass;
                [self openChatWithThread:chatThread];
            }
        });
    }]; // dispatch_async(dispatch_get_main_queue(), ^{
    /*
    NSLog(@"Selected user for new chat: %@", selectedUserClass.UserName);
    [PPHUD showLoading];
    [ChManager.sharedManager checkChatAvailabilityForUser:selectedUserClass.ID
                            completion:^(BOOL available, NSString *reason) {

        if (!available) {
            //[self enterUserUnavailableState:reason];
            [PPHUD dismiss];
            [PPAlertHelper showInfoIn:self title:@"UserUnavailable" subtitle:reason];
            return;
        }
    }]; */
    
}
 
// Presents chat safely, only after any modal is dismissed, and only if thread exists
- (void)openChatWithThread:(ChatThreadModel *)thread {

    if (!thread) return;

    [PPOverlayCoordinator pp_openChatThread:thread fromVC:self];
   
}


- (void)startNewChat {
    
    
    
    NSString *currentUID = [self pp_currentChatIdentity];

    NSArray *options = [AppMgr.usersArray filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(UserModel *user, NSDictionary *bindings) {
                return ![user.ID isEqualToString:currentUID];
            }]];
    
    
    
    PPSelectOptionViewController *vc =
    [[PPSelectOptionViewController alloc] initWithCompletion:^(id selected) {
        DLog(@"[PickUser] completion fired with selected=%@", selected);
        self.selectedUser = selected;
        [self selectUser:selected vcName:@"chats"];
        DLog(@"[PickUser] \n User value \nupdated='%@' \nuid='%@' \nselectedUser=%@", self.selectedUser.UserName, self.selectedUser.ID, self.selectedUser);
    }];

    // 3) Supply data + references for XLForm updates
    vc.allOptions      = options;
    vc.filteredOptions = options;

    vc.parentForm      = self;
    vc.imageLoaded = NO;
    vc.presentationStyle = PPSelectOptionPresentationSheet;
    vc.title = kLang(@"Select User");
    
    vc.modalPresentationStyle = UIModalPresentationFormSheet;
    vc.modalTransitionStyle = UIModalTransitionStyleCoverVertical;

    // prevent background dimming
    vc.modalPresentationCapturesStatusBarAppearance = YES;
    vc.view.backgroundColor = UIColor.systemBackgroundColor;

    // important: set presentation context
    self.definesPresentationContext = YES;
    vc.modalPresentationStyle = UIModalPresentationOverCurrentContext;
   [self presentViewController:vc animated:YES completion:nil];
}

#pragma mark - ChatManagerDelegate

- (void)chat:(ChatThreadModel *)chat didUpdateOnlineStatus:(OnlineStatus)status {
    
    NSLog(@"OnlineStatus ---- >>>>>> didUpdateOnlineStatus on chat %@",chat.ID);
    
    // find indexPath, reload row, or update just the dot:
    NSIndexPath *idx = [self indexPathForChat:chat];
    if (!idx) return;
    [self.tableView reloadRowsAtIndexPaths:@[idx]
                          withRowAnimation:UITableViewRowAnimationNone];
}

- (NSIndexPath *)indexPathForChat:(ChatThreadModel *)chat {
    // Find by unique ID rather than pointer equality, in case objects differ
    NSUInteger row = [self.threads indexOfObjectPassingTest:^BOOL(ChatThreadModel *obj, NSUInteger idx, BOOL *stop) {
        return [obj.ID isEqualToString:chat.ID];
    }];
    NSLog(@"OnlineStatus ---- >>>>>> indexPathForChat on chat %@",chat.ID);
    if (row != NSNotFound) {
        return [NSIndexPath indexPathForRow:row inSection:0];
    } else {
        return nil;
    }
}

#pragma mark - Chat Methods
- (void)startChatWith:(UserModel *)user
{
    NSLog(@"💬 [Chat] Start chat requested with userID=%@", user.ID);

    [ChManager.sharedManager createOrGetChatThreadWithUser:user
                                                completion:^(ChatThreadModel * _Nullable thread,
                                                             NSError * _Nullable error)
    {
        if (error) {
            NSLog(@"❌ [Chat] Failed to create/get chat thread for userID=%@ | error=%@",
                  user.ID,
                  error.localizedDescription);
            return;
        }

        if (!thread) {
            NSLog(@"⚠️ [Chat] Thread is nil for userID=%@", user.ID);
            return;
        }

        NSLog(@"✅ [Chat] Thread ready | threadID=%@ | messagesCount=%ld",
              thread.ID,
              (long)thread.messagesCount);

        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"➡️ [Chat] Opening chat UI for threadID=%@", thread.ID);

            // Coordinator is optional here, but keeping for consistency
            //PPOverlayCoordinator *over = [[PPOverlayCoordinator alloc] initWithPresenter:self];
            [PPOverlayCoordinator pp_openChatThread:thread fromVC:self];
        });
    }];
}
-(void)updateThreadAtindexPath:(NSIndexPath *)indexPath withOtherUserImage:(UIImage *)otherImage
{
    // This method is not adjusted because threads is immutable array.
    // If needed, this should be handled differently.
}
@end
/*
 UIView *card = cell.contentView;
 card.layer.cornerRadius = 16.0;
 card.layer.masksToBounds = NO;

 card.layer.shadowColor = [UIColor blackColor].CGColor;
 card.layer.shadowOpacity = 0.06;
 card.layer.shadowRadius = 12;
 card.layer.shadowOffset = CGSizeMake(0, 6);

 NSInteger section = indexPath.section;
 NSInteger row = indexPath.row;
 NSInteger rows = [tableView numberOfRowsInSection:section];

 UIBezierPath *maskPath;
 CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
 CGRect bounds = cell.bounds;

 if (row == 0 && row == rows - 1) {
     // Single cell
     maskPath = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:16];
 } else if (row == 0) {
     // First cell
     maskPath = [UIBezierPath bezierPathWithRoundedRect:bounds
                                      byRoundingCorners:(UIRectCornerTopLeft | UIRectCornerTopRight)
                                            cornerRadii:CGSizeMake(16, 16)];
 } else if (row == rows - 1) {
     // Last cell
     maskPath = [UIBezierPath bezierPathWithRoundedRect:bounds
                                      byRoundingCorners:(UIRectCornerBottomLeft | UIRectCornerBottomRight)
                                            cornerRadii:CGSizeMake(16, 16)];
 } else {
     // Middle cell
     maskPath = [UIBezierPath bezierPathWithRect:bounds];
 }

 maskLayer.path = maskPath.CGPath;
 cell.layer.mask = maskLayer;
 */
