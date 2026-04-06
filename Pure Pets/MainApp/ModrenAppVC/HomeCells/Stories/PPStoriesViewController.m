//
//  PPStoriesViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 2/22/26.
//

#import "PPStoriesViewController.h"
#import "Language.h"
#import "PPStoryCollectionViewCell.h"
#import "PPStoryPlayerViewController.h"
#import "PPStoriesManager.h"
#import "PPStory.h"
#import "UserManager.h"
#import "UserModel.h"
#import "ImagePicker.h"
#import "GM.h"
#import "PPHUD.h"
#import <FirebaseAuth/FirebaseAuth.h>

static const CGFloat PPStoriesSidePadding      = 12.0;
static const CGFloat PPStoriesTopPadding        = 8.0;
static const CGFloat PPStoriesBottomPadding     = 10.0;
static const CGFloat PPStoriesItemSpacing       = 10.0;
static const CGFloat PPStoriesItemWidth         = 88.0;
static const CGFloat PPStoriesItemHeight        = 108.0;
static const CGFloat PPStoriesTitleTopPadding   = 10.0;
static const CGFloat PPStoriesTitleBottomSpacing = 4.0;

@interface PPStoriesViewController ()
@property (nonatomic, strong) UILabel *sectionTitleLabel;
@property (nonatomic, strong) NSLayoutConstraint *collectionTopConstraint;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> storiesListener;
@property (nonatomic, assign) BOOL hasSectionTitle;
@property (nonatomic, strong, nullable) PPStory *currentUserStory;
@property (nonatomic, strong, nullable) ImagePicker *imagePicker;
@property (nonatomic, assign) BOOL isUploadingStory;
@property (nonatomic, assign) BOOL hasPlayedEntrance;
@property (nonatomic, strong) UIVisualEffectView *glassBackdrop;
@end

@implementation PPStoriesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;

    // Glass backdrop card
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    _glassBackdrop = [[UIVisualEffectView alloc] initWithEffect:blur];
    _glassBackdrop.translatesAutoresizingMaskIntoConstraints = NO;
    _glassBackdrop.layer.cornerRadius = 20.0;
    _glassBackdrop.layer.masksToBounds = YES;
    _glassBackdrop.layer.borderWidth = 0.5;
    _glassBackdrop.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;
    [self.view addSubview:_glassBackdrop];

    _sectionTitleLabel = [UILabel new];
    _sectionTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _sectionTitleLabel.font = [GM boldFontWithSize:15.0];
    _sectionTitleLabel.textColor = UIColor.labelColor;
    _sectionTitleLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    _sectionTitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    _sectionTitleLabel.hidden = YES;
    [self.view addSubview:_sectionTitleLabel];

    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.sectionInset = UIEdgeInsetsMake(PPStoriesTopPadding, PPStoriesSidePadding, PPStoriesBottomPadding, PPStoriesSidePadding);
    layout.minimumInteritemSpacing = PPStoriesItemSpacing;
    layout.minimumLineSpacing = PPStoriesItemSpacing;
    layout.itemSize = CGSizeMake(PPStoriesItemWidth, PPStoriesItemHeight);

    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero
                                          collectionViewLayout:layout];
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _collectionView.showsHorizontalScrollIndicator = NO;
    _collectionView.backgroundColor = UIColor.clearColor;
    _collectionView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [_collectionView registerClass:[PPStoryCollectionViewCell class]
        forCellWithReuseIdentifier:@"StoryCell"];
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    [self.view addSubview:_collectionView];

    _collectionTopConstraint =
        [_collectionView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:0.0];

    [NSLayoutConstraint activateConstraints:@[
        [_glassBackdrop.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:4.0],
        [_glassBackdrop.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8.0],
        [_glassBackdrop.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8.0],
        [_glassBackdrop.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-4.0],

        [_sectionTitleLabel.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:PPStoriesTitleTopPadding],
        [_sectionTitleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPStoriesSidePadding + 8.0],
        [_sectionTitleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-(PPStoriesSidePadding + 8.0)],
        [_collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        _collectionTopConstraint,
        [_collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [self pp_applySectionTitle];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self startObservingStories];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopObservingStories];
}

- (void)dealloc {
    [self stopObservingStories];
}

- (void)setSectionTitleText:(NSString * _Nullable)sectionTitleText {
    _sectionTitleText = [sectionTitleText copy];
    [self pp_applySectionTitle];
}

- (void)setSectionTitleLocalizationKey:(NSString * _Nullable)sectionTitleLocalizationKey {
    _sectionTitleLocalizationKey = [sectionTitleLocalizationKey copy];
    [self pp_applySectionTitle];
}

- (void)startObservingStories {
    if (self.storiesListener) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    self.storiesListener = [[PPStoriesManager shared] observeStoriesWithCompletion:^(NSArray<PPStory *> *stories, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self pp_applyIncomingStories:error ? @[] : (stories ?: @[]) error:error];
        });
    }];

    if (!self.storiesListener) {
        [self reloadStories];
    }
}

