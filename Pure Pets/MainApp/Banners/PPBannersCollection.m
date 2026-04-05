//
//  PPBannersCollection 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 08/09/2025.
//


//
//  PPBannersCollection.m
//  PurePets
//


#import "PPBannersCollection.h"
#import "PPBannerCell.h"
@class PPBannerCell;


static NSString * const kReuseBannerCell = @"PPBannerCell";

@interface PPBannersCollection () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout,BannerTapsCellDelegate>
@property (nonatomic, strong) NSTimer *autoScrollTimer;
@property (nonatomic, strong) UIView *collectionShadowContainer;
@property (nonatomic, strong) UIButton *pageControlGlassButton;
@end

@implementation PPBannersCollection


- (void)layoutSubviews {
    [super layoutSubviews];
    [self bringSubviewToFront:self.pageControl];
    self.collectionShadowContainer.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.collectionShadowContainer.bounds cornerRadius:PPNewCorner].CGPath;
}



- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat pageWidth = MAX(scrollView.bounds.size.width, 1);
    NSInteger page = (NSInteger)llround(scrollView.contentOffset.x / pageWidth);
    page = MAX(0, MIN(page, (NSInteger)self.pageControl.numberOfPages - 1));
    self.pageControl.currentPage = page;
}



- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window) {
        [self startAutoScroll];
    } else {
        [self stopAutoScroll];
    }
}

// If the interval changes later, restart timer
- (void)setAutoScrollInterval:(NSTimeInterval)autoScrollInterval {
    _autoScrollInterval = autoScrollInterval;
    [self startAutoScroll];
}

- (void)startAutoScroll {
    [self stopAutoScroll];
    if (self.autoScrollInterval <= 0 || self.banners.count <= 1) return;

    // Use a timer and add it to the run loop in common modes,
    // so it still fires even when the scroll view is not in default mode.
    self.autoScrollTimer = [NSTimer timerWithTimeInterval:self.autoScrollInterval
                                                   target:self
                                                 selector:@selector(scrollToNext)
                                                 userInfo:nil
                                                  repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.autoScrollTimer forMode:NSRunLoopCommonModes];
}

- (void)stopAutoScroll {
    [self.autoScrollTimer invalidate];
    self.autoScrollTimer = nil;
}


- (void)setBanners:(NSArray<PPBannerViewModel *> *)banners {
    _banners = [banners copy];
    self.pageControl.numberOfPages = _banners.count;
    self.pageControl.currentPage = 0;
    // Reset position & reload
    [self.collectionView setContentOffset:CGPointZero animated:NO];
    [self.collectionView reloadData];

    // If you auto-scroll, restart so timing aligns with new data
    [self startAutoScroll];

    // Make sure the dots are on top
    [self bringSubviewToFront:self.pageControl];
}


- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self stopAutoScroll];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        // Resume after a small delay so it doesn't fight the user
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self startAutoScroll];
        });
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    NSInteger page = (NSInteger)round(scrollView.contentOffset.x / MAX(scrollView.bounds.size.width, 1));
    self.pageControl.currentPage = page;

    // Resume auto scroll after user stops
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self startAutoScroll];
    });
}

-(instancetype)init
{
    self = [super init];
    if (self) {
        self.banners = @[];
        [self setupCollectionView];
        [self setupPageControl];
    }
    return self;
}

- (instancetype)initWithBanners:(NSArray<PPBannerViewModel *> *)banners {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.banners = banners;
        [self setupCollectionView];
        [self setupPageControl];
    }
    return self;
}


#pragma mark - Setup

