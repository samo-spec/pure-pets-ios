//
//  PPNovaProductMessageCell.m
//  Pure Pets
//

#import "PPNovaProductMessageCell.h"
#import "PPUniversalCellViewModel.h"
#import "PPImageLoaderManager.h"
#import "AppManager.h"
#import "ServiceModel.h"
#import "PetAd.h"
#import "AdoptPetModel.h"
#import "VetModel.h"

@interface PPNovaProductMessageCell () <UICollectionViewDelegateFlowLayout, UICollectionViewDataSource, PPUniversalCellDelegate>

@property (nonatomic, strong) UIStackView *headerStack;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray *products;
@property (nonatomic, assign) CGFloat maxWidth;
@property (nonatomic, copy) NSString *messageID;
@property (nonatomic, copy) NSString *renderKey;
@property (nonatomic, assign) BOOL hasPerformedInitialScroll;
@property (nonatomic, assign) CGFloat lastCollectionLayoutWidth;
@property (nonatomic, copy) NSString *lastAnimatedRenderKey;

@end

@implementation PPNovaProductMessageCell

+ (NSString *)reuseIdentifier {
    return @"PPNovaProductMessageCell";
}

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
    self.messageID = nil;
    self.renderKey = nil;
    self.hasPerformedInitialScroll = NO;
    self.lastCollectionLayoutWidth = 0.0;
    self.lastAnimatedRenderKey = nil;
    self.countLabel.text = nil;
    for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
        cell.transform = CGAffineTransformIdentity;
        cell.alpha = 1.0;
    }
}

- (void)setupUI {
    self.backgroundColor = [UIColor clearColor];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.clipsToBounds = NO;
    self.contentView.clipsToBounds = NO;
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    self.headerStack = [[UIStackView alloc] init];
    self.headerStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerStack.axis = UILayoutConstraintAxisHorizontal;
    self.headerStack.alignment = UIStackViewAlignmentCenter;
    self.headerStack.spacing = 8.0;
    self.headerStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
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
    self.collectionView.clipsToBounds = NO;
    self.collectionView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [PPUniversalCell pp_registerInCollectionView:self.collectionView];

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
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-20.0],
        [self.collectionView.heightAnchor constraintEqualToConstant:286.0]
    ]];
}

- (void)configureWithMessage:(ChatMessageModel *)messageModel maxWidth:(CGFloat)maxWidth {
    NSString *nextMessageID = messageModel.ID ?: @"";
    NSString *nextRenderKey = [self pp_renderKeyForMessage:messageModel];
    BOOL isNewMessage = ![self.messageID isEqualToString:nextMessageID];
    BOOL shouldReloadCards = isNewMessage || ![self.renderKey isEqualToString:nextRenderKey];
    BOOL widthChanged = fabs(self.maxWidth - maxWidth) > 1.0;
    self.messageID = messageModel.ID ?: @"";
    self.renderKey = nextRenderKey;
    if (isNewMessage) {
        self.hasPerformedInitialScroll = NO;
    }

    self.products = [self pp_supportedNovaItemsFromArray:(NSArray *)messageModel.novaProducts];
    self.maxWidth = maxWidth;
    LOG_INFO(@"NOVA_UNIVERSAL_CELL_RENDER_PREP message_id=%@ response_id=%@ item_count=%lu supported_count=%lu",
             messageModel.ID ?: @"",
             messageModel.novaResponseID ?: @"",
             (unsigned long)((NSArray *)messageModel.novaProducts).count,
             (unsigned long)self.products.count);
    if (((NSArray *)messageModel.novaProducts).count > 0 && self.products.count == 0) {
        LOG_WARN(@"NOVA_UNIVERSAL_CELL_RENDER_FAILURE message_id=%@ response_id=%@ reason=no_supported_items item_count=%lu",
                 messageModel.ID ?: @"",
                 messageModel.novaResponseID ?: @"",
                 (unsigned long)((NSArray *)messageModel.novaProducts).count);
    }
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.headerStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.collectionView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.titleLabel.text = kLang(@"nova_product_results");
    self.countLabel.text = [NSString stringWithFormat:kLang(@"nova_product_count_format"), (long)self.products.count];
    if (shouldReloadCards) {
        [UIView performWithoutAnimation:^{
            [self.collectionView reloadData];
            [self.collectionView.collectionViewLayout invalidateLayout];
        }];
        [self pp_scrollToInitialProductIfNeededForRenderKey:nextRenderKey];
        [self pp_animateCardsEntranceIfNeededForRenderKey:nextRenderKey];
    } else if (widthChanged) {
        CGPoint preservedOffset = self.collectionView.contentOffset;
        [UIView performWithoutAnimation:^{
            [self.collectionView.collectionViewLayout invalidateLayout];
            [self.collectionView setNeedsLayout];
            [self.collectionView layoutIfNeeded];
            [self.collectionView setContentOffset:preservedOffset animated:NO];
        }];
    }
}

