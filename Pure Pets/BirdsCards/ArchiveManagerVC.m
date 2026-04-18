//
//  ArchiveManagerVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/12/2024.
//  Modern UI refactor – 2025
//

#import "ArchiveManagerVC.h"
#import "PrefixHeader.pch"

static NSString * const kFolderCellID = @"PPArchiveFolderCell";
static NSString * const kNewCellID    = @"PPNewArchiveCell";

static UIColor *PPFolderColor(NSInteger idx) {
    NSArray<UIColor *> *palette = @[
        [UIColor colorWithRed:0.35 green:0.58 blue:0.93 alpha:1.0],
        [UIColor colorWithRed:0.30 green:0.76 blue:0.55 alpha:1.0],
        [UIColor colorWithRed:0.95 green:0.60 blue:0.30 alpha:1.0],
        [UIColor colorWithRed:0.65 green:0.45 blue:0.85 alpha:1.0],
        [UIColor colorWithRed:0.90 green:0.40 blue:0.55 alpha:1.0],
        [UIColor colorWithRed:0.25 green:0.70 blue:0.75 alpha:1.0],
    ];
    return palette[idx % palette.count];
}

// ──────────────────────────────────────────────
#pragma mark - PPArchiveFolderCell
// ──────────────────────────────────────────────

@interface PPArchiveFolderCell : UICollectionViewCell
@property (nonatomic, strong) UIView      *iconCircle;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel     *titleLabel;
@property (nonatomic, strong) UILabel     *countLabel;
@property (nonatomic, strong) UIImageView *chevron;
- (void)configureWithArchive:(ArchiveModel *)archive colorIndex:(NSInteger)index;
@end

@implementation PPArchiveFolderCell

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) [self buildUI];
    return self;
}

- (void)buildUI {
    UIView *cv = self.contentView;
    cv.backgroundColor = AppForgroundColr;
    cv.layer.cornerRadius = 14;
    [cv pp_setShadowColor:[UIColor blackColor]];
    cv.layer.shadowOffset  = CGSizeMake(0, 2);
    cv.layer.shadowRadius  = 8;
    cv.layer.shadowOpacity = 0.06;
    self.clipsToBounds = NO;
    cv.clipsToBounds   = NO;

    _iconCircle = [UIView new];
    _iconCircle.layer.cornerRadius = 22;
    _iconCircle.translatesAutoresizingMaskIntoConstraints = NO;
    [cv addSubview:_iconCircle];

    _iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"folder.fill"]];
    _iconView.tintColor    = [UIColor whiteColor];
    _iconView.contentMode  = UIViewContentModeScaleAspectFit;
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [_iconCircle addSubview:_iconView];

    _titleLabel = [UILabel new];
    _titleLabel.font = [GM boldFontWithSize:16];
    _titleLabel.numberOfLines = 1;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cv addSubview:_titleLabel];

    _countLabel = [UILabel new];
    _countLabel.font      = [GM MidFontWithSize:13];
    _countLabel.textColor = [UIColor secondaryLabelColor];
    _countLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cv addSubview:_countLabel];

    _chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
    _chevron.tintColor    = [UIColor tertiaryLabelColor];
    _chevron.contentMode  = UIViewContentModeScaleAspectFit;
    _chevron.translatesAutoresizingMaskIntoConstraints = NO;
    [cv addSubview:_chevron];

    [NSLayoutConstraint activateConstraints:@[
        [_iconCircle.leadingAnchor  constraintEqualToAnchor:cv.leadingAnchor constant:16],
        [_iconCircle.centerYAnchor  constraintEqualToAnchor:cv.centerYAnchor],
        [_iconCircle.widthAnchor    constraintEqualToConstant:44],
        [_iconCircle.heightAnchor   constraintEqualToConstant:44],

        [_iconView.centerXAnchor constraintEqualToAnchor:_iconCircle.centerXAnchor],
        [_iconView.centerYAnchor constraintEqualToAnchor:_iconCircle.centerYAnchor],
        [_iconView.widthAnchor   constraintEqualToConstant:22],
        [_iconView.heightAnchor  constraintEqualToConstant:22],

        [_titleLabel.topAnchor     constraintEqualToAnchor:cv.topAnchor constant:16],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconCircle.trailingAnchor constant:14],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_chevron.leadingAnchor constant:-8],

        [_countLabel.topAnchor     constraintEqualToAnchor:_titleLabel.bottomAnchor constant:3],
        [_countLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_countLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],

        [_chevron.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-16],
        [_chevron.centerYAnchor  constraintEqualToAnchor:cv.centerYAnchor],
        [_chevron.widthAnchor    constraintEqualToConstant:14],
        [_chevron.heightAnchor   constraintEqualToConstant:14],
    ]];
}

