//
//  PPCenteredSelectorView.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 08/12/2025.
//

#import "PPCenteredSelectorView.h"
#import "MainKindsModel.h"


// Cell ID
static NSString * const kPPSelectorCellId       = @"PPSelectorCellId";
// Insets for the whole carousel
static const CGFloat kPPSelectorHorizontalInset = 8.0;

// Center/normal sizes for the carousel layout
static const CGFloat kPPCenterCellWidth        = 120.0;
static const CGFloat kPPCenterCellHeight       = 48.0;
static const CGFloat kPPNormalCellWidth        =  48.0;
static const CGFloat kPPNormalCellHeight       = 48.0;

#pragma mark - Cell

@interface PPSelectorCell : UICollectionViewCell
@property (nonatomic, strong) UIButton    *container;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel     *titleLabel;
@property (nonatomic, assign) BOOL isSelectedCell;

@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *selectedConstraints;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *normalConstraints;

-(void)updateSelectedState:(BOOL)selected;
@end

@implementation PPSelectorCell

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {

        self.contentView.clipsToBounds = NO;
        self.backgroundColor = UIColor.clearColor;

        UIButtonConfiguration *config;
        if (@available(iOS 26.0, *)) {
            config = [UIButtonConfiguration glassButtonConfiguration];
        } else {
            config = [UIButtonConfiguration plainButtonConfiguration];
        }
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.background.backgroundColor = UIColor.clearColor;

        _container = [UIButton buttonWithType:UIButtonTypeSystem];
        _container.translatesAutoresizingMaskIntoConstraints = NO;
        _container.userInteractionEnabled = NO; // taps handled via carousel paginator
        _container.configuration = config;
        [self.contentView addSubview:_container];

        [NSLayoutConstraint activateConstraints:@[
            [_container.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:0],
            [_container.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:0],
            [_container.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [_container.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        ]];

        _iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconView.contentMode = UIViewContentModeScaleAspectFit;

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [GM MidFontWithSize:15];
        _titleLabel.textColor = UIColor.labelColor;

        [_container addSubview:_iconView];
        [_container addSubview:_titleLabel];

        // Selected state constraints
        NSLayoutConstraint *iconLeading = [_iconView.leadingAnchor constraintEqualToAnchor:_container.leadingAnchor constant:8];
        NSLayoutConstraint *iconCenterY = [_iconView.centerYAnchor constraintEqualToAnchor:_container.centerYAnchor];
        NSLayoutConstraint *iconWidth = [_iconView.widthAnchor constraintEqualToConstant:30];
        NSLayoutConstraint *iconHeight = [_iconView.heightAnchor constraintEqualToConstant:30];

        NSLayoutConstraint *titleLeading = [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:8];
        NSLayoutConstraint *titleTrailing = [_titleLabel.trailingAnchor constraintEqualToAnchor:_container.trailingAnchor constant:-8];
        NSLayoutConstraint *titleCenterY = [_titleLabel.centerYAnchor constraintEqualToAnchor:_container.centerYAnchor];

        self.selectedConstraints = @[iconLeading, iconCenterY, iconWidth, iconHeight, titleLeading, titleTrailing, titleCenterY];

        // Normal state constraints
        NSLayoutConstraint *iconCenterXNormal = [_iconView.centerXAnchor constraintEqualToAnchor:_container.centerXAnchor];
        NSLayoutConstraint *iconCenterYNormal = [_iconView.centerYAnchor constraintEqualToAnchor:_container.centerYAnchor];
        NSLayoutConstraint *iconWidthNormal = [_iconView.widthAnchor constraintEqualToConstant:24];
        NSLayoutConstraint *iconHeightNormal = [_iconView.heightAnchor constraintEqualToConstant:24];

        self.normalConstraints = @[iconCenterXNormal, iconCenterYNormal, iconWidthNormal, iconHeightNormal];

        // Activate normal constraints by default
        [NSLayoutConstraint activateConstraints:self.normalConstraints];

        // Title hidden by default
        self.titleLabel.alpha = 0.0;
    }
    return self;
}

-(void)updateSelectedState:(BOOL)selected
{
    if (selected) {
        [NSLayoutConstraint deactivateConstraints:self.normalConstraints];
        [NSLayoutConstraint activateConstraints:self.selectedConstraints];

        [UIView animateWithDuration:0.25 animations:^{
            self.titleLabel.alpha = 1.0;
        }];
    } else {
        [NSLayoutConstraint deactivateConstraints:self.selectedConstraints];
        [NSLayoutConstraint activateConstraints:self.normalConstraints];

        [UIView animateWithDuration:0.25 animations:^{
            self.titleLabel.alpha = 0.0;
        }];
    }
}

-(void)prepareForReuse
{
    [super prepareForReuse];
    [self updateSelectedState:NO];
}
@end

#pragma mark - View

@interface PPCenteredSelectorView () <
    YTScaledCenterCarouselPaginatorDelegate,
    UICollectionViewDataSource
>

@property (nonatomic, strong, readwrite) UICollectionView *collectionView;
@property (nonatomic, strong) YTScaledCenterCarouselLayout   *carouselLayout;
@property (nonatomic, strong) YTScaledCenterCarouselPaginator *paginator;
@property (nonatomic, strong) UIImpactFeedbackGenerator      *haptic;

@end

@implementation PPCenteredSelectorView

#pragma mark - Init

- (instancetype)initWithItems:(NSArray<MainKindsModel *> *)items {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;

    _items = items ?: @[];
    _selectedIndex = 5;
    _haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];

    [self setupCollectionView];

    return self;
}

