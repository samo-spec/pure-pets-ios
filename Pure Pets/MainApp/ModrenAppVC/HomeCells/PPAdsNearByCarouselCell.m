//
//  PPAdsNearByCarouselCell 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 30/12/2025.
//


#import "PPAdsNearByCarouselCell.h"
#import "PPUniversalCell.h"
#import "PPImageLoaderManager.h"
@interface PPAdsNearByCarouselCell ()
<UICollectionViewDataSource, UICollectionViewDelegate>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UICollectionViewFlowLayout *layout;
@property (nonatomic, copy) NSArray<PPUniversalCellViewModel *> *items;
@property (nonatomic, assign) NSInteger startIndex;

@end

@implementation PPAdsNearByCarouselCell

+ (NSString *)reuseIdentifier {
    return @"PPAdsNearByCarouselCell";
}

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self buildCollectionView];
    }
    return self;
}

#pragma mark - Setup

- (void)buildCollectionView {

    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;

    // Professional card sizing
    layout.itemSize = CGSizeMake(300, 380);
    layout.minimumLineSpacing = 16;
    layout.sectionInset = UIEdgeInsetsMake(0, 24, 0, 24);

    self.layout = layout;

    UICollectionView *cv =
    [[UICollectionView alloc] initWithFrame:CGRectZero
                       collectionViewLayout:self.layout];

    cv.translatesAutoresizingMaskIntoConstraints = NO;
    cv.backgroundColor = UIColor.clearColor;
    cv.showsHorizontalScrollIndicator = NO;
    cv.decelerationRate = UIScrollViewDecelerationRateFast;
    cv.clipsToBounds = NO;

    cv.dataSource = self;
    cv.delegate   = self;

    [cv registerClass:PPUniversalCell.class
forCellWithReuseIdentifier:PPUniversalCell.reuseIdentifier];

    [self.contentView addSubview:cv];
    self.collectionView = cv;

    [NSLayoutConstraint activateConstraints:@[
        [cv.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [cv.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [cv.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [cv.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];
}

#pragma mark - Configure

- (void)configureWithViewModels:(NSArray<PPUniversalCellViewModel *> *)models
                    startIndex:(NSInteger)index {

    self.items = models ?: @[];
    self.startIndex = MAX(0, MIN(index, self.items.count - 1));

    [self.collectionView reloadData];

    // 🔥 Ensure layout is ready before scrolling
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.startIndex < self.items.count) {
            NSIndexPath *ip =
            [NSIndexPath indexPathForItem:self.startIndex inSection:0];

            [self.collectionView scrollToItemAtIndexPath:ip
                                        atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                                animated:NO];
        }
    });
}

#pragma mark - Reuse

- (void)prepareForReuse {
    [super prepareForReuse];
    self.items = @[];
    self.startIndex = 0;
    [self.collectionView setContentOffset:CGPointZero animated:NO];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    return self.items.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                           cellForItemAtIndexPath:(NSIndexPath *)indexPath {

    PPUniversalCell *cell =
    [collectionView dequeueReusableCellWithReuseIdentifier:PPUniversalCell.reuseIdentifier
                                              forIndexPath:indexPath];

    PPUniversalCellViewModel *vm = self.items[indexPath.item];

    [cell applyViewModel:vm
                 context:vm.modelContext
              layoutMode:PPCellLayoutModeSquare
            discountMode:PPDiscountStyleBadge
             imageLoader:^(UIImageView *iv,
                           NSString *url,
                           UIImage *placeholder,
                           UIView *card) {

        [[PPImageLoaderManager shared] setImageOnImageView:iv url:url complation:^(UIImage * _Nonnull image, NSString * _Nullable urlString) {
            
        }];
    }];

    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath {

    PPUniversalCellViewModel *vm = self.items[indexPath.item];
    if (!vm) return;

    // Bubble selection up using responder chain if needed
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"PPAdsNearByDidSelectAd"
     object:vm];
}

#pragma mark - Scroll Scaling
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat centerX = scrollView.contentOffset.x + scrollView.bounds.size.width * 0.5;

    for (UICollectionViewCell *cell in self.collectionView.visibleCells) {

        CGPoint cellCenter =
        [self.collectionView convertPoint:cell.center toView:self.collectionView];

        CGFloat distance = fabs(cellCenter.x - centerX);
        CGFloat maxDistance = scrollView.bounds.size.width * 0.6;
        CGFloat ratio = MIN(distance / maxDistance, 1.0);

        CGFloat scale = 1.0 - (ratio * 0.18);
        CGFloat alpha = 1.0 - (ratio * 0.55);

        cell.transform = CGAffineTransformMakeScale(scale, scale);
        cell.alpha = alpha;

        // 🔥 Critical: bring focused cell forward
        cell.layer.zPosition = (1.0 - ratio) * 1000;
    }
}

@end