- (void)configureWithArchive:(ArchiveModel *)archive colorIndex:(NSInteger)index {
    _iconCircle.backgroundColor = PPFolderColor(index);
    _titleLabel.text = archive.archiveTitle.length ? archive.archiveTitle : kLang(@"untitledArchive");
    _countLabel.text = [NSString stringWithFormat:@"%ld %@", (long)archive.detailsCount, kLang(@"ArchiveCardsCount")];
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:0.2 delay:0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.transform           = highlighted ? CGAffineTransformMakeScale(0.97, 0.97) : CGAffineTransformIdentity;
        self.contentView.alpha   = highlighted ? 0.85 : 1.0;
    } completion:nil];
}

@end

// ──────────────────────────────────────────────
#pragma mark - PPNewArchiveCell
// ──────────────────────────────────────────────

@interface PPNewArchiveCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *plusIcon;
@property (nonatomic, strong) UILabel     *label;
@end

@implementation PPNewArchiveCell

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) [self buildUI];
    return self;
}

- (void)buildUI {
    UIView *cv = self.contentView;
    cv.backgroundColor    = [AppPrimaryClr colorWithAlphaComponent:0.06];
    cv.layer.cornerRadius = 14;
    cv.layer.borderWidth  = 1.5;
    [cv pp_setBorderColor:[AppPrimaryClr colorWithAlphaComponent:0.30]];

    _plusIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"plus.circle.fill"]];
    _plusIcon.tintColor   = AppPrimaryClr;
    _plusIcon.contentMode = UIViewContentModeScaleAspectFit;
    _plusIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [cv addSubview:_plusIcon];

    _label = [UILabel new];
    _label.text      = kLang(@"addArchiveTitle");
    _label.font      = [GM boldFontWithSize:15];
    _label.textColor = AppPrimaryClr;
    _label.translatesAutoresizingMaskIntoConstraints = NO;
    [cv addSubview:_label];

    [NSLayoutConstraint activateConstraints:@[
        [_plusIcon.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:20],
        [_plusIcon.centerYAnchor constraintEqualToAnchor:cv.centerYAnchor],
        [_plusIcon.widthAnchor   constraintEqualToConstant:28],
        [_plusIcon.heightAnchor  constraintEqualToConstant:28],

        [_label.leadingAnchor  constraintEqualToAnchor:_plusIcon.trailingAnchor constant:12],
        [_label.centerYAnchor  constraintEqualToAnchor:cv.centerYAnchor],
        [_label.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-16],
    ]];
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:0.15 animations:^{
        self.contentView.backgroundColor = highlighted
            ? [AppPrimaryClr colorWithAlphaComponent:0.14]
            : [AppPrimaryClr colorWithAlphaComponent:0.06];
        self.transform = highlighted ? CGAffineTransformMakeScale(0.97, 0.97) : CGAffineTransformIdentity;
    }];
}

@end

// ──────────────────────────────────────────────
#pragma mark - ArchiveManagerVC
// ──────────────────────────────────────────────

typedef NS_ENUM(NSInteger, PPArchiveSection) {
    PPArchiveSectionNewButton = 0,
    PPArchiveSectionFolders   = 1,
};