#pragma mark - Setup

- (void)setupCollectionView {
    self.translatesAutoresizingMaskIntoConstraints = NO;

    // Scaled center carousel layout
    self.carouselLayout = [YTScaledCenterCarouselLayout new];
    self.carouselLayout.centerCellWidth  = kPPCenterCellWidth;
    self.carouselLayout.centerCellHeight = kPPCenterCellHeight;
    self.carouselLayout.normalCellWidth  = kPPNormalCellWidth;
    self.carouselLayout.normalCellHeight = kPPNormalCellHeight;
    self.carouselLayout.collectionView.contentInset = UIEdgeInsetsMake(0,
                                                                       kPPSelectorHorizontalInset,
                                                                       0,
                                                                       kPPSelectorHorizontalInset);

    UICollectionView *cv =
        [[UICollectionView alloc] initWithFrame:CGRectZero
                           collectionViewLayout:self.carouselLayout];
    cv.translatesAutoresizingMaskIntoConstraints = NO;
    cv.backgroundColor = UIColor.clearColor;
    cv.showsHorizontalScrollIndicator = NO;
    cv.decelerationRate = UIScrollViewDecelerationRateFast;
    cv.dataSource = self;
    if ([cv respondsToSelector:@selector(setSemanticContentAttribute:)]) {
        cv.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    }

    [cv registerClass:[PPSelectorCell class]
forCellWithReuseIdentifier:kPPSelectorCellId];

    [self addSubview:cv];
    self.collectionView = cv;

    [NSLayoutConstraint activateConstraints:@[
        [cv.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [cv.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [cv.topAnchor constraintEqualToAnchor:self.topAnchor],
        [cv.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    ]];

    // Attach paginator as delegate/behavior of the carousel
    self.paginator = [[YTScaledCenterCarouselPaginator alloc] initWithCollectionView:cv
                                                                            delegate:self];
    self.paginator.selectedIndex = self.selectedIndex;

    // Initial reload/selection on next runloop to ensure layout/bounds are set
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.collectionView reloadData];
        [self centerCurrentIndexWithoutNotifying];
    });
}

#pragma mark - Public reload

- (void)reloadWithItems:(NSArray<MainKindsModel *> *)items
         preselectIndex:(NSUInteger)index {
    self.items = items ?: @[];

    if (self.items.count == 0) {
        self.selectedIndex = 0;
        self.paginator.selectedIndex = 0;
        [self.collectionView reloadData];
        return;
    }

    if (index >= self.items.count) {
        index = 0;
    }
    self.selectedIndex = index;
    self.paginator.selectedIndex = index;

    // Compute proposed offset so the selected item starts centered
    NSIndexPath *ip = [NSIndexPath indexPathForItem:index inSection:0];
    UICollectionViewLayoutAttributes *attrs =
        [self.carouselLayout layoutAttributesForItemAtIndexPath:ip];

    if (attrs) {
        CGFloat centerX = attrs.center.x;
        CGFloat offsetX = centerX - CGRectGetWidth(self.collectionView.bounds) / 2.0;
        self.carouselLayout.proposedContentOffset = CGPointMake(MAX(offsetX, 0.0), 0.0);
    }

    [self.collectionView reloadData];
}

