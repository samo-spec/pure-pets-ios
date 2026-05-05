#import "PPPinterestLayout.h"

@interface PPPinterestLayout ()
/// Dictionary to cache layout attributes for each item by indexPath.
@property (nonatomic, strong) NSMutableDictionary<NSIndexPath *, UICollectionViewLayoutAttributes *> *attrsDictionary;
/// Content height after layout (used for contentSize).
@property (nonatomic) CGFloat contentHeight;
/// Last computed content width (used to detect width changes).
@property (nonatomic) CGFloat contentWidth;
@end

@implementation PPPinterestLayout

static NSUInteger PPPinterestAutomaticColumnCount(CGFloat collectionWidth)
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return 3;
    }

    CGFloat targetCellWidth = 188.0;
    NSUInteger columns =
        (NSUInteger)floor(MAX(collectionWidth, 0.0) / MAX(targetCellWidth, 1.0));
    return MAX(columns, 2);
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _spacing = 12;
        // Set default values
        _columnCount = 0; // 0 means "automatic" column count
        _minimumInteritemSpacing = 12;
        _minimumLineSpacing = 12;
        _sectionInset = UIEdgeInsetsMake(90, 16, 16, 16);
        _attrsDictionary = [NSMutableDictionary dictionary];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        _spacing = 12;
        // Same default initialization for storyboards/nibs.
        _columnCount = 0;
        _minimumInteritemSpacing = 12;
        _minimumLineSpacing = 12;
        _sectionInset = UIEdgeInsetsMake(90, 16, 16, 16);
        _attrsDictionary = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)prepareLayout {
    [super prepareLayout];
    
    // Clear previous attributes cache
    [self.attrsDictionary removeAllObjects];
    self.contentHeight = 0;
    
    // Ensure collectionView exists
    NSUInteger numberOfSections = [self.collectionView numberOfSections];
    if (numberOfSections == 0) {
        return;
    }
    
    // Determine number of columns to use
    UIEdgeInsets contentInset = self.collectionView.contentInset;
    CGFloat collectionWidth =
    self.collectionView.bounds.size.width
    - contentInset.left
    - contentInset.right;
    self.contentWidth = collectionWidth; // store for contentSize and bounds change checks
    
    NSUInteger columns = self.columnCount;
    if (columns == 0) {
        columns = PPPinterestAutomaticColumnCount(collectionWidth);
    }
    if (columns < 1) {
        columns = 1; // safety check (at least 1 column)
    }
    
    // Array to track current y-offset for each column (height of content in each column).
    CGFloat *columnHeights = calloc(columns, sizeof(CGFloat));
    
    CGFloat insetLeft = _sectionInset.left;
    CGFloat insetRight = _sectionInset.right;
    CGFloat insetTop = _sectionInset.top;
    CGFloat insetBottom = _sectionInset.bottom;
    CGFloat interColumnSpacing = _minimumInteritemSpacing;
    CGFloat interItemSpacing = _minimumLineSpacing;
    
    // Start each column at top inset for the first section.
    for (NSUInteger col = 0; col < columns; col++) {
        columnHeights[col] = insetTop;
    }
    
    // Iterate through each section and each item to compute frames.
    for (NSUInteger section = 0; section < numberOfSections; section++) {
        NSUInteger itemCount = [self.collectionView numberOfItemsInSection:section];
        if (itemCount == 0) {
            // Even if no items, account for section insets
            for (NSUInteger col = 0; col < columns; col++) {
                columnHeights[col] = columnHeights[col] + insetTop + insetBottom;
            }
            self.contentHeight = MAX(self.contentHeight, columnHeights[0]);
            continue;
        }
        
        // If multiple sections, reset column heights to start at current contentHeight + top inset for this section.
        if (section > 0) {
            // Advance each column by current contentHeight (from previous sections) plus this section's top inset.
            for (NSUInteger col = 0; col < columns; col++) {
                columnHeights[col] = self.contentHeight + insetTop;
            }
        }
        
    // Compute item width (all columns have equal width).
    CGFloat availableWidth =
    collectionWidth
    - insetLeft
    - insetRight
    - (columns - 1) * interColumnSpacing;
    // Floor to avoid fractional pixel sizes
    CGFloat itemWidth = floor(availableWidth / columns);
    itemWidth = MAX(itemWidth, 1);
        
        // Layout each item
        for (NSUInteger itemIndex = 0; itemIndex < itemCount; itemIndex++) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:itemIndex inSection:section];
            // Diffable-safe: Use stable ID if available for cache keys
            NSString *cacheKey = nil;
            if ([self.delegate respondsToSelector:@selector(collectionView:layout:stableIDForItemAtIndexPath:)]) {
                cacheKey = [self.delegate collectionView:self.collectionView
                                                  layout:self
                             stableIDForItemAtIndexPath:indexPath];
            }
            if (!cacheKey) {
                cacheKey = [NSString stringWithFormat:@"%ld-%ld",
                            (long)indexPath.section,
                            (long)indexPath.item];
            }
            // Determine the shortest column to place the next item
            NSUInteger targetColumn = 0;
            CGFloat minColumnHeight = columnHeights[0];
            for (NSUInteger col = 1; col < columns; col++) {
                if (columnHeights[col] < minColumnHeight) {
                    minColumnHeight = columnHeights[col];
                    targetColumn = col;
                }
            }
            // Calculate x position for the item
            CGFloat xOffset = insetLeft + (itemWidth + interColumnSpacing) * targetColumn;
            CGFloat yOffset = columnHeights[targetColumn];
            // Ask delegate for item height given the computed width
            CGFloat itemHeight = 0;
            if ([self.delegate respondsToSelector:@selector(collectionView:layout:heightForItemAtIndexPath:withWidth:)]) {
                itemHeight = [self.delegate collectionView:self.collectionView layout:self heightForItemAtIndexPath:indexPath withWidth:itemWidth];
            }

            // Fallback if delegate returns invalid height
            if (itemHeight <= 0) {
                itemHeight = itemWidth;
            }

            itemHeight = MAX(itemHeight, MAX(kPPPinterestMinCellHeight, itemWidth));

            // Create layout attributes and set frame
            UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
            attributes.frame = CGRectMake(xOffset, yOffset, itemWidth, itemHeight);
            attributes.zIndex = 0;
            // Cache the attributes
            self.attrsDictionary[indexPath] = attributes;


            // Update the column height
            columnHeights[targetColumn] = yOffset + itemHeight + interItemSpacing;
            // Update overall contentHeight to the bottom of this item
            self.contentHeight = MAX(self.contentHeight, columnHeights[targetColumn]);
        }
        // After laying out all items in the section, add bottom inset to column heights
        for (NSUInteger col = 0; col < columns; col++) {
            columnHeights[col] = columnHeights[col] + insetBottom;
        }
        // Update overall contentHeight after this section
        self.contentHeight = MAX(self.contentHeight, columnHeights[0]);
        for (NSUInteger col = 1; col < columns; col++) {
            if (columnHeights[col] > self.contentHeight) {
                self.contentHeight = columnHeights[col];
            }
        }
    }
    
    free(columnHeights);
}
- (UICollectionViewLayoutInvalidationContext *)invalidationContextForBoundsChange:(CGRect)newBounds {
    UICollectionViewLayoutInvalidationContext *context =
    [super invalidationContextForBoundsChange:newBounds];
   
    return context;
}
- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect {
    NSMutableArray<UICollectionViewLayoutAttributes *> *visibleAttributes = [NSMutableArray array];
    // Return attributes that intersect the given rect
    [self.attrsDictionary enumerateKeysAndObjectsUsingBlock:^(NSIndexPath *indexPath, UICollectionViewLayoutAttributes *attributes, BOOL *stop) {
        if (CGRectIntersectsRect(attributes.frame, rect)) {
            [visibleAttributes addObject:attributes];
        }
    }];
    return visibleAttributes;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    // Return the layout attributes for the specific item (already calculated in prepareLayout).
    return self.attrsDictionary[indexPath];
}

