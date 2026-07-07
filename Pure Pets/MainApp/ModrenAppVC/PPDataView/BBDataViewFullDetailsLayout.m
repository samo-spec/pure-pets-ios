#import "BBDataViewFullDetailsLayout.h"

static const CGFloat BBFullDetailsCardWidthRatio = 0.76;
static const CGFloat BBFullDetailsCardHeightRatio = 1.0;
static const CGFloat BBFullDetailsMinimumCardHeight = 340.0;
static const CGFloat BBFullDetailsMinimumCardWidth = 260.0;
static const CGFloat BBFullDetailsInterItemSpacing = 16.0;
static const CGFloat BBFullDetailsAdjacentMinimumScale = 0.90;
static const CGFloat BBFullDetailsAdjacentMinimumAlpha = 0.66;

@implementation BBDataViewFullDetailsLayout

- (instancetype)init
{
    self = [super init];
    if (!self) { return nil; }
    self.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    self.minimumLineSpacing = BBFullDetailsInterItemSpacing;
    self.minimumInteritemSpacing = BBFullDetailsInterItemSpacing;
    return self;
}

- (void)prepareLayout
{
    [super prepareLayout];
    [self bb_recalculateMetrics];
}

- (void)invalidateForViewportChange
{
    [self invalidateLayout];
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
    return YES;
}

- (void)bb_recalculateMetrics
{
    UICollectionView *collectionView = self.collectionView;
    if (!collectionView) { return; }

    UIEdgeInsets adjustedInset = collectionView.contentInset;
    if (@available(iOS 11.0, *)) {
        adjustedInset = collectionView.adjustedContentInset;
    }

    CGSize boundsSize = collectionView.bounds.size;
    CGFloat availableWidth = MAX(1.0, boundsSize.width - adjustedInset.left - adjustedInset.right);
    CGFloat availableHeight = MAX(1.0, boundsSize.height - adjustedInset.top - adjustedInset.bottom);

    CGFloat itemWidth = floor(MIN(MAX(availableWidth * BBFullDetailsCardWidthRatio,
                                      MIN(BBFullDetailsMinimumCardWidth, availableWidth)),
                                  availableWidth));
    CGFloat preferredHeight = floor(availableHeight * BBFullDetailsCardHeightRatio);
    CGFloat itemHeight = floor(MIN(MAX(preferredHeight, MIN(BBFullDetailsMinimumCardHeight, availableHeight)),
                                   MAX(1.0, availableHeight)));

    self.itemSize = CGSizeMake(itemWidth, itemHeight);

    CGFloat horizontalInset = MAX(0.0, floor((availableWidth - itemWidth) * 0.5));
    CGFloat verticalInset = 0.0;
    self.sectionInset = UIEdgeInsetsMake(verticalInset,
                                         horizontalInset,
                                         verticalInset,
                                         horizontalInset);
}

- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect
{
    NSArray<UICollectionViewLayoutAttributes *> *attributes = [super layoutAttributesForElementsInRect:rect];
    NSMutableArray<UICollectionViewLayoutAttributes *> *copiedAttributes = [NSMutableArray arrayWithCapacity:attributes.count];
    UICollectionView *collectionView = self.collectionView;
    if (!collectionView) { return attributes; }

    CGFloat visibleCenterX = collectionView.contentOffset.x + CGRectGetWidth(collectionView.bounds) * 0.5;
    CGFloat normalizingDistance = MAX(self.itemSize.width + self.minimumLineSpacing, 1.0);
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();

    for (UICollectionViewLayoutAttributes *attribute in attributes) {
        UICollectionViewLayoutAttributes *copy = [attribute copy];
        if (copy.representedElementCategory == UICollectionElementCategoryCell) {
            CGRect frame = copy.frame;
            frame.origin.y = 0.0;
            copy.frame = frame;

            if (!reduceMotion) {
                CGFloat distance = MIN(ABS(copy.center.x - visibleCenterX), normalizingDistance);
                CGFloat progress = distance / normalizingDistance;
                CGFloat scale = 1.0 - ((1.0 - BBFullDetailsAdjacentMinimumScale) * progress);
                CGFloat alpha = 1.0 - ((1.0 - BBFullDetailsAdjacentMinimumAlpha) * progress);
                copy.transform = CGAffineTransformMakeScale(scale, scale);
                copy.alpha = alpha;
                copy.zIndex = (NSInteger)lrint((1.0 - progress) * 1000.0);
            } else {
                copy.transform = CGAffineTransformIdentity;
                copy.alpha = 1.0;
            }
        } else {
            copy.transform = CGAffineTransformIdentity;
            copy.alpha = 1.0;
        }
        [copiedAttributes addObject:copy];
    }
    return copiedAttributes;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewLayoutAttributes *attributes = [[super layoutAttributesForItemAtIndexPath:indexPath] copy];
    if (!attributes || !self.collectionView) {
        return attributes;
    }

    if (attributes.representedElementCategory == UICollectionElementCategoryCell) {
        CGRect frame = attributes.frame;
        frame.origin.y = 0.0;
        attributes.frame = frame;
    }

    if (UIAccessibilityIsReduceMotionEnabled()) {
        attributes.transform = CGAffineTransformIdentity;
        attributes.alpha = 1.0;
        return attributes;
    }

    CGFloat visibleCenterX = self.collectionView.contentOffset.x + CGRectGetWidth(self.collectionView.bounds) * 0.5;
    CGFloat normalizingDistance = MAX(self.itemSize.width + self.minimumLineSpacing, 1.0);
    CGFloat distance = MIN(ABS(attributes.center.x - visibleCenterX), normalizingDistance);
    CGFloat progress = distance / normalizingDistance;
    CGFloat scale = 1.0 - ((1.0 - BBFullDetailsAdjacentMinimumScale) * progress);
    CGFloat alpha = 1.0 - ((1.0 - BBFullDetailsAdjacentMinimumAlpha) * progress);
    attributes.transform = CGAffineTransformMakeScale(scale, scale);
    attributes.alpha = alpha;
    return attributes;
}

- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset
                                 withScrollingVelocity:(CGPoint)velocity
{
    UICollectionView *collectionView = self.collectionView;
    if (!collectionView) {
        return [super targetContentOffsetForProposedContentOffset:proposedContentOffset
                                            withScrollingVelocity:velocity];
    }

    if ([collectionView numberOfSections] <= 0) {
        return [super targetContentOffsetForProposedContentOffset:proposedContentOffset
                                            withScrollingVelocity:velocity];
    }
    NSInteger itemCount = [collectionView numberOfItemsInSection:0];
    if (itemCount <= 0) {
        return [super targetContentOffsetForProposedContentOffset:proposedContentOffset
                                            withScrollingVelocity:velocity];
    }

    CGFloat stride = MAX(self.itemSize.width + self.minimumLineSpacing, 1.0);
    CGFloat firstCenterX = self.sectionInset.left + (self.itemSize.width * 0.5);
    CGFloat proposedCenterX = proposedContentOffset.x + CGRectGetWidth(collectionView.bounds) * 0.5;
    CGFloat rawIndex = (proposedCenterX - firstCenterX) / stride;
    NSInteger targetIndex = (NSInteger)llround(rawIndex);
    if (velocity.x > 0.35) {
        targetIndex = (NSInteger)ceil(rawIndex);
    } else if (velocity.x < -0.35) {
        targetIndex = (NSInteger)floor(rawIndex);
    }
    targetIndex = MAX(0, MIN(targetIndex, itemCount - 1));

    CGFloat centeredX = firstCenterX + ((CGFloat)targetIndex * stride);
    CGFloat x = centeredX - (CGRectGetWidth(collectionView.bounds) * 0.5);
    CGFloat minX = -collectionView.adjustedContentInset.left;
    CGFloat maxX = MAX(minX,
                       collectionView.contentSize.width -
                       CGRectGetWidth(collectionView.bounds) +
                       collectionView.adjustedContentInset.right);
    x = MIN(MAX(x, minX), maxX);
    return CGPointMake(x, proposedContentOffset.y);
}

@end
