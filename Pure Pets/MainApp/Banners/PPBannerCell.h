//
//  PPBannerCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 08/09/2025.
//


@protocol BannerTapsCellDelegate <NSObject>
-(void)didTapOnBanner_cell:(PPBannerViewModel *)pannerViewModel;
@end


@interface PPBannerCell : UICollectionViewCell
- (void)configureWithModel:(PPBannerViewModel *)vm;
@property (nonatomic, strong, readonly) PPBannerView *bannerView;
- (void)setBackgroundGradientFrom:(UIColor *)startColor
                               to:(UIColor *)endColor
                            angle:(CGFloat)degrees;
- (NSArray<UIColor *> *)extractTwoMainColorsFromImage:(UIImage *)image andLightenAmount:(float)amount;

@property (nonatomic, weak) id <BannerTapsCellDelegate> delegate;
@end