- (CGSize)collectionViewContentSize {
    // Width is the collection view's width; height is the calculated contentHeight (or at least the visible height).
    CGFloat width = self.collectionView.bounds.size.width;
    // Ensure contentHeight is at least the height of the collection view bounds (to avoid zero-height content issues).
    CGFloat height = MAX(self.contentHeight, self.collectionView.bounds.size.height);
    return CGSizeMake(width, height);
}

//- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
//    return YES;
//}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    return !CGSizeEqualToSize(newBounds.size, self.collectionView.bounds.size);
}
@end













 













 
#define kPPHeightCacheBaseKey @"PPHeightCacheDict"

@interface PPHeightCacheManager ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSNumber *> *> *heightCaches;
@end

@implementation PPHeightCacheManager

+ (instancetype)sharedManager {
    static PPHeightCacheManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[PPHeightCacheManager alloc] init];
        manager.heightCaches = [NSMutableDictionary dictionary];
    });
    return manager;
}

- (NSString *)fullKeyForKey:(NSString *)key {
    return [NSString stringWithFormat:@"%@_%@", kPPHeightCacheBaseKey, key];
}

- (void)loadCacheForKey:(NSString *)cacheKey {
    NSString *fullKey = [self fullKeyForKey:cacheKey];
    NSDictionary *stored = [[NSUserDefaults standardUserDefaults] objectForKey:fullKey];
    if ([stored isKindOfClass:[NSDictionary class]]) {
        self.heightCaches[cacheKey] = [stored mutableCopy];
    } else {
        self.heightCaches[cacheKey] = [NSMutableDictionary dictionary];
    }
}

- (void)saveCacheForKey:(NSString *)cacheKey {
    NSString *fullKey = [self fullKeyForKey:cacheKey];
    NSDictionary *cacheDict = self.heightCaches[cacheKey];
    if (cacheDict) {
        [[NSUserDefaults standardUserDefaults] setObject:cacheDict forKey:fullKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}
 
- (void)clearCacheForKey:(NSString *)cacheKey {
    if (!cacheKey) return;
    [self.heightCaches removeObjectForKey:cacheKey];
    NSString *fullKey = [self fullKeyForKey:cacheKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:fullKey];
}

- (NSString *)cacheIndexKeyForIndexPath:(NSIndexPath *)indexPath {
    return [NSString stringWithFormat:@"%ld-%ld", (long)indexPath.section, (long)indexPath.item];
}

- (nullable NSNumber *)heightForIndexPath:(NSIndexPath *)indexPath key:(NSString *)cacheKey {
    return self.heightCaches[cacheKey][[self cacheIndexKeyForIndexPath:indexPath]];
}

- (void)setHeight:(CGFloat)height forIndexPath:(NSIndexPath *)indexPath key:(NSString *)cacheKey {
    if (!self.heightCaches[cacheKey]) {
        self.heightCaches[cacheKey] = [NSMutableDictionary dictionary];
    }
    self.heightCaches[cacheKey][[self cacheIndexKeyForIndexPath:indexPath]] = @(height);
}

@end