@interface ArchiveManagerVC () <UICollectionViewDelegate, UICollectionViewDataSource>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray<ArchiveModel *> *archiveArray;
@property (nonatomic, strong) UIView  *headerCardView;
@property (nonatomic, strong) UILabel *birdInfoLabel;
@property (nonatomic, strong) UILabel *ringIdLabel;
@property (nonatomic, strong) UIView  *emptyStateView;
@property (nonatomic, strong) CAGradientLayer *headerGradient;
@property (nonatomic, strong) UIImpactFeedbackGenerator *haptic;

@end

@implementation ArchiveManagerVC

- (void)viewDidLoad {
    [super viewDidLoad];
    _haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [_haptic prepare];
    [self setupBaseUI];
    [self setupHeaderCard];
    [self setupCollectionView];
    [self setupEmptyState];
    [self loadArchivesData];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _headerGradient.frame = _headerCardView.bounds;
}

#pragma mark - Setup

- (void)setupBaseUI {
    self.view.backgroundColor = AppBackgroundClr;
    self.title = kLang(@"_archiveTitle");
    self.navigationController.navigationBar.prefersLargeTitles = NO;

    UIBarButtonItem *closeItem = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"xmark.circle.fill"]
                style:UIBarButtonItemStylePlain target:self action:@selector(dismissVC)];
    closeItem.tintColor = [UIColor secondaryLabelColor];
    self.navigationItem.leftBarButtonItem = closeItem;

    UIBarButtonItem *addItem = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"plus.circle.fill"]
                style:UIBarButtonItemStylePlain target:self action:@selector(addArchiveClicked)];
    addItem.tintColor = AppPrimaryClr;
    self.navigationItem.rightBarButtonItem = addItem;
}

- (void)setupHeaderCard {
    _headerCardView = [UIView new];
    _headerCardView.layer.cornerRadius = 18;
    _headerCardView.clipsToBounds = YES;
    _headerCardView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_headerCardView];

    // Gradient background
    _headerGradient = [CAGradientLayer layer];
    _headerGradient.colors = @[
        (id)[AppPrimaryClr colorWithAlphaComponent:0.90].CGColor,
        (id)[AppPrimaryClr colorWithAlphaComponent:0.65].CGColor,
    ];
    _headerGradient.startPoint = CGPointMake(0, 0);
    _headerGradient.endPoint   = CGPointMake(1, 1);
    [_headerCardView.layer insertSublayer:_headerGradient atIndex:0];

    // Decorative circle (top-right, partially clipped)
    UIView *decorCircle = [UIView new];
    decorCircle.backgroundColor    = [[UIColor whiteColor] colorWithAlphaComponent:0.12];
    decorCircle.layer.cornerRadius = 45;
    decorCircle.translatesAutoresizingMaskIntoConstraints = NO;
    [_headerCardView addSubview:decorCircle];

    // Icon circle
    UIView *iconBg = [UIView new];
    iconBg.backgroundColor    = [[UIColor whiteColor] colorWithAlphaComponent:0.25];
    iconBg.layer.cornerRadius = 24;
    iconBg.translatesAutoresizingMaskIntoConstraints = NO;
    [_headerCardView addSubview:iconBg];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"archivebox.fill"]];
    iconView.tintColor   = [UIColor whiteColor];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [iconBg addSubview:iconView];

    // Labels
    _birdInfoLabel = [UILabel new];
    _birdInfoLabel.font      = [GM boldFontWithSize:18];
    _birdInfoLabel.textColor = [UIColor whiteColor];
    _birdInfoLabel.text      = self.cardToArchive.CardTitle ?: @"";
    _birdInfoLabel.numberOfLines = 1;
    _birdInfoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_headerCardView addSubview:_birdInfoLabel];

    _ringIdLabel = [UILabel new];
    _ringIdLabel.font      = [GM MidFontWithSize:14];
    _ringIdLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.85];
    _ringIdLabel.text = [NSString stringWithFormat:@"%@: %@",
                         kLang(@"RingID"),
                         self.cardToArchive.RingID ?: @"–"];
    _ringIdLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_headerCardView addSubview:_ringIdLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_headerCardView.topAnchor      constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [_headerCardView.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor  constant:16],
        [_headerCardView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [_headerCardView.heightAnchor   constraintEqualToConstant:110],

        [decorCircle.trailingAnchor constraintEqualToAnchor:_headerCardView.trailingAnchor constant:25],
        [decorCircle.topAnchor      constraintEqualToAnchor:_headerCardView.topAnchor      constant:-25],
        [decorCircle.widthAnchor    constraintEqualToConstant:90],
        [decorCircle.heightAnchor   constraintEqualToConstant:90],

        [iconBg.leadingAnchor constraintEqualToAnchor:_headerCardView.leadingAnchor constant:20],
        [iconBg.centerYAnchor constraintEqualToAnchor:_headerCardView.centerYAnchor],
        [iconBg.widthAnchor   constraintEqualToConstant:48],
        [iconBg.heightAnchor  constraintEqualToConstant:48],

        [iconView.centerXAnchor constraintEqualToAnchor:iconBg.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconBg.centerYAnchor],
        [iconView.widthAnchor   constraintEqualToConstant:26],
        [iconView.heightAnchor  constraintEqualToConstant:26],

        [_birdInfoLabel.topAnchor      constraintEqualToAnchor:_headerCardView.topAnchor constant:30],
        [_birdInfoLabel.leadingAnchor  constraintEqualToAnchor:iconBg.trailingAnchor constant:16],
        [_birdInfoLabel.trailingAnchor constraintEqualToAnchor:_headerCardView.trailingAnchor constant:-20],

        [_ringIdLabel.topAnchor      constraintEqualToAnchor:_birdInfoLabel.bottomAnchor constant:5],
        [_ringIdLabel.leadingAnchor  constraintEqualToAnchor:_birdInfoLabel.leadingAnchor],
        [_ringIdLabel.trailingAnchor constraintEqualToAnchor:_birdInfoLabel.trailingAnchor],
    ]];
}