- (void)pp_animateCardsEntranceIfNeededForRenderKey:(NSString *)renderKey {
    if (UIAccessibilityIsReduceMotionEnabled() || renderKey.length == 0 ||
        [self.lastAnimatedRenderKey isEqualToString:renderKey]) {
        return;
    }
    self.lastAnimatedRenderKey = renderKey;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.collectionView.window == nil ||
            ![self.renderKey isEqualToString:renderKey]) {
            return;
        }
        [self.collectionView layoutIfNeeded];
        NSArray<UICollectionViewCell *> *visibleCells =
            [self.collectionView.visibleCells sortedArrayUsingComparator:^NSComparisonResult(UICollectionViewCell *first, UICollectionViewCell *second) {
                NSIndexPath *firstPath = [self.collectionView indexPathForCell:first];
                NSIndexPath *secondPath = [self.collectionView indexPathForCell:second];
                if (firstPath.item == secondPath.item) return NSOrderedSame;
                return firstPath.item < secondPath.item ? NSOrderedAscending : NSOrderedDescending;
            }];
        self.headerStack.alpha = 0.0;
        self.headerStack.transform = CGAffineTransformMakeTranslation(0.0, 5.0);
        [UIView animateWithDuration:0.32
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.headerStack.alpha = 1.0;
            self.headerStack.transform = CGAffineTransformIdentity;
        } completion:nil];

        [visibleCells enumerateObjectsUsingBlock:^(UICollectionViewCell *cell, NSUInteger idx, __unused BOOL *stop) {
            cell.alpha = 0.0;
            cell.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 12.0),
                                                     CGAffineTransformMakeScale(0.985, 0.985));
            [UIView animateWithDuration:0.36
                                  delay:0.045 * idx
                                options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                cell.alpha = 1.0;
                cell.transform = CGAffineTransformIdentity;
            } completion:nil];
        }];
    });
}

- (void)updateAvailableWidth:(CGFloat)maxWidth {
    if (maxWidth <= 1.0) {
        return;
    }
    if (fabs(self.maxWidth - maxWidth) <= 1.0) {
        return;
    }
    self.maxWidth = maxWidth;
    CGPoint preservedOffset = self.collectionView.contentOffset;
    [UIView performWithoutAnimation:^{
        [self.collectionView.collectionViewLayout invalidateLayout];
        [self.collectionView setNeedsLayout];
        [self.collectionView layoutIfNeeded];
        [self.collectionView setContentOffset:preservedOffset animated:NO];
    }];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.collectionView.bounds);
    if (width > 1.0 && fabs(width - self.lastCollectionLayoutWidth) > 1.0) {
        self.lastCollectionLayoutWidth = width;
        CGPoint preservedOffset = self.collectionView.contentOffset;
        [UIView performWithoutAnimation:^{
            [self.collectionView.collectionViewLayout invalidateLayout];
            [self.collectionView setContentOffset:preservedOffset animated:NO];
        }];
    }
}

- (void)pp_scrollToInitialProductIfNeededForRenderKey:(NSString *)renderKey {
    if (self.hasPerformedInitialScroll || self.products.count == 0) {
        return;
    }

    NSString *capturedRenderKey = renderKey ?: @"";
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.products.count == 0 || self.collectionView.window == nil ||
            ![self.renderKey isEqualToString:capturedRenderKey]) {
            return;
        }
        self.hasPerformedInitialScroll = YES;
        [self.collectionView layoutIfNeeded];
        UICollectionViewScrollPosition position = Language.isRTL ? UICollectionViewScrollPositionRight : UICollectionViewScrollPositionLeft;
        [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]
                                    atScrollPosition:position
                                            animated:NO];
    });
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.products.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PPUniversalCell *cell = (PPUniversalCell *)[PPUniversalCell pp_dequeueFromCollectionView:collectionView indexPath:indexPath];
    cell.transform = CGAffineTransformIdentity;
    cell.alpha = 1.0;
    if (indexPath.item >= self.products.count) {
        LOG_WARN(@"NOVA_UNIVERSAL_CELL_RENDER_FAILURE message_id=%@ reason=index_out_of_bounds index=%ld count=%lu",
                 self.messageID ?: @"",
                 (long)indexPath.item,
                 (unsigned long)self.products.count);
        return cell;
    }

    id item = self.products[indexPath.item];
    PPCellContext context = [self pp_cellContextForNovaItem:item];
    PPUniversalCellViewModel *vm = [[PPUniversalCellViewModel alloc] initWithModel:item context:context];

    [cell applyViewModel:vm
                 context:context
              layoutMode:PPCellLayoutModeMarket
            discountMode:PPDiscountStyleBadge
             imageLoader:^(UIImageView * _Nullable imageView, NSString * _Nullable url, UIImage * _Nullable placeholder, UIView * _Nullable card) {
        [[PPImageLoaderManager shared] setImageOnImageView:imageView
                                                        url:url
                                                placeholder:placeholder
                                                 complation:nil];
    }];

    cell.delegate = self;
    LOG_INFO(@"NOVA_UNIVERSAL_CELL_RENDER_SUCCESS message_id=%@ render_key=%@ index=%ld objectClass=%@ context=%ld",
             self.messageID ?: @"",
             self.renderKey ?: @"",
             (long)indexPath.item,
             NSStringFromClass([item class]),
             (long)context);
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat availableWidth = CGRectGetWidth(collectionView.bounds);
    if (availableWidth <= 1.0) {
        availableWidth = self.contentView.bounds.size.width > 0 ? self.contentView.bounds.size.width : self.maxWidth;
    }
    CGFloat horizontalInset = 36.0;
    CGFloat lineSpacing = 12.0;
    CGFloat cardWidth = floor((availableWidth - horizontalInset - lineSpacing) / 2.0);
    cardWidth = MAX(154.0, MIN(cardWidth, 2085.0));
    cardWidth = cardWidth - 20.0;
    return CGSizeMake(cardWidth , 270.0);
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
    id item = universalModel.ModelObject;
    if ([self pp_isSupportedNovaItem:item]) {
        [self.delegate novaProductCell_didTapProduct:item];
    }
}

