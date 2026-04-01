//
//  PPBannerCollectionCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 30/09/2025.
//

#import "PPBannersCollection.h"
@class PPBannerViewModel;
@class MainBannerModel;
@class PPHomePromoCarouselCard;
#import "PPImageCollection.h"

typedef void (^PPHomePromoCarouselTapBlock)(PPHomePromoCarouselCard *card);

@interface PPBannerCollectionCell : UICollectionViewCell<PPImageCollectionDelegate>
@property (nonatomic, strong) PPBannersCollection *bannersView;
+ (CGFloat)preferredCarouselSectionHeight;
+ (CGFloat)preferredCarouselSectionTopInset;
+ (CGFloat)preferredCarouselSectionHorizontalInset;
+ (CGFloat)preferredCarouselSectionBottomInset;
- (void)configureWithBanners:(NSArray<PPBannerViewModel *> *)banners group:(MainBannerModel *)group delegate:(id<BannerTapsCollectionDelegate>)delegate;
- (void)configureWithPromoCards:(NSArray<PPHomePromoCarouselCard *> *)cards
                      onCardTap:(nullable PPHomePromoCarouselTapBlock)onCardTap
                   onPrimaryTap:(nullable PPHomePromoCarouselTapBlock)onPrimaryTap
                 onSecondaryTap:(nullable PPHomePromoCarouselTapBlock)onSecondaryTap;
+ (NSString *)reuseIdentifier;
- (void)configurePlaceholder;
@end
