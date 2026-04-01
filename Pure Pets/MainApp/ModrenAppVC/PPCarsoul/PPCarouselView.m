//
//  PPCarouselView 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 27/12/2025.
//


#import "PPCarouselView.h"
#import "PPCarouselItem.h"
#import "PPCarouselCollectionCell.h"

@interface PPCarouselView () <UICollectionViewDelegate, UICollectionViewDataSource>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIPageControl *pageControl;
@property (nonatomic, strong) NSArray<PPCarouselItem *> *items;
@property (nonatomic, strong) NSTimer *autoScrollTimer;
@property (nonatomic, assign) BOOL userDragging;
@property (nonatomic, assign) NSInteger lastPageIndex;

@end

@implementation PPCarouselView

#pragma mark — Init

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {

        UICollectionViewCompositionalLayout *layout =
        [[UICollectionViewCompositionalLayout alloc]
         initWithSection:[self makeSection]];

        _collectionView = [[UICollectionView alloc]
                           initWithFrame:CGRectZero
                 collectionViewLayout:layout];
        _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
        _collectionView.delegate = self;
        _collectionView.dataSource = self;
        _collectionView.showsHorizontalScrollIndicator = NO;
        _collectionView.backgroundColor = UIColor.clearColor;
        _collectionView.layer.cornerRadius = PPCornersHome;

        // Shadow container (best practice: shadow outside, mask inside)
        UIView *shadowContainer = [UIView new];
        shadowContainer.translatesAutoresizingMaskIntoConstraints = NO;
        shadowContainer.backgroundColor = UIColor.clearColor;
        shadowContainer.layer.shadowColor = UIColor.blackColor.CGColor;
        shadowContainer.layer.shadowOpacity = 0.18;
        shadowContainer.layer.shadowRadius = 16;
        shadowContainer.layer.shadowOffset = CGSizeMake(0, 6);
        shadowContainer.layer.cornerRadius = PPCornersHome;

        // Move collectionView inside shadow container
        [self addSubview:shadowContainer];
        [shadowContainer addSubview:_collectionView];

        // Constraints for shadow container
        [NSLayoutConstraint activateConstraints:@[
            [shadowContainer.topAnchor constraintEqualToAnchor:self.topAnchor],
            [shadowContainer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [shadowContainer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [shadowContainer.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];

        // Constraints for collectionView inside shadow container
        [NSLayoutConstraint activateConstraints:@[
            [_collectionView.topAnchor constraintEqualToAnchor:shadowContainer.topAnchor],
            [_collectionView.leadingAnchor constraintEqualToAnchor:shadowContainer.leadingAnchor],
            [_collectionView.trailingAnchor constraintEqualToAnchor:shadowContainer.trailingAnchor],
            [_collectionView.bottomAnchor constraintEqualToAnchor:shadowContainer.bottomAnchor constant:-24]
        ]];
        
        
        
        // Mask only content, not shadow
        _collectionView.layer.masksToBounds = YES;

        _pageControl = [UIPageControl new];
        _pageControl.translatesAutoresizingMaskIntoConstraints = NO;
        _pageControl.currentPageIndicatorTintColor = AppPrimaryClr;
        _pageControl.pageIndicatorTintColor =
            [AppSecondaryTextClr colorWithAlphaComponent:0.25];
        _pageControl.allowsContinuousInteraction = YES; // iOS 14+
        _pageControl.backgroundStyle = UIPageControlBackgroundStyleMinimal;
        [shadowContainer addSubview:_pageControl];
        self.pageControl.hidesForSinglePage = YES;

        [NSLayoutConstraint activateConstraints:@[
            

            [self.pageControl.centerXAnchor
             constraintEqualToAnchor:shadowContainer.centerXAnchor],
            [self.pageControl.bottomAnchor constraintEqualToAnchor:shadowContainer.bottomAnchor constant:-8],
        ]];

        [shadowContainer bringSubviewToFront:self.pageControl];
        
    }
    return self;
}

#pragma mark — Layout

- (NSCollectionLayoutSection *)makeSection {
    NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                     heightDimension:
     [NSCollectionLayoutDimension fractionalHeightDimension:1.0]];

    NSCollectionLayoutItem *item =
    [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:itemSize
                                                  subitems:@[item]];

    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];

    section.orthogonalScrollingBehavior =
    UICollectionLayoutSectionOrthogonalScrollingBehaviorGroupPagingCentered;
    return section;
}

#pragma mark — Configure

- (void)configureWithItems:(NSArray<PPCarouselItem *> *)items {
    self.items = items.copy;
    self.pageControl.numberOfPages = items.count;
    self.pageControl.currentPage = 0;
    self.lastPageIndex = 0;
    [self.collectionView reloadData];

    if (items.count > 1) {
        [self startAutoScroll];
    }
}

#pragma mark — Auto Scroll

- (void)startAutoScroll {
    [self stopAutoScroll];
    if (self.items.count <= 1) return;

    self.autoScrollTimer =
    [NSTimer scheduledTimerWithTimeInterval:4.0
                                     target:self
                                   selector:@selector(autoScrollTick)
                                   userInfo:nil
                                    repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.autoScrollTimer forMode:NSRunLoopCommonModes];
}

- (void)stopAutoScroll {
    [self.autoScrollTimer invalidate];
    self.autoScrollTimer = nil;
}

- (void)autoScrollTick {
    if (self.userDragging || self.items.count == 0) return;
    NSInteger next = (self.pageControl.currentPage + 1) % self.items.count;
    NSIndexPath *ip = [NSIndexPath indexPathForItem:next inSection:0];
    [self.collectionView scrollToItemAtIndexPath:ip
                                atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                        animated:YES];
    [self animatePageIndicatorToIndex:next];
}

#pragma mark — UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    self.userDragging = YES;
    [self stopAutoScroll];
}