- (void)PPUniversalCell_changeQuantity:(PPUniversalCellViewModel *)universalModel quantity:(NSInteger)quantity {
    // For Nova chat, we usually add 1, but we can handle quantity change if needed.
    // However, the task says "add to cart", which usually implies quantity 1 initially.
    if (quantity > 0 && [universalModel.ModelObject isKindOfClass:[PetAccessory class]]) {
        [self.delegate novaProductCell_didTapAddToCart:universalModel.ModelObject];
    }
}

// Map the old delegate method to the new one if needed
- (void)PPUniversalCell_tapAddToCart:(PPUniversalCellViewModel *)universalModel {
    if ([universalModel.ModelObject isKindOfClass:[PetAccessory class]]) {
        [self.delegate novaProductCell_didTapAddToCart:universalModel.ModelObject];
    }
}

#pragma mark - Nova Item Support

- (NSArray *)pp_supportedNovaItemsFromArray:(NSArray *)items {
    if (![items isKindOfClass:NSArray.class]) {
        return @[];
    }
    NSMutableArray *supported = [NSMutableArray arrayWithCapacity:items.count];
    for (id item in items) {
        if ([self pp_isSupportedNovaItem:item]) {
            [supported addObject:item];
        }
    }
    return supported.copy;
}

- (BOOL)pp_isSupportedNovaItem:(id)item {
    return [self pp_realNovaIDForItem:item].length > 0;
}

- (NSString *)pp_renderKeyForMessage:(ChatMessageModel *)messageModel {
    NSMutableArray<NSString *> *ids = [NSMutableArray array];
    for (id item in (NSArray *)messageModel.novaProducts) {
        NSString *identifier = [self pp_realNovaIDForItem:item];
        if (identifier.length > 0) {
            [ids addObject:identifier];
        }
    }
    return [NSString stringWithFormat:@"%@|%@|%@",
            messageModel.ID ?: @"",
            messageModel.novaResponseID ?: @"",
            [ids componentsJoinedByString:@","]];
}

- (NSString *)pp_realNovaIDForItem:(id)item {
    if ([item isKindOfClass:PetAccessory.class]) {
        return ((PetAccessory *)item).accessoryID ?: @"";
    }
    if ([item isKindOfClass:ServiceModel.class]) {
        return ((ServiceModel *)item).serviceID ?: @"";
    }
    if ([item isKindOfClass:PetAd.class]) {
        return ((PetAd *)item).adID ?: @"";
    }
    if ([item isKindOfClass:AdoptPetModel.class]) {
        return ((AdoptPetModel *)item).documentID ?: @"";
    }
    if ([item isKindOfClass:VetModel.class]) {
        return ((VetModel *)item).vetID ?: @"";
    }
    return @"";
}

- (PPCellContext)pp_cellContextForNovaItem:(id)item {
    if ([item isKindOfClass:ServiceModel.class]) {
        return PPCellForServices;
    }
    if ([item isKindOfClass:VetModel.class]) {
        return PPCellForVets;
    }
    if ([item isKindOfClass:AdoptPetModel.class]) {
        return PPCellForAdopt;
    }
    if ([item isKindOfClass:PetAd.class]) {
        return PPCellForAds;
    }
    if ([item isKindOfClass:PetAccessory.class]) {
        PetAccessory *accessory = (PetAccessory *)item;
        if (accessory.accessKindType == AccessTypeFood) {
            return PPCellForFood;
        }
        if (accessory.accessKindType == AccessTypeLivePet) {
            return PPCellForAds;
        }
    }
    return PPCellForMarket;
}

@end
