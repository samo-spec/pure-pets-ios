//
//  PPNovaProductMessageCell.m
//  Pure Pets
//

#import "PPNovaProductMessageCell.h"
#import "PPUniversalCellViewModel.h"
#import "PPImageLoaderManager.h"
#import "AppManager.h"

@interface PPNovaProductMessageCell () <UICollectionViewDelegate, UICollectionViewDataSource, PPUniversalCellDelegate>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray<PetAccessory *> *products;
@property (nonatomic, assign) CGFloat maxWidth;

@end

@implementation PPNovaProductMessageCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor clearColor];
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumLineSpacing = 12;
    layout.minimumInteritemSpacing = 0;
    layout.sectionInset = UIEdgeInsetsMake(0, 16, 0, 16);

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    [self.collectionView registerClass:[PPUniversalCell class] forCellWithReuseIdentifier:[PPUniversalCell reuseIdentifier]];

    [self.contentView addSubview:self.collectionView];

    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.viewForFirstBaselineLayout.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.viewForFirstBaselineLayout.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],
        [self.collectionView.heightAnchor constraintEqualToConstant:240] // Standard card height
    ]];
}

- (void)configureWithMessage:(ChatMessageModel *)messageModel maxWidth:(CGFloat)maxWidth {
    self.products = messageModel.novaProducts;
    self.maxWidth = maxWidth;
    [self.collectionView reloadData];
    
    // Reset scroll position
    if (self.products.count > 0) {
        [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0] atScrollPosition:UICollectionViewScrollPositionLeft animated:NO];
    }
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.products.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PPUniversalCell *cell = [collectionView dequeueReusableCellWithIdentifier:[PPUniversalCell reuseIdentifier] forIndexPath:indexPath];
    
    PetAccessory *product = self.products[indexPath.item];
    PPUniversalCellViewModel *vm = [[PPUniversalCellViewModel alloc] initWithModel:product context:PPCellForMarket];
    
    [cell applyViewModel:vm
                 context:PPCellForMarket
              layoutMode:PPManagerCellLayoutModeCompact
            discountMode:PPDiscountStyleBadge
             imageLoader:^(UIImageView * _Nullable imageView, NSString * _Nullable url, UIImage * _Nullable placeholder, UIView * _Nullable card) {
        [[PPImageLoaderManager shared] loadImageWithURL:url 
                                           intoImageView:imageView 
                                            placeholder:placeholder 
                                               callback:nil];
    }];
    
    cell.delegate = self;
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    // Standard compact card size for chat
    return CGSizeMake(160, 240);
}

#pragma mark - PPUniversalCellDelegate

- (void)PPUniversalCell_tapCard:(PPUniversalCellViewModel *)universalModel {
    if ([universalModel.ModelObject isKindOfClass:[PetAccessory class]]) {
        [self.delegate novaProductCell_didTapProduct:(PetAccessory *)universalModel.ModelObject];
    }
}

- (void)PPUniversalCell_changeQuantity:(PPUniversalCellViewModel *)universalModel quantity:(NSInteger)quantity {
    // For Nova chat, we usually add 1, but we can handle quantity change if needed.
    // However, the task says "add to cart", which usually implies quantity 1 initially.
    if (quantity > 0 && [universalModel.ModelObject isKindOfClass:[PetAccessory class]]) {
        [self.delegate novaProductCell_didTapAddToCart:(PetAccessory *)universalModel.ModelObject];
    }
}

// Map the old delegate method to the new one if needed
- (void)PPUniversalCell_tapAddToCart:(PPUniversalCellViewModel *)universalModel {
    if ([universalModel.ModelObject isKindOfClass:[PetAccessory class]]) {
        [self.delegate novaProductCell_didTapAddToCart:(PetAccessory *)universalModel.ModelObject];
    }
}

@end
