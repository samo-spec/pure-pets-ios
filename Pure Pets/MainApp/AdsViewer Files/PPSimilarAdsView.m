//
//  PPSimilarAdsView 2.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 16/01/2026.
//


#import "PPSimilarAdsView.h"
#import "PPUniversalCell.h"
#import "PPUniversalCellViewModel.h"
#import "GM.h"
#import "PPImageLoaderManager.h"
static const CGFloat kPPSimilarSectionCollectionHeight = 318.0;
static const CGFloat kPPSimilarSectionTitleHeight = 32.0;
static const CGFloat kPPSimilarSectionSpacing = 14.0;

@interface PPSimilarAdsView () <UICollectionViewDelegate, UICollectionViewDataSource>


@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray<PPUniversalCellViewModel *> *items;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) NSLayoutConstraint *collectionHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *stackHeightConstraint;

@end

@implementation PPSimilarAdsView

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.items = @[];
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.clipsToBounds = NO;
    [self buildUI];
    
    self.layer.masksToBounds = NO;
    self.collectionView.layer.masksToBounds = NO;

    return self;
}

#pragma mark - UI

- (void)buildUI {
    
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = _titleString;
    self.titleLabel.font = [GM boldFontWithSize:20];
    self.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.titleLabel.textColor = UIColor.labelColor;
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.titleLabel.alpha = 0.96;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    UICollectionViewCompositionalLayout *layout =
    [[UICollectionViewCompositionalLayout alloc]
     initWithSectionProvider:^NSCollectionLayoutSection * _Nullable(
                                                                    NSInteger section,
                                                                    id<NSCollectionLayoutEnvironment>  _Nonnull environment) {
        return [self buildSectionWithEnvironment:environment];
    }];
    
    self.collectionView =
    [[UICollectionView alloc] initWithFrame:CGRectZero
                       collectionViewLayout:layout];
    
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.decelerationRate = UIScrollViewDecelerationRateFast;
    self.collectionView.clipsToBounds = NO;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    if (@available(iOS 15.0, *)) {
        self.collectionView.prefetchingEnabled = NO;
    }
    
    [self.collectionView registerClass:PPUniversalCell.class
            forCellWithReuseIdentifier:@"PPUniversalCell"];
    
    [self addSubview:self.titleLabel];
    [self addSubview:self.collectionView];
    
    self.collectionHeightConstraint =
    [self.collectionView.heightAnchor
     constraintEqualToConstant:0.0];
    self.stackHeightConstraint =
    [self.heightAnchor constraintEqualToConstant:0.0];
    self.stackHeightConstraint.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:24],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-24],
        [self.titleLabel.heightAnchor constraintEqualToConstant:kPPSimilarSectionTitleHeight],
        
        [self.collectionView.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:kPPSimilarSectionSpacing],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        self.collectionHeightConstraint,
    ]];
}

- (NSCollectionLayoutSection *)buildSection {
    return [self buildSectionWithEnvironment:nil];
}