- (void)setupCollectionView {
    UICollectionViewCompositionalLayout *layout = [self createListLayout];

    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collectionView.delegate   = self;
    _collectionView.dataSource = self;
    _collectionView.backgroundColor = [UIColor clearColor];
    _collectionView.showsVerticalScrollIndicator = NO;
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;

    [_collectionView registerClass:[PPNewArchiveCell class]    forCellWithReuseIdentifier:kNewCellID];
    [_collectionView registerClass:[PPArchiveFolderCell class] forCellWithReuseIdentifier:kFolderCellID];

    [self.view addSubview:_collectionView];

    [NSLayoutConstraint activateConstraints:@[
        [_collectionView.topAnchor      constraintEqualToAnchor:_headerCardView.bottomAnchor constant:16],
        [_collectionView.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [_collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_collectionView.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (UICollectionViewCompositionalLayout *)createListLayout {
    return [[UICollectionViewCompositionalLayout alloc]
        initWithSectionProvider:^NSCollectionLayoutSection * _Nullable(
            NSInteger sectionIndex,
            id<NSCollectionLayoutEnvironment> _Nonnull env) {

        CGFloat h = (sectionIndex == PPArchiveSectionNewButton) ? 56 : 72;

        NSCollectionLayoutSize *itemSize =
            [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                          heightDimension:[NSCollectionLayoutDimension absoluteDimension:h]];
        NSCollectionLayoutItem *item = [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
        item.contentInsets = NSDirectionalEdgeInsetsMake(0, 16, 0, 16);

        NSCollectionLayoutSize *groupSize =
            [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                          heightDimension:[NSCollectionLayoutDimension absoluteDimension:h]];
        NSCollectionLayoutGroup *group =
            [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize subitems:@[item]];

        NSCollectionLayoutSection *section = [NSCollectionLayoutSection sectionWithGroup:group];
        section.interGroupSpacing = 10;
        section.contentInsets = NSDirectionalEdgeInsetsMake(0, 0, 12, 0);
        return section;
    }];
}

- (void)setupEmptyState {
    _emptyStateView = [UIView new];
    _emptyStateView.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyStateView.hidden = YES;
    [self.view addSubview:_emptyStateView];

    UIImageView *emptyIcon = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:@"archivebox"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:52
                                                                                 weight:UIImageSymbolWeightLight]]];
    emptyIcon.tintColor   = [UIColor tertiaryLabelColor];
    emptyIcon.contentMode = UIViewContentModeScaleAspectFit;
    emptyIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [_emptyStateView addSubview:emptyIcon];

    UILabel *emptyTitle = [UILabel new];
    emptyTitle.text          = kLang(@"archiveEmptyTitle");
    emptyTitle.font          = [GM boldFontWithSize:18];
    emptyTitle.textColor     = [UIColor secondaryLabelColor];
    emptyTitle.textAlignment = NSTextAlignmentCenter;
    emptyTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [_emptyStateView addSubview:emptyTitle];

    UILabel *emptyDesc = [UILabel new];
    emptyDesc.text          = kLang(@"PleaseAddNewArchive");
    emptyDesc.font          = [GM MidFontWithSize:14];
    emptyDesc.textColor     = [UIColor tertiaryLabelColor];
    emptyDesc.textAlignment = NSTextAlignmentCenter;
    emptyDesc.numberOfLines = 0;
    emptyDesc.translatesAutoresizingMaskIntoConstraints = NO;
    [_emptyStateView addSubview:emptyDesc];

    [NSLayoutConstraint activateConstraints:@[
        [_emptyStateView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyStateView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:40],
        [_emptyStateView.widthAnchor   constraintEqualToAnchor:self.view.widthAnchor constant:-60],

        [emptyIcon.topAnchor     constraintEqualToAnchor:_emptyStateView.topAnchor],
        [emptyIcon.centerXAnchor constraintEqualToAnchor:_emptyStateView.centerXAnchor],
        [emptyIcon.widthAnchor   constraintEqualToConstant:60],
        [emptyIcon.heightAnchor  constraintEqualToConstant:60],

        [emptyTitle.topAnchor      constraintEqualToAnchor:emptyIcon.bottomAnchor constant:14],
        [emptyTitle.leadingAnchor  constraintEqualToAnchor:_emptyStateView.leadingAnchor],
        [emptyTitle.trailingAnchor constraintEqualToAnchor:_emptyStateView.trailingAnchor],

        [emptyDesc.topAnchor      constraintEqualToAnchor:emptyTitle.bottomAnchor constant:6],
        [emptyDesc.leadingAnchor  constraintEqualToAnchor:_emptyStateView.leadingAnchor],
        [emptyDesc.trailingAnchor constraintEqualToAnchor:_emptyStateView.trailingAnchor],
        [emptyDesc.bottomAnchor   constraintEqualToAnchor:_emptyStateView.bottomAnchor],
    ]];
}

#pragma mark - Data

- (void)loadArchivesData {
    self.archiveArray = [AppData.UserArchivesDocs mutableCopy] ?: [NSMutableArray new];
    [self.collectionView reloadData];
    [self updateEmptyState];
    [self animateCellsEntrance];
}

- (void)updateEmptyState {
    BOOL empty = (self.archiveArray.count == 0);
    _emptyStateView.hidden  = !empty;
    _collectionView.hidden  = empty;
}

- (void)animateCellsEntrance {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSArray<UICollectionViewCell *> *cells = self.collectionView.visibleCells;
        for (NSInteger i = 0; i < (NSInteger)cells.count; i++) {
            UICollectionViewCell *c = cells[i];
            c.alpha     = 0;
            c.transform = CGAffineTransformMakeTranslation(0, 20);
            [UIView animateWithDuration:0.35
                                  delay:i * 0.06
                 usingSpringWithDamping:0.85
                  initialSpringVelocity:0.5
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                c.alpha     = 1;
                c.transform = CGAffineTransformIdentity;
            } completion:nil];
        }
    });
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 2;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    return (section == PPArchiveSectionNewButton) ? 1 : self.archiveArray.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                           cellForItemAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.section == PPArchiveSectionNewButton) {
        return [collectionView dequeueReusableCellWithReuseIdentifier:kNewCellID forIndexPath:indexPath];
    }

    PPArchiveFolderCell *cell =
        [collectionView dequeueReusableCellWithReuseIdentifier:kFolderCellID forIndexPath:indexPath];
    [cell configureWithArchive:self.archiveArray[indexPath.item] colorIndex:indexPath.item];
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView
    didSelectItemAtIndexPath:(NSIndexPath *)indexPath {

    [_haptic impactOccurred];

    if (indexPath.section == PPArchiveSectionNewButton) {
        [self addArchiveClicked];
        return;
    }

    ArchiveModel *selectedArchive = self.archiveArray[indexPath.item];
    [self confirmArchivingTo:selectedArchive];
}

