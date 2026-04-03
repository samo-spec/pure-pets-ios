//
//  PPCarouselView 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 27/12/2025.
//


#import "PPCarouselView.h"
#import "PPCarouselItem.h"
#import "PPCarouselCollectionCell.h"

/// Multiplier for infinite-loop illusion (real items × this = virtual items)
static const NSInteger kLoopMultiplier = 200;

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

        UICollectionViewFlowLayout *flow = [[UICollectionViewFlowLayout alloc] init];
        flow.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        flow.minimumLineSpacing = 12.0;

        _collectionView = [[UICollectionView alloc]
                           initWithFrame:CGRectZero
                 collectionViewLayout:flow];
        _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
        _collectionView.delegate = self;
        _collectionView.dataSource = self;
        _collectionView.showsHorizontalScrollIndicator = NO;
        _collectionView.backgroundColor = UIColor.clearColor;
        _collectionView.clipsToBounds = NO;
        _collectionView.decelerationRate = UIScrollViewDecelerationRateFast;

        [_collectionView registerClass:PPCarouselCollectionCell.class
            forCellWithReuseIdentifier:@"PPCarouselCollectionCell"];

        // Shadow container
        UIView *shadowContainer = [UIView new];
        shadowContainer.translatesAutoresizingMaskIntoConstraints = NO;
        shadowContainer.backgroundColor = UIColor.clearColor;
        shadowContainer.clipsToBounds = NO;

        [self addSubview:shadowContainer];
        [shadowContainer addSubview:_collectionView];

        [NSLayoutConstraint activateConstraints:@[
            [shadowContainer.topAnchor constraintEqualToAnchor:self.topAnchor],
            [shadowContainer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [shadowContainer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [shadowContainer.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];

        [NSLayoutConstraint activateConstraints:@[
            [_collectionView.topAnchor constraintEqualToAnchor:shadowContainer.topAnchor],
            [_collectionView.leadingAnchor constraintEqualToAnchor:shadowContainer.leadingAnchor],
            [_collectionView.trailingAnchor constraintEqualToAnchor:shadowContainer.trailingAnchor],
            [_collectionView.bottomAnchor constraintEqualToAnchor:shadowContainer.bottomAnchor constant:-24],
        ]];

        _pageControl = [UIPageControl new];
        _pageControl.translatesAutoresizingMaskIntoConstraints = NO;
        _pageControl.currentPageIndicatorTintColor = AppPrimaryClr;
        _pageControl.pageIndicatorTintColor =
            [AppSecondaryTextClr colorWithAlphaComponent:0.25];
        _pageControl.allowsContinuousInteraction = YES;
        _pageControl.backgroundStyle = UIPageControlBackgroundStyleMinimal;
        _pageControl.hidesForSinglePage = YES;
        [shadowContainer addSubview:_pageControl];

        [NSLayoutConstraint activateConstraints:@[
            [_pageControl.centerXAnchor constraintEqualToAnchor:shadowContainer.centerXAnchor],
            [_pageControl.bottomAnchor constraintEqualToAnchor:shadowContainer.bottomAnchor constant:-4],
        ]];

        [shadowContainer bringSubviewToFront:_pageControl];
    }
    return self;
}

#pragma mark — Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    UICollectionViewFlowLayout *flow = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
    CGFloat peekInset = 24.0;
    CGFloat spacing = flow.minimumLineSpacing;
    CGFloat itemWidth = self.collectionView.bounds.size.width - (peekInset * 2);
    CGFloat itemHeight = self.collectionView.bounds.size.height;
    if (itemWidth > 0 && itemHeight > 0) {
        flow.itemSize = CGSizeMake(itemWidth, itemHeight);
        flow.sectionInset = UIEdgeInsetsMake(0, peekInset, 0, peekInset);
    }
    (void)spacing;
}

#pragma mark — Infinite Loop Helpers

- (NSInteger)realIndexForIndexPath:(NSIndexPath *)indexPath {
    if (self.items.count == 0) return 0;
    return indexPath.item % self.items.count;
}

- (NSInteger)middleStartIndex {
    if (self.items.count == 0) return 0;
    NSInteger total = self.items.count * kLoopMultiplier;
    NSInteger middle = total / 2;
    return middle - (middle % self.items.count);
}

- (void)centerToMiddleIfNeeded {
    if (self.items.count <= 1) return;
    NSInteger total = self.items.count * kLoopMultiplier;
    NSInteger current = [self currentVirtualIndex];
    // Re-center when near edges
    if (current < self.items.count * 2 || current > total - self.items.count * 2) {
        NSInteger realIdx = current % self.items.count;
        NSInteger newIndex = [self middleStartIndex] + realIdx;
        [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:newIndex inSection:0]
                                    atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                            animated:NO];
    }
}

- (NSInteger)currentVirtualIndex {
    CGFloat centerX = self.collectionView.contentOffset.x + self.collectionView.bounds.size.width * 0.5;
    NSIndexPath *ip = [self.collectionView indexPathForItemAtPoint:CGPointMake(centerX, self.collectionView.bounds.size.height * 0.5)];
    return ip ? ip.item : 0;
}

#pragma mark — Configure

- (void)configureWithItems:(NSArray<PPCarouselItem *> *)items {
    self.items = items.copy;
    self.pageControl.numberOfPages = items.count;
    self.pageControl.currentPage = 0;
    self.lastPageIndex = 0;
    [self.collectionView reloadData];

    if (items.count > 0) {
        [self.collectionView layoutIfNeeded];
        NSInteger startIndex = [self middleStartIndex];
        [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:startIndex inSection:0]
                                    atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                            animated:NO];
    }

    if (items.count > 1) {
        [self startAutoScroll];
    }
}