- (NSCollectionLayoutSection *)buildSectionWithEnvironment:(id<NSCollectionLayoutEnvironment> _Nullable)environment {
    
    CGFloat availableWidth = environment.container.effectiveContentSize.width;
    CGFloat cardWidth = 168.0;
    if (availableWidth > 0) {
        cardWidth = MAX(150.0, MIN(200.0, availableWidth * 0.64));
    }
    
    NSCollectionLayoutSize *itemSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                   heightDimension:
     [NSCollectionLayoutDimension fractionalHeightDimension:1.0]];
    
    NSCollectionLayoutItem *item =
    [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
    
    NSCollectionLayoutSize *groupSize =
    [NSCollectionLayoutSize sizeWithWidthDimension:
     [NSCollectionLayoutDimension absoluteDimension:cardWidth]
                                   heightDimension:
     [NSCollectionLayoutDimension absoluteDimension:kPPSimilarSectionCollectionHeight]];
    
    NSCollectionLayoutGroup *group =
    [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize
                                                  subitems:@[item]];
    
    NSCollectionLayoutSection *section =
    [NSCollectionLayoutSection sectionWithGroup:group];
    
    section.interGroupSpacing = 14;
    section.contentInsets = NSDirectionalEdgeInsetsMake(6, 16, 0, 16);
    
    section.orthogonalScrollingBehavior =
    UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary;
    section.visibleItemsInvalidationHandler =
    ^(NSArray<NSCollectionLayoutItem *> * _Nonnull visibleItems,
      CGPoint contentOffset,
      id<NSCollectionLayoutEnvironment>  _Nonnull layoutEnvironment) {
        
        CGFloat containerWidth = layoutEnvironment.container.effectiveContentSize.width;
        if (containerWidth <= 0) containerWidth = 1;
        CGFloat containerCenterX = contentOffset.x + containerWidth / 2.0;
        for (id<NSCollectionLayoutVisibleItem> item in visibleItems) {
              CGFloat distance = fabs(item.center.x - containerCenterX);
              CGFloat normalized = MIN(1.0, distance / (containerWidth * 0.86));
              CGFloat scale = 1.0 - (normalized * 0.06);
              CGAffineTransform transform = CGAffineTransformIdentity;
              transform = CGAffineTransformTranslate(transform, 0.0, normalized * 8.0);
              transform = CGAffineTransformScale(transform, MAX(0.94, scale), MAX(0.94, scale));
              item.transform = transform;
              item.alpha = 1.0 - (normalized * 0.20);
          }
        
    };
    
    return section;
}


#pragma mark - Public

- (void)updateWithViewModels:(NSArray<PPUniversalCellViewModel *> *)viewModels {
    
    self.items = viewModels ?: @[];
    
    BOOL shouldShow = self.items.count >= 2;
    BOOL shouldHide = !shouldShow;
    
    self.hidden = shouldHide;
    self.titleLabel.hidden = shouldHide;
    self.collectionView.hidden = shouldHide;
    self.titleLabel.text = _titleString;
    
    if (shouldHide) {
        self.collectionHeightConstraint.constant = 0.0;
        self.stackHeightConstraint.constant = 0.0;
    } else {
        self.collectionHeightConstraint.constant = kPPSimilarSectionCollectionHeight;
        self.stackHeightConstraint.constant =
        kPPSimilarSectionTitleHeight + kPPSimilarSectionSpacing + kPPSimilarSectionCollectionHeight;
        [self.collectionView reloadData];
    }

    [self invalidateIntrinsicContentSize];

    if (self.didUpdateContentState) {
        self.didUpdateContentState(shouldShow, self.items.count);
    }
}

- (BOOL)hasContent {
    return self.items.count >= 2;
}

#pragma mark - CollectionView

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    return self.items.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                           cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    PPUniversalCell *cell =
    [collectionView dequeueReusableCellWithReuseIdentifier:@"PPUniversalCell"
                                              forIndexPath:indexPath];
    
    PPUniversalCellViewModel *vm = self.items[indexPath.item];
    vm.indexPath = indexPath;
    [cell applyViewModel:vm
                 context:vm.modelContext
              layoutMode:PPCellLayoutModeSquare
            discountMode:PPDiscountStyleBadge
             imageLoader:^(UIImageView *iv,
                           NSString *url,
                           UIImage *placeholder,
                           UIView *card) {

        // Images — prefer BlurHash placeholder if available
        UIImage *ph = nil;

        // 1️⃣ Try BlurHash from view model
        if (vm.blurHash.length > 0) {
            ph = [PPBlurHashBridge imageFrom:vm.blurHash syncSize:CGSizeMake(40, 40) punch:1.0];
            //NSLog(@"vm.blurHash.length > 0  %@",vm.blurHash);
        }

        // 2️⃣ Fallbacks
        if (!ph) {
            ph = vm.placeholder ?: [UIImage imageNamed:@"placeholder"];
        }
        
        [[PPImageLoaderManager shared] setImageOnImageView:iv url:url placeholder:ph complation:^(UIImage * _Nonnull image, NSString * _Nullable urlString) {
            
        }];
    }];
    
    
    // Modern card polish
    //cell.layer.cornerRadius = 18;
    cell.layer.cornerCurve = kCACornerCurveContinuous;
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    
    if (self.didSelectViewModel) {
        self.didSelectViewModel(self.items[indexPath.item]);
    }
}

@end