- (void)stopObservingStories {
    [self.storiesListener remove];
    self.storiesListener = nil;
}

- (void)reloadStories {
    __weak typeof(self) weakSelf = self;
    [[PPStoriesManager shared] fetchStoriesWithCompletion:^(NSArray<PPStory *> *stories, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self pp_applyIncomingStories:error ? @[] : (stories ?: @[]) error:error];
        });
    }];
}

#pragma mark - CollectionView

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    (void)collectionView; (void)section;
    return self.stories.count + ([self pp_hasCurrentUserEntry] ? 1 : 0);
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                           cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    PPStoryCollectionViewCell *cell =
        [collectionView dequeueReusableCellWithReuseIdentifier:@"StoryCell" forIndexPath:indexPath];

    __weak typeof(self) weakSelf = self;
    cell.onAddBadgeTapped = nil;
    if ([self pp_isCurrentUserEntryAtIndex:indexPath.item]) {
        PPStory *story = [self pp_currentUserDisplayStory];
        [cell configureWithStory:story currentUserEntry:YES showAddBadge:YES];
        cell.onAddBadgeTapped = ^{
            __strong typeof(weakSelf) self = weakSelf;
            [self pp_handleAddStoryTapped];
        };
    } else {
        PPStory *story = [self pp_storyForDisplayIndex:indexPath.item];
        if (story) {
            [cell configureWithStory:story currentUserEntry:NO showAddBadge:NO];
        }
    }

    // Staggered entrance animation (first load only)
    if (!self.hasPlayedEntrance) {
        NSTimeInterval delay = indexPath.item * 0.06;
        [cell playEntranceAnimationWithDelay:delay];
    }

    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item < 0 || indexPath.item >= [self collectionView:collectionView numberOfItemsInSection:indexPath.section]) {
        return;
    }

    if ([self pp_isCurrentUserEntryAtIndex:indexPath.item]) {
        if (self.currentUserStory.items.count > 0) {
            NSArray<PPStory *> *playableStories = [self pp_playableStories];
            if (playableStories.count > 0) {
                PPStoryPlayerViewController *player =
                    [[PPStoryPlayerViewController alloc] initWithStories:playableStories startIndex:0];
                player.modalPresentationStyle = UIModalPresentationFullScreen;
                UIViewController *presenter = self.parentViewController ?: self;
                if (!presenter.presentedViewController) {
                    [presenter presentViewController:player animated:YES completion:nil];
                }
            }
        } else {
            [self pp_handleAddStoryTapped];
        }
        return;
    }

    PPStory *story = [self pp_storyForDisplayIndex:indexPath.item];
    if (story.items.count == 0) {
        return;
    }

    if (!story.isSeen) {
        story.isSeen = YES;
        [collectionView reloadItemsAtIndexPaths:@[indexPath]];
        [[PPStoriesManager shared] recordViewForStoryOwnerID:story.userID completion:nil];
    }

    NSArray<PPStory *> *playableStories = [self pp_playableStories];
    NSInteger startIndex = [playableStories indexOfObjectPassingTest:^BOOL(PPStory * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)idx;
        if ([obj.userID isEqualToString:story.userID]) {
            *stop = YES;
            return YES;
        }
        return NO;
    }];
    if (startIndex == NSNotFound) {
        startIndex = 0;
    }

    PPStoryPlayerViewController *player =
        [[PPStoryPlayerViewController alloc] initWithStories:playableStories startIndex:startIndex];
    player.modalPresentationStyle = UIModalPresentationFullScreen;

    UIViewController *presenter = self.parentViewController ?: self;
    if (!presenter.presentedViewController) {
        [presenter presentViewController:player animated:YES completion:nil];
    }
}