#pragma mark - Business Logic (preserved exactly)

- (void)confirmArchivingTo:(ArchiveModel *)archive {
    NSString *title = kLang(@"title_ArchiveAlert");
    NSString *subtitle = [NSString stringWithFormat:@"%@ (%@) %@ (%@) %@",
                          kLang(@"subtitle1_ArchiveAlert"),
                          self.cardToArchive.CardTitle,
                          kLang(@"subtitle3_ArchiveAlert"),
                          archive.archiveTitle,
                          kLang(@"subtitle4_ArchiveAlert")];

    [PPAlertHelper showConfirmationIn:self
                                title:title
                             subtitle:subtitle
                        confirmButton:kLang(@"yes")
                         cancelButton:kLang(@"no")
                                 icon:nil
                         confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
        if (didConfirm) {
            [self performArchivingTo:archive];
        }
    } cancelBlock:^{}];
}

- (void)performArchivingTo:(ArchiveModel *)archive {
    [PPHUD showLoading];
    NSString *cardID    = self.cardToArchive.ID;
    NSString *archiveID = archive.ID;

    ArchivesManager *manager = [ArchivesManager shared];
    [manager removeArchiveDetailsByCardID:cardID completion:^(NSError * _Nullable error) {
        if (error) { [PPHUD dismiss]; return; }

        [manager addCard:cardID child:self.childToArchive toArchive:archiveID
                 ownerID:PPCurrentUser.ID completion:^(NSError * _Nullable error) {
            [PPHUD dismiss];
            if (!error) {
                [ArchivesManager.shared syncDetailsCountForArchiveID:archiveID];
                if (self.childToArchive) {
                    [ChildsDataManager syncDetailsCountForCageID:self.childToArchive.CageID completion:nil];
                    [self.delegate RemoveChild:self.childToArchive];
                }
                [self dismissViewControllerAnimated:YES completion:nil];
            }
        }];
    }];
}