#pragma mark - Helpers

- (void)configureCell:(PPSelectorCell *)cell atIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.items.count) return;

    MainKindsModel *kind = self.items[index];
    NSString *title = kind.KindName ?: kind.KindNameEn ?: kind.KindNameAr ?: @"-";

    cell.titleLabel.text = title;
    cell.iconView.image  = PPSYSImage(kind.KindIconName) ?: PPImage(kind.KindIconName);

    BOOL selected = (index == (NSInteger)self.selectedIndex);

    UIButtonConfiguration *config;
    if (cell.container.configuration) {
        config = cell.container.configuration;
    } else {
        config = [UIButtonConfiguration plainButtonConfiguration];
    }
    config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;

    if (selected) {
        config.background.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:1.2];
        cell.titleLabel.textColor = UIColor.whiteColor;
        cell.iconView.tintColor   = UIColor.whiteColor;
        cell.titleLabel.font      = [GM boldFontWithSize:15];
    } else {
        config.background.backgroundColor = UIColor.clearColor;
        cell.titleLabel.textColor = UIColor.clearColor;
        cell.iconView.tintColor   = AppPrimaryClr;
        cell.titleLabel.font      = [GM MidFontWithSize:15];
    }

    cell.container.configuration = config;

    [cell updateSelectedState:selected];
}

- (void)updateVisibleCellsSelectionAppearance {
    for (NSIndexPath *ip in self.collectionView.indexPathsForVisibleItems) {
        PPSelectorCell *cell =
            (PPSelectorCell *)[self.collectionView cellForItemAtIndexPath:ip];
        if (!cell) continue;
        [self configureCell:cell atIndex:ip.item];
    }
}

- (void)centerCurrentIndexWithoutNotifying {
    if (self.items.count == 0) return;
    if (self.selectedIndex >= self.items.count) self.selectedIndex = 0;

    // Set paginator state; it will center the cell on next layout pass.
    self.paginator.selectedIndex = self.selectedIndex;
}

- (void)notifyDelegateForSelectionChange {
    if (self.items.count == 0) return;
    if (self.selectedIndex >= self.items.count) return;

    if ([self.delegate respondsToSelector:@selector(selectorDidSelectIndex:item:)]) {
        [self.delegate selectorDidSelectIndex:(NSInteger)self.selectedIndex
                                         item:self.items[self.selectedIndex]];
    }
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    return self.items.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                          cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PPSelectorCell *cell =
        [collectionView dequeueReusableCellWithReuseIdentifier:kPPSelectorCellId
                                                  forIndexPath:indexPath];
    [self configureCell:cell atIndex:indexPath.item];
    return cell;
}

#pragma mark - YTScaledCenterCarouselDataSource

// Property is declared in header and synthesized automatically.
// Paginator reads/writes this selectedIndex.

#pragma mark - YTScaledCenterCarouselPaginatorDelegate

// Called on tap selection and also when paginator snaps to a new center.
- (void)carousel:(UICollectionView *)collectionView
didSelectElementAtIndex:(NSUInteger)selectedIndex {

    if (selectedIndex == self.selectedIndex) {
        // No-op: same element
        return;
    }

    self.selectedIndex = selectedIndex;
    self.paginator.selectedIndex = selectedIndex;

    [self.haptic impactOccurred];
    [self updateVisibleCellsSelectionAppearance];
    [self notifyDelegateForSelectionChange];
}

// Optional callback: you can react to scroll+snap changes.
// Here we treat it as “drag changed selection” if needed.
- (void)carousel:(UICollectionView *)collectionView
didScrollToVisibleCells:(NSArray<NSIndexPath *> *)indexPathes {

    // Paginator keeps selectedIndex in sync; we just update visuals.
    [self updateVisibleCellsSelectionAppearance];
    // If selection changed due to snapping, you can also notify delegate here.
    [self notifyDelegateForSelectionChange];
}

@end