- (void)pp_applyIncomingStories:(NSArray<PPStory *> *)stories error:(NSError * _Nullable)error {
    (void)error;
    NSString *currentUserID = [self pp_currentUserID];
    NSMutableArray<PPStory *> *otherStories = [NSMutableArray array];
    PPStory *myStory = nil;
    for (PPStory *story in stories) {
        if (![story isKindOfClass:PPStory.class]) continue;
        if ([story isExpired]) continue;
        if (currentUserID.length > 0 && [story.userID isEqualToString:currentUserID]) {
            myStory = story;
            continue;
        }
        [otherStories addObject:story];
    }

    BOOL isFirstLoad = (self.stories == nil || self.stories.count == 0) && !self.hasPlayedEntrance;
    self.currentUserStory = myStory;
    self.stories = otherStories.copy;
    [self.collectionView reloadData];

    // Mark entrance as played after first load
    if (isFirstLoad && (otherStories.count > 0 || [self pp_hasCurrentUserEntry])) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.hasPlayedEntrance = YES;
        });
    }

    // Preserve scroll position unless near beginning
    CGFloat currentOffsetX = self.collectionView.contentOffset.x;
    CGFloat threshold = 60.0;

    if ([self pp_hasCurrentUserEntry] && currentOffsetX <= threshold) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.collectionView layoutIfNeeded];
            if ([self.collectionView numberOfItemsInSection:0] > 0) {
                NSIndexPath *firstIndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
                [self.collectionView scrollToItemAtIndexPath:firstIndexPath
                                            atScrollPosition:UICollectionViewScrollPositionLeft
                                                    animated:NO];
            }
        });
    }

    if (self.onStoriesChanged) {
        NSMutableArray<PPStory *> *display = [NSMutableArray array];
        if (self.currentUserStory.items.count > 0) {
            [display addObject:self.currentUserStory];
        }
        [display addObjectsFromArray:self.stories ?: @[]];
        if (display.count == 0 && [self pp_hasCurrentUserEntry]) {
            [display addObject:[self pp_currentUserDisplayStory]];
        }
        self.onStoriesChanged(display.copy);
    }
}

- (NSString *)pp_currentUserID {
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    if (uid.length > 0) return uid;
    return [UserManager sharedManager].currentUser.ID ?: @"";
}

- (BOOL)pp_hasCurrentUserEntry {
    return [self pp_currentUserID].length > 0;
}

- (BOOL)pp_isCurrentUserEntryAtIndex:(NSInteger)index {
    return [self pp_hasCurrentUserEntry] && index == 0;
}

- (NSInteger)pp_currentUserEntryOffset {
    return [self pp_hasCurrentUserEntry] ? 1 : 0;
}