#pragma mark - Page Detection (Center Cell)

// Derive current page from center visible cell, not contentOffset
- (void)updatePageFromVisibleCenter {

    if (self.items.count == 0) return;

    CGPoint center =
    CGPointMake(self.collectionView.bounds.size.width * 0.5 +
                self.collectionView.contentOffset.x,
                self.collectionView.bounds.size.height * 0.5);

    NSIndexPath *centerIndexPath =
    [self.collectionView indexPathForItemAtPoint:center];

    if (!centerIndexPath) return;

    NSInteger page = centerIndexPath.item;

    if (page != self.lastPageIndex) {
        [self animatePageIndicatorToIndex:page];
    }
}

// Track page continuously as user scrolls, so indicator animates in real time.
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self updatePageFromVisibleCenter];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    self.userDragging = NO;
    [self updatePageFromVisibleCenter];
    [self startAutoScroll];
}

#pragma mark — UICollectionView DataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    return self.items.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {

    PPCarouselCollectionCell *cell =
    [collectionView dequeueReusableCellWithReuseIdentifier:@"PPCarouselCollectionCell"
                                              forIndexPath:indexPath];
    [cell configureWithCarouselItem:self.items[indexPath.item]];
    return cell;
}

#pragma mark — UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (self.onItemTap) {
        self.onItemTap(self.items[indexPath.item]);
    }
}

#pragma mark - Page Indicator Animation

- (void)animatePageIndicatorToIndex:(NSInteger)index {

    if (index < 0 ||
        index >= self.pageControl.numberOfPages ||
        index == self.lastPageIndex) {
        return;
    }

    // Phase 1: stretch toward direction
    CGFloat direction = (index > self.lastPageIndex) ? 1.0 : -1.0;

    [UIView animateWithDuration:0.18
                          delay:0
         usingSpringWithDamping:0.75
          initialSpringVelocity:0.6
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{

        // Horizontal stretch
        self.pageControl.transform =
        CGAffineTransformMakeScale(1.25, 0.9);

        // Slight directional nudge
        self.pageControl.transform =
        CGAffineTransformTranslate(self.pageControl.transform,
                                   direction * 4.0,
                                   0);

        self.pageControl.alpha = 0.75;

    } completion:^(BOOL finished) {

        // Update page at peak stretch
        self.pageControl.currentPage = index;
        self.lastPageIndex = index;

        // Phase 2: snap back
        [UIView animateWithDuration:0.22
                              delay:0
             usingSpringWithDamping:0.9
              initialSpringVelocity:0.4
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{

            self.pageControl.transform = CGAffineTransformIdentity;
            self.pageControl.alpha = 1.0;

        } completion:nil];
    }];
}

@end