#pragma mark - Actions

- (void)addArchiveClicked {
    [PPAlertHelper showTextFieldAlertIn:self
                                  title:kLang(@"addArchiveTitle")
                               subtitle:kLang(@"enterArchiveName")
                            placeholder:@""
                            initialText:nil
                            confirmText:kLang(@"save")
                             cancelText:kLang(@"cancel")
                             completion:^(NSString * _Nullable text, BOOL didConfirm) {
        if (didConfirm && text.length > 0) {
            [self createNewArchive:text];
        }
    }];
}

- (void)createNewArchive:(NSString *)title {
    [PPHUD showLoading];

    NSString *userID = PPCurrentUser.ID;
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"ddmmssSSS"];
    NSString *timestamp = [df stringFromDate:[NSDate date]];
    NSString *archiveID = [NSString stringWithFormat:@"ARC_%@_%@", userID, timestamp];

    NSDictionary *data = @{
        @"ID"             : archiveID,
        @"archiveTitle"   : title,
        @"archiveDate"    : [NSDate date],
        @"archiveOwnerID" : userID,
        @"CreateDate"     : [NSDate date],
        @"isDeleted"      : @0
    };

    [[[[FIRFirestore firestore] collectionWithPath:@"ArchiveCol"]
      documentWithPath:archiveID] setData:data completion:^(NSError * _Nullable error) {
        [PPHUD dismiss];
        if (!error) {
            [self loadArchivesData];
        }
    }];
}

- (void)dismissVC {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
