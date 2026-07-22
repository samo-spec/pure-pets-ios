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

static const CGFloat PPStoriesSidePadding        = 18.0;
static const CGFloat PPStoriesContainerSideInset = 16.0;
static const CGFloat PPStoriesTopPadding         = 10.0;
static const CGFloat PPStoriesBottomPadding      = 10.0;
static const CGFloat PPStoriesItemSpacing        = 12.0;
static const CGFloat PPStoriesItemWidth          = 106.0;
static const CGFloat PPStoriesItemHeight         = 138.0;
static const CGFloat PPStoriesTitleTopPadding    = 16.0;
static const CGFloat PPStoriesTitleBottomSpacing = 8.0;

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
@property (nonatomic, strong) UIView *ambientGlowView;
@property (nonatomic, strong) UIView *bottomAccentView;
@end

@implementation PPStoriesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.view.semanticContentAttribute = GM.setSemantic;
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    UIColor *storiesAccentColor = AppPrimaryClrShiner ?: AppPrimaryClr ?: UIColor.systemPinkColor;
    UIColor *storiesSurfaceColor = AppForgroundColr ?: AppBackgroundClr ?: UIColor.secondarySystemBackgroundColor;
    _glassBackdrop = [[UIVisualEffectView alloc] initWithEffect:blur];
    _glassBackdrop.translatesAutoresizingMaskIntoConstraints = NO;
    _glassBackdrop.layer.cornerRadius = 28.0;
    _glassBackdrop.layer.masksToBounds = YES;
    _glassBackdrop.clipsToBounds = YES;
    _glassBackdrop.layer.borderWidth = 0.0;
    [_glassBackdrop pp_setBorderColor:[UIColor.whiteColor colorWithAlphaComponent:0.68]];
    [_glassBackdrop pp_setShadowColor:[UIColor.blackColor colorWithAlphaComponent:0.10]];
    _glassBackdrop.layer.shadowOpacity = 1.0;
    _glassBackdrop.layer.shadowRadius = 22.0;
    _glassBackdrop.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    [self.view addSubview:_glassBackdrop];

    UIView *ambientGlow = [UIView new];
    ambientGlow.translatesAutoresizingMaskIntoConstraints = NO;
    ambientGlow.backgroundColor = [storiesAccentColor colorWithAlphaComponent:0.20];
    ambientGlow.userInteractionEnabled = NO;
    ambientGlow.layer.cornerRadius = 76.0;
    [ambientGlow pp_setShadowColor:storiesAccentColor];
    ambientGlow.layer.shadowOpacity = 0.28;
    ambientGlow.layer.shadowRadius = 46.0;
    ambientGlow.layer.shadowOffset = CGSizeZero;
    [_glassBackdrop.contentView addSubview:ambientGlow];
    self.ambientGlowView = ambientGlow;

    UIView *tintOverlay = [UIView new];
    tintOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    tintOverlay.backgroundColor = [storiesSurfaceColor colorWithAlphaComponent:0.94];
    tintOverlay.userInteractionEnabled = NO;
    tintOverlay.layer.cornerRadius = 28.0;
    tintOverlay.clipsToBounds = YES;
    [_glassBackdrop.contentView addSubview:tintOverlay];

    UIView *bottomAccent = [UIView new];
    bottomAccent.translatesAutoresizingMaskIntoConstraints = NO;
    bottomAccent.userInteractionEnabled = NO;
    bottomAccent.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.12];
    bottomAccent.layer.cornerRadius = 1.5;
    bottomAccent.hidden = YES;
    [_glassBackdrop.contentView addSubview:bottomAccent];
    self.bottomAccentView = bottomAccent;

    [NSLayoutConstraint activateConstraints:@[
        [ambientGlow.widthAnchor constraintEqualToConstant:152.0],
        [ambientGlow.heightAnchor constraintEqualToConstant:152.0],
        [ambientGlow.topAnchor constraintEqualToAnchor:_glassBackdrop.contentView.topAnchor constant:-56.0],
        [ambientGlow.trailingAnchor constraintEqualToAnchor:_glassBackdrop.contentView.trailingAnchor constant:42.0],

        [tintOverlay.topAnchor constraintEqualToAnchor:_glassBackdrop.contentView.topAnchor],
        [tintOverlay.leadingAnchor constraintEqualToAnchor:_glassBackdrop.contentView.leadingAnchor],
        [tintOverlay.trailingAnchor constraintEqualToAnchor:_glassBackdrop.contentView.trailingAnchor],
        [tintOverlay.bottomAnchor constraintEqualToAnchor:_glassBackdrop.contentView.bottomAnchor],

        [bottomAccent.leadingAnchor constraintEqualToAnchor:_glassBackdrop.contentView.leadingAnchor constant:22.0],
        [bottomAccent.trailingAnchor constraintEqualToAnchor:_glassBackdrop.contentView.trailingAnchor constant:-22.0],
        [bottomAccent.bottomAnchor constraintEqualToAnchor:_glassBackdrop.contentView.bottomAnchor constant:-10.0],
        [bottomAccent.heightAnchor constraintEqualToConstant:3.0],
    ]];

    _sectionTitleLabel = [UILabel new];
    _sectionTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _sectionTitleLabel.font = [GM boldFontWithSize:15.5];
    _sectionTitleLabel.textColor = UIColor.labelColor;
    _sectionTitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    _sectionTitleLabel.numberOfLines = 1;
    _sectionTitleLabel.hidden = YES;
    [self.view addSubview:_sectionTitleLabel];

    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.sectionInset = UIEdgeInsetsMake(PPStoriesTopPadding, PPStoriesSidePadding + 6, PPStoriesBottomPadding, PPStoriesSidePadding+6);
    layout.minimumInteritemSpacing = PPStoriesItemSpacing;
    layout.minimumLineSpacing = PPStoriesItemSpacing;
    layout.itemSize = CGSizeMake(PPStoriesItemWidth, PPStoriesItemHeight);

    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero
                                          collectionViewLayout:layout];
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _collectionView.showsHorizontalScrollIndicator = NO;
    _collectionView.backgroundColor = UIColor.clearColor;
    _collectionView.decelerationRate = UIScrollViewDecelerationRateFast;
    [_collectionView registerClass:[PPStoryCollectionViewCell class]
        forCellWithReuseIdentifier:@"StoryCell"];
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    _collectionView.semanticContentAttribute = GM.setSemantic;
    [self.view addSubview:_collectionView];

    _collectionTopConstraint =
        [_collectionView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:0.0];

    [NSLayoutConstraint activateConstraints:@[
        [_glassBackdrop.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:4.0],
        [_glassBackdrop.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPStoriesContainerSideInset],
        [_glassBackdrop.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPStoriesContainerSideInset],
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

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    self.glassBackdrop.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.glassBackdrop.bounds
                                                                     cornerRadius:28.0].CGPath;
    [Styling addLiquidGlassBorderToView:_glassBackdrop cornerRadius:28.0];
    [self.collectionView.collectionViewLayout invalidateLayout];
}