#pragma mark — Auto Scroll

- (void)startAutoScroll {
    [self stopAutoScroll];
    if (self.items.count <= 1) return;

    __weak typeof(self) weakSelf = self;
    self.autoScrollTimer =
    [NSTimer scheduledTimerWithTimeInterval:4.0
                                    repeats:YES
                                      block:^(NSTimer *timer) {
        [weakSelf autoScrollTick];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.autoScrollTimer forMode:NSRunLoopCommonModes];
}

- (void)stopAutoScroll {
    [self.autoScrollTimer invalidate];
    self.autoScrollTimer = nil;
}

- (void)autoScrollTick {
    if (self.userDragging || self.items.count == 0) return;
    NSInteger nextVirtual = [self currentVirtualIndex] + 1;
    NSIndexPath *ip = [NSIndexPath indexPathForItem:nextVirtual inSection:0];
    [self.collectionView scrollToItemAtIndexPath:ip
                                atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                        animated:YES];
    NSInteger realIdx = nextVirtual % self.items.count;
    [self animatePageIndicatorToIndex:realIdx];
}

#pragma mark — UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    self.userDragging = YES;
    [self stopAutoScroll];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self applyParallaxAndScale];
    [self updatePageFromVisibleCenter];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    self.userDragging = NO;
    [self centerToMiddleIfNeeded];
    [self snapToNearestItem];
    [self startAutoScroll];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [self centerToMiddleIfNeeded];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        self.userDragging = NO;
        [self snapToNearestItem];
        [self startAutoScroll];
    }
}

#pragma mark — Snap & Parallax

- (void)snapToNearestItem {
    CGFloat centerX = self.collectionView.contentOffset.x + self.collectionView.bounds.size.width * 0.5;
    NSIndexPath *ip = [self.collectionView indexPathForItemAtPoint:CGPointMake(centerX, self.collectionView.bounds.size.height * 0.5)];
    if (ip) {
        [self.collectionView scrollToItemAtIndexPath:ip
                                    atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                            animated:YES];
    }
}

- (void)applyParallaxAndScale {
    CGFloat centerX = self.collectionView.contentOffset.x + self.collectionView.bounds.size.width * 0.5;

    for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
        CGFloat cellCenterX = cell.center.x;
        CGFloat distance = fabs(centerX - cellCenterX);
        CGFloat maxDist = self.collectionView.bounds.size.width * 0.6;

        // Scale: 1.0 for center, 0.92 for edges
        CGFloat normalizedDist = MIN(distance / maxDist, 1.0);
        CGFloat scale = 1.0 - (normalizedDist * 0.08);
        cell.transform = CGAffineTransformMakeScale(scale, scale);

        // Alpha: 1.0 center, 0.6 edges
        cell.alpha = 1.0 - (normalizedDist * 0.4);

        // Shadow on focused cell
        if (normalizedDist < 0.3) {
            cell.layer.shadowColor = UIColor.blackColor.CGColor;
            cell.layer.shadowOpacity = 0.18;
            cell.layer.shadowRadius = 16;
            cell.layer.shadowOffset = CGSizeMake(0, 6);
        } else {
            cell.layer.shadowOpacity = 0.0;
        }
    }
}

#pragma mark - Page Detection

- (void)updatePageFromVisibleCenter {
    if (self.items.count == 0) return;
    NSInteger virtualIdx = [self currentVirtualIndex];
    NSInteger page = virtualIdx % self.items.count;
    if (page != self.lastPageIndex) {
        [self animatePageIndicatorToIndex:page];
    }
}

#pragma mark — UICollectionView DataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    if (self.items.count <= 1) return self.items.count;
    return self.items.count * kLoopMultiplier;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {

    PPCarouselCollectionCell *cell =
    [collectionView dequeueReusableCellWithReuseIdentifier:@"PPCarouselCollectionCell"
                                              forIndexPath:indexPath];
    NSInteger realIdx = [self realIndexForIndexPath:indexPath];
    [cell configureWithCarouselItem:self.items[realIdx]];
    return cell;
}

#pragma mark — UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (self.onItemTap) {
        NSInteger realIdx = [self realIndexForIndexPath:indexPath];
        self.onItemTap(self.items[realIdx]);
    }
}

#pragma mark - Page Indicator Animation

- (void)animatePageIndicatorToIndex:(NSInteger)index {

    if (index < 0 ||
        index >= self.pageControl.numberOfPages ||
        index == self.lastPageIndex) {
        return;
    }

    CGFloat direction = (index > self.lastPageIndex) ? 1.0 : -1.0;
    // Handle wrap-around: 0→last or last→0
    if (self.lastPageIndex == 0 && index == self.pageControl.numberOfPages - 1) direction = -1.0;
    if (self.lastPageIndex == self.pageControl.numberOfPages - 1 && index == 0) direction = 1.0;

    [UIView animateWithDuration:0.18
                          delay:0
         usingSpringWithDamping:0.75
          initialSpringVelocity:0.6
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.pageControl.transform =
        CGAffineTransformTranslate(
            CGAffineTransformMakeScale(1.2, 0.88),
            direction * 4.0, 0);
        self.pageControl.alpha = 0.75;
    } completion:^(BOOL finished) {
        self.pageControl.currentPage = index;
        self.lastPageIndex = index;

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

- (void)dealloc {
    [self stopAutoScroll];
}

@end