- (void)setupCollectionView {
    self.collectionShadowContainer = [[UIView alloc] initWithFrame:CGRectZero];
    self.collectionShadowContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionShadowContainer.layer.shadowColor = UIColor.blackColor.CGColor;
    self.collectionShadowContainer.layer.shadowOpacity = 0.18;
    self.collectionShadowContainer.layer.shadowRadius = 10;
    self.collectionShadowContainer.layer.shadowOffset = CGSizeMake(0, 6);
    self.collectionShadowContainer.layer.cornerRadius = PPNewCorner;

    [self addSubview:self.collectionShadowContainer];

    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumLineSpacing = 0;

    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _collectionView.pagingEnabled = YES;
    _collectionView.showsHorizontalScrollIndicator = NO;
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    //_collectionView.backgroundColor = GM.AppForegroundColor;
    // In HomeViewController.m (where you create the collection view)
    [self.collectionView registerClass:[PPBannerCell class] forCellWithReuseIdentifier:kReuseBannerCell];
    _collectionView.layer.cornerRadius = PPNewCorner;
    _collectionView.layer.masksToBounds = YES;

    [self.collectionShadowContainer addSubview:_collectionView];

    [NSLayoutConstraint activateConstraints:@[
        [self.collectionShadowContainer.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.collectionShadowContainer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.collectionShadowContainer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.collectionShadowContainer.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [_collectionView.topAnchor constraintEqualToAnchor:self.collectionShadowContainer.topAnchor],
        [_collectionView.leadingAnchor constraintEqualToAnchor:self.collectionShadowContainer.leadingAnchor],
        [_collectionView.trailingAnchor constraintEqualToAnchor:self.collectionShadowContainer.trailingAnchor],
        [_collectionView.bottomAnchor constraintEqualToAnchor:self.collectionShadowContainer.bottomAnchor],
    ]];
  

}

- (void)setupPageControl
{
    // =========================
    // Glass button container
    // =========================
    self.pageControlGlassButton = [UIButton new];
    self.pageControlGlassButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.pageControlGlassButton.userInteractionEnabled = NO;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *cfg;
        
        if (@available(iOS 26.0, *)) {
            cfg = [UIButtonConfiguration filledButtonConfiguration];
        } else {
            cfg = [UIButtonConfiguration filledButtonConfiguration];
        }
        cfg.baseBackgroundColor = UIColor.clearColor;
        cfg.background.backgroundColor = UIColor.clearColor;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 10, 6, 10);
        self.pageControlGlassButton.configuration = cfg;
    } else {
        self.pageControlGlassButton.backgroundColor =
        [[UIColor blackColor] colorWithAlphaComponent:0.25];
        self.pageControlGlassButton.layer.cornerRadius = 12;
    }

    // Subtle elevation
    self.pageControlGlassButton.layer.shadowColor = UIColor.blackColor.CGColor;
    self.pageControlGlassButton.layer.shadowOpacity = 0.18;
    self.pageControlGlassButton.layer.shadowRadius = 6;
    self.pageControlGlassButton.layer.shadowOffset = CGSizeMake(0, 3);

    [self.collectionShadowContainer addSubview:self.pageControlGlassButton];

    // =========================
    // Ellipse page control
    // =========================
    self.pageControl = [[EllipsePageControl alloc] init];
    self.pageControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.pageControl.userInteractionEnabled = NO;
 
     self.pageControl.currentPage = 0;

    [self.pageControlGlassButton addSubview:self.pageControl];

    // =========================
    // Constraints
    // =========================
    [NSLayoutConstraint activateConstraints:@[
        [self.pageControlGlassButton.centerXAnchor constraintEqualToAnchor:self.collectionShadowContainer.centerXAnchor],
        [self.pageControlGlassButton.bottomAnchor constraintEqualToAnchor:self.collectionShadowContainer.bottomAnchor constant:-0],
        [self.pageControlGlassButton.widthAnchor constraintEqualToConstant:80],
        [self.pageControlGlassButton.heightAnchor constraintEqualToConstant:28],

        
        
        [self.pageControl.centerXAnchor constraintEqualToAnchor:self.pageControlGlassButton.centerXAnchor],
        [self.pageControl.centerYAnchor constraintEqualToAnchor:self.pageControlGlassButton.centerYAnchor],
         
       
    ]];
}

// In -scrollToNext
- (void)scrollToNext {
    if (self.banners.count == 0) return;

    CGFloat pageWidth = self.collectionView.bounds.size.width;
    NSInteger currentPage = (NSInteger)round(self.collectionView.contentOffset.x / MAX(pageWidth, 1));
    NSInteger nextPage = (currentPage + 1) % self.banners.count;
    CGPoint target = CGPointMake(nextPage * pageWidth, 0);

    if (self.autoScrollStyle == PPBannersAutoScrollStyleFade) {
        // Cross-dissolve while jumping to target without “scroll” animation
        [UIView transitionWithView:self.collectionView
                          duration:self.autoScrollAnimationDuration
                           options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent
                        animations:^{
                            [self.collectionView setContentOffset:target animated:NO];
                        } completion:nil];
    } else {
        // Slide (custom speed)
        [UIView animateWithDuration:self.autoScrollAnimationDuration
                              delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             self.collectionView.contentOffset = target;
                         } completion:nil];
    }

    self.pageControl.currentPage = nextPage;
}

#pragma mark - UICollectionView

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.banners.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PPBannerCell *cell = [cv dequeueReusableCellWithReuseIdentifier:kReuseBannerCell forIndexPath:indexPath];
    id banner = self.banners[indexPath.item];
    [cell configureWithModel:(PPBannerViewModel *)banner];
    
    cell.delegate = self;
    
    
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return collectionView.bounds.size;
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    PPBannerViewModel *vm = self.banners[indexPath.item];
    
    [self.delegate didTapOn_BannerViewModel:vm];

}


-(void)didTapOnBanner_cell:(PPBannerViewModel *)pannerViewModel
{
    [self.delegate didTapOn_BannerViewModel:pannerViewModel];
}

- (void)dealloc {
    [self.autoScrollTimer invalidate];
    self.autoScrollTimer = nil;
}

@end
