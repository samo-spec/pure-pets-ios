//

//  Pure Pets
//
//  Created by Mohammed Ahmed on 08/05/2025.
//

  
#if __has_include(<Lottie/Lottie.h>)
#import <Lottie/Lottie.h>
#elif __has_include("Lottie.h")
#import "Lottie.h"
#elif __has_include(<lottie-ios_Oc/Lottie.h>)
#import <lottie-ios_Oc/Lottie.h>
#elif __has_include(<lottie_ios_Oc/Lottie.h>)
#import <lottie_ios_Oc/Lottie.h>
#else
@class LOTAnimationView;
#endif
#import "PPInsetLabel.h"

@protocol mainScreenCellDelegate <NSObject>
- (void)mainScreenTapCellAtIndex:(NSIndexPath *)index;
@end

@interface MainAppCell : UICollectionViewCell
@property (nonatomic, weak) id<mainScreenCellDelegate> delegate;
@property (nonatomic, strong) NSIndexPath *cellIndexPath;
@property (nonatomic, strong) UIImageView *BackImage;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) PPInsetLabel *nameLabel;
@property (nonatomic, strong) UIButton *nameLabelContainter;
@property (nonatomic, strong) UIView *nameView;

//@property (nonatomic, strong) UIButton *cancelButton; // NEW

@property (nonatomic, copy) void (^onCancelTap)(void); // Callback for cancel tap


- (void)setBackgroundGradientFrom:(UIColor *)startColor
                               middleColor:(UIColor *)middleColor
                               to:(UIColor *)endColor
                            angle:(CGFloat)degrees;
- (NSArray<UIColor *> *)extractTwoMainColorsFromImage:(UIImage *)image andLightenAmount:(float)amount;
@property (nonatomic, strong) UIView *metaBadgeView;
@property (nonatomic, strong) UIImageView *metaIconView;
@property (nonatomic, strong) UILabel *metaLabel;
- (void)setMetaText:(NSString *)text iconNamed:(NSString *)iconName;
- (void)configureWithMainKindModel:(MainKindsModel *)model atIndexPath:(NSIndexPath *)indexPath ;
@end