- (PPStory *)pp_currentUserDisplayStory {
    UserModel *currentUser = [UserManager sharedManager].currentUser;
    if (self.currentUserStory.items.count > 0) {
        if (!self.currentUserStory.userImageURL) {
            self.currentUserStory.userImageURL = currentUser.UserImageUrl ?: [FIRAuth auth].currentUser.photoURL;
        }
        self.currentUserStory.userName = kLang(@"your_story");
        return self.currentUserStory;
    }

    PPStory *displayStory = [PPStory new];
    displayStory.userID = [self pp_currentUserID];
    displayStory.userName = kLang(@"your_story");
    displayStory.userImageURL = currentUser.UserImageUrl ?: [FIRAuth auth].currentUser.photoURL;
    displayStory.items = @[];
    displayStory.isSeen = YES;
    return displayStory;
}

- (PPStory * _Nullable)pp_storyForDisplayIndex:(NSInteger)displayIndex {
    NSInteger modelIndex = displayIndex - [self pp_currentUserEntryOffset];
    if (modelIndex < 0 || modelIndex >= (NSInteger)self.stories.count) return nil;
    return self.stories[modelIndex];
}

- (NSArray<PPStory *> *)pp_playableStories {
    NSMutableArray<PPStory *> *all = [NSMutableArray array];
    if (self.currentUserStory.items.count > 0) {
        [all addObject:self.currentUserStory];
    }
    [all addObjectsFromArray:self.stories ?: @[]];
    return all.copy;
}

- (void)pp_handleAddStoryTapped {
    if (self.isUploadingStory) return;

    UIViewController *presenter = self.parentViewController ?: self;
    if (!presenter || presenter.presentedViewController) return;

    self.imagePicker = [[ImagePicker alloc] initWithPresentingViewController:presenter];
    __weak typeof(self) weakSelf = self;
    [self.imagePicker showImageSourceSelection:^(UIImage * _Nullable image, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (error || !image) return;

        self.isUploadingStory = YES;
        [PPHUD showLoading:kLang(@"story_uploading")];
        [[PPStoriesManager shared] addImageStoryItemForCurrentUser:image completion:^(NSError * _Nullable writeError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isUploadingStory = NO;
                [PPHUD dismiss];
                if (writeError) {
                    [PPHUD showInfo:kLang(@"story_upload_failed")];
                    return;
                }
                [PPHUD showSuccess:kLang(@"post_story_sucsses")];
                [self reloadStories];
            });
        }];
    }];
}

- (void)pp_applySectionTitle {
    if (!self.isViewLoaded) return;

    NSString *resolvedTitle = self.sectionTitleText ?: @"";
    if (self.sectionTitleLocalizationKey.length > 0) {
        resolvedTitle = kLang(self.sectionTitleLocalizationKey);
    }

    self.hasSectionTitle = resolvedTitle.length > 0;
    self.sectionTitleLabel.text = resolvedTitle;
    self.sectionTitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.sectionTitleLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.sectionTitleLabel.hidden = !self.hasSectionTitle;
    CGFloat labelHeight = ceil(self.sectionTitleLabel.font.lineHeight);
    self.collectionTopConstraint.constant =
        self.hasSectionTitle ? (PPStoriesTitleTopPadding + PPStoriesTitleBottomSpacing + labelHeight) : 0.0;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    (void)collectionView; (void)collectionViewLayout; (void)indexPath;
    return CGSizeMake(PPStoriesItemWidth, PPStoriesItemHeight);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView
                   layout:(UICollectionViewLayout *)collectionViewLayout
minimumLineSpacingForSectionAtIndex:(NSInteger)section
{
    (void)collectionView; (void)collectionViewLayout; (void)section;
    return PPStoriesItemSpacing;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView
                        layout:(UICollectionViewLayout *)collectionViewLayout
        insetForSectionAtIndex:(NSInteger)section
{
    (void)collectionView; (void)collectionViewLayout; (void)section;
    return UIEdgeInsetsMake(PPStoriesTopPadding, PPStoriesSidePadding, PPStoriesBottomPadding, PPStoriesSidePadding);
}

@end
