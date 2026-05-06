//
//  PPNovaProductMessageCell.m
//  Pure Pets
//

#import "PPNovaProductMessageCell.h"
#import "PPUniversalCellViewModel.h"
#import "PPImageLoaderManager.h"
#import "AppManager.h"

@interface PPNovaProductMessageCell () <UICollectionViewDelegateFlowLayout, UICollectionViewDataSource, PPUniversalCellDelegate>

@property (nonatomic, strong) UIStackView *headerStack;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *countLabel;
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

- (void)prepareForReuse {
    [super prepareForReuse];
    self.products = @[];
    self.countLabel.text = nil;
    for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
        cell.transform = CGAffineTransformIdentity;
        cell.alpha = 1.0;
    }
}

- (void)setupUI {
    self.backgroundColor = [UIColor clearColor];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    self.headerStack = [[UIStackView alloc] init];
    self.headerStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerStack.axis = UILayoutConstraintAxisHorizontal;
    self.headerStack.alignment = UIStackViewAlignmentCenter;
    self.headerStack.spacing = 8.0;
    [self.contentView addSubview:self.headerStack];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [GM boldFontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = AppPrimaryTextClr;
    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.titleLabel.text = kLang(@"nova_product_results");
    [self.headerStack addArrangedSubview:self.titleLabel];

    UIView *spacer = [[UIView alloc] init];
    [self.headerStack addArrangedSubview:spacer];

    UIColor *brandColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    self.countLabel = [[UILabel alloc] init];
    self.countLabel.font = [GM MidFontWithSize:PPFontCaption2] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    self.countLabel.textColor = [brandColor colorWithAlphaComponent:0.90];
    self.countLabel.textAlignment = NSTextAlignmentCenter;
    self.countLabel.backgroundColor = [brandColor colorWithAlphaComponent:0.10];
    self.countLabel.layer.cornerRadius = 11.0;
    self.countLabel.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.countLabel.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.headerStack addArrangedSubview:self.countLabel];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumLineSpacing = 14;
    layout.minimumInteritemSpacing = 0;
    layout.sectionInset = UIEdgeInsetsMake(0, 18, 0, 18);

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    [self.collectionView registerClass:[PPUniversalCell class] forCellWithReuseIdentifier:[PPUniversalCell reuseIdentifier]];

    [self.contentView addSubview:self.collectionView];

    [NSLayoutConstraint activateConstraints:@[
        [self.headerStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10.0],
        [self.headerStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20.0],
        [self.headerStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20.0],
        [self.countLabel.heightAnchor constraintEqualToConstant:22.0],
        [self.countLabel.widthAnchor constraintGreaterThanOrEqualToConstant:58.0],

        [self.collectionView.topAnchor constraintEqualToAnchor:self.headerStack.bottomAnchor constant:9.0],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12.0],
        [self.collectionView.heightAnchor constraintEqualToConstant:286.0]
    ]];
}

- (void)configureWithMessage:(ChatMessageModel *)messageModel maxWidth:(CGFloat)maxWidth {
    self.products = messageModel.novaProducts ?: @[];
    self.maxWidth = maxWidth;
    self.titleLabel.text = kLang(@"nova_product_results");
    self.countLabel.text = [NSString stringWithFormat:kLang(@"nova_product_count_format"), (long)self.products.count];
    [self.collectionView reloadData];
    
    // Reset scroll position
    if (self.products.count > 0) {
        UICollectionViewScrollPosition position = Language.isRTL ? UICollectionViewScrollPositionRight : UICollectionViewScrollPositionLeft;
        [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0] atScrollPosition:position animated:NO];
    }
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.products.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PPUniversalCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[PPUniversalCell reuseIdentifier] forIndexPath:indexPath];
    
    PetAccessory *product = self.products[indexPath.item];
    PPUniversalCellViewModel *vm = [[PPUniversalCellViewModel alloc] initWithModel:product context:PPCellForMarket];
    
    [cell applyViewModel:vm
                 context:PPCellForMarket
              layoutMode:PPCellLayoutModeMarket
            discountMode:PPDiscountStyleBadge
             imageLoader:^(UIImageView * _Nullable imageView, NSString * _Nullable url, UIImage * _Nullable placeholder, UIView * _Nullable card) {
        [[PPImageLoaderManager shared] setImageOnImageView:imageView
                                                        url:url
                                                placeholder:placeholder
                                                 complation:nil];
    }];

    cell.delegate = self;
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat availableWidth = self.contentView.bounds.size.width > 0 ? self.contentView.bounds.size.width : self.maxWidth;
    CGFloat cardWidth = floor((availableWidth - 54.0) / 2.0);
    cardWidth = MAX(154.0, MIN(cardWidth, 198.0));
    return CGSizeMake(cardWidth, 270.0);
}

- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    if (!cell || UIAccessibilityIsReduceMotionEnabled()) return;

    [UIView animateWithDuration:0.10 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        cell.transform = CGAffineTransformMakeScale(0.982, 0.982);
        cell.alpha = 0.94;
    } completion:nil];
}

- (void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    if (!cell || UIAccessibilityIsReduceMotionEnabled()) return;

    [UIView animateWithDuration:0.20 delay:0.0 usingSpringWithDamping:0.90 initialSpringVelocity:0.15 options:UIViewAnimationOptionCurveEaseOut animations:^{
        cell.transform = CGAffineTransformIdentity;
        cell.alpha = 1.0;
    } completion:nil];
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