#pragma mark - Public

- (void)reloadStories
{
    __weak typeof(self) weakSelf = self;
    [[PPStoriesManager shared] fetchStoriesWithCompletion:^(NSArray<PPStory *> *stories, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf pp_applyIncomingStories:stories error:error];
    }];
}

- (void)startObservingStories
{
    if (self.storiesListener) return;

    __weak typeof(self) weakSelf = self;
    self.storiesListener =
        [[PPStoriesManager shared] observeStoriesWithCompletion:^(NSArray<PPStory *> *stories, NSError *error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf pp_applyIncomingStories:stories error:error];
        }];
}

- (void)stopObservingStories
{
    if (self.storiesListener) {
        [self.storiesListener remove];
        self.storiesListener = nil;
    }
}

- (void)dealloc
{
    [self stopObservingStories];
}

#pragma mark - Player Configuration

- (void)pp_configureStoryPlayerForOptimisticUpdates:(PPStoryPlayerViewController *)player
{
    __weak typeof(self) weakSelf = self;
    player.onStoryUpdated = ^(PPStory *story) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf.collectionView reloadData];
    };
}

- (NSArray<PPStory *> *)pp_playableStories
{
    NSMutableArray<PPStory *> *result = [NSMutableArray array];
    if (self.currentUserStory && self.currentUserStory.items.count > 0) {
        [result addObject:self.currentUserStory];
    }
    if (self.stories.count > 0) {
        [result addObjectsFromArray:self.stories];
    }
    return result;
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    (void)collectionView;
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    (void)collectionView; (void)section;
    NSInteger count = self.stories.count;
    if ([self pp_hasCurrentUserEntry]) {
        count += 1;
    }
    return count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    PPStoryCollectionViewCell *cell =
        [collectionView dequeueReusableCellWithReuseIdentifier:@"StoryCell"
                                                  forIndexPath:indexPath];

    BOOL isCurrentUserEntry = [self pp_isCurrentUserEntryAtIndex:indexPath.item];
    BOOL isEmpty = isCurrentUserEntry && (self.currentUserStory.items.count == 0);

    if (isCurrentUserEntry) {
        PPStory *displayStory = self.currentUserStory ?: [self pp_currentUserDisplayStory];
        [cell configureWithStory:displayStory
               currentUserEntry:YES
                   showAddBadge:isEmpty];
        __weak typeof(self) weakSelf = self;
        cell.onAddBadgeTapped = ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf pp_handleCurrentUserStoryTap];
        };
    } else {
        NSInteger storyIndex = [self pp_hasCurrentUserEntry] ? indexPath.item - 1 : indexPath.item;
        if (storyIndex >= 0 && storyIndex < (NSInteger)self.stories.count) {
            PPStory *story = self.stories[storyIndex];
            [cell configureWithStory:story];
        }
    }

    if (!self.hasPlayedEntrance && self.stories.count > 0) {
        [cell playEntranceAnimationWithDelay:indexPath.item * 0.06];
    }

    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.isUploadingStory) return;

    BOOL isCurrentUserEntry = [self pp_isCurrentUserEntryAtIndex:indexPath.item];
    if (isCurrentUserEntry && self.currentUserStory.items.count == 0) {
        return;
    }

    PPStory *story = nil;
    if (isCurrentUserEntry) {
        story = self.currentUserStory;
    } else {
        NSInteger storyIndex = [self pp_hasCurrentUserEntry] ? indexPath.item - 1 : indexPath.item;
        if (storyIndex >= 0 && storyIndex < (NSInteger)self.stories.count) {
            story = self.stories[storyIndex];
        }
    }
    if (!story || story.items.count == 0) return;

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
    [self pp_configureStoryPlayerForOptimisticUpdates:player];
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

    if (isFirstLoad && (otherStories.count > 0 || [self pp_hasCurrentUserEntry])) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.hasPlayedEntrance = YES;
        });
    }

    CGFloat currentOffsetX = self.collectionView.contentOffset.x;
    CGFloat threshold = 60.0;

    if ([self pp_hasCurrentUserEntry] && currentOffsetX <= threshold) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.collectionView layoutIfNeeded];
            if ([self.collectionView numberOfItemsInSection:0] > 0) {
                NSIndexPath *firstIndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
                UICollectionViewScrollPosition position = Language.isRTL
                    ? UICollectionViewScrollPositionRight
                    : UICollectionViewScrollPositionLeft;
                [self.collectionView scrollToItemAtIndexPath:firstIndexPath
                                            atScrollPosition:position
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

- (PPStory *)pp_currentUserDisplayStory {
    PPStory *story = [[PPStory alloc] init];
    story.userID = [self pp_currentUserID];
    story.userName = kLang(@"your_story");
    story.items = @[];
    return story;
}

#pragma mark - Current User Story Actions

- (void)pp_handleCurrentUserStoryTap
{
    self.imagePicker = [[ImagePicker alloc] initWithPresentingViewController:self];
    __weak typeof(self) weakSelf = self;
    [self.imagePicker showImageSourceSelection:^(UIImage * _Nullable image, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !image) return;

        strongSelf.isUploadingStory = YES;
        [PPHUD showLoading];

        [[PPStoriesManager shared] addImageStoryItemForCurrentUser:image completion:^(NSError *error) {
            strongSelf.isUploadingStory = NO;
            [PPHUD dismiss];

            if (error) {
                [PPHUD showError:error.localizedDescription ?: kLang(@"story_upload_failed")];
                return;
            }
            [strongSelf reloadStories];
        }];
    }];
}

#pragma mark - Section Title

- (void)pp_applySectionTitle {
    if (!self.isViewLoaded) return;

    NSString *resolvedTitle = self.sectionTitleText ?: @"";
    if (self.sectionTitleLocalizationKey.length > 0) {
        resolvedTitle = kLang(self.sectionTitleLocalizationKey);
    }
    resolvedTitle = nil;
    self.hasSectionTitle = resolvedTitle.length > 0;
    self.sectionTitleLabel.text = resolvedTitle;
    self.sectionTitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
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
    NSInteger itemCount = self.stories.count + ([self pp_hasCurrentUserEntry] ? 1 : 0);
    CGFloat width = CGRectGetWidth(collectionView.bounds);
    CGFloat contentWidth = (itemCount * PPStoriesItemWidth) + (MAX(0, itemCount - 1) * PPStoriesItemSpacing);
    CGFloat extraInset = MAX(0.0, width - contentWidth - (PPStoriesSidePadding * 2.0));
    CGFloat leadingInset = PPStoriesSidePadding;
    CGFloat trailingInset = PPStoriesSidePadding;

    if (Language.isRTL) {
        leadingInset += extraInset;
    } else {
        trailingInset += extraInset;
    }

    return UIEdgeInsetsMake(PPStoriesTopPadding, leadingInset, PPStoriesBottomPadding, trailingInset);
}

@end
