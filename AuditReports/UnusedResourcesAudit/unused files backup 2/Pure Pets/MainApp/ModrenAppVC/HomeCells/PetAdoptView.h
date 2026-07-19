//
//  PetAdoptView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 10/08/2025.
//

#import <UIKit/UIKit.h>
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
#pragma mark - Interface
// ============================================================
// MARK: PetAdoptView : UIView
// ============================================================
@interface PetAdoptView : UIView

// ============================================================
// MARK: UI Elements
// ============================================================
@property (nonatomic, strong) UILabel *titleLabel;       // Main title (e.g., pet name)
@property (nonatomic, strong) UILabel *subtitleLabel;    // Subtitle (e.g., description)
@property (nonatomic, strong) UIImageView *petImageView; // Pet image
@property (nonatomic, strong) UIView *shadowView;        // For adding shadow beneath ContView
@property (nonatomic, strong) UIView *ContView;          // Content container with rounded corners
@property (nonatomic, copy, nullable) void (^onTap)(void);

// ============================================================
// MARK: Gradient Background
// ============================================================
//@property (nonatomic, strong) CAGradientLayer *bgGradientLayer; // Background gradient layer


@property (nonatomic, strong) LOTAnimationView *lottieHeaderView;


- (void)setBackgroundGradientFrom:(UIColor *)startColor
                               to:(UIColor *)endColor
                            angle:(CGFloat)degrees;
- (NSArray<UIColor *> *)extractTwoMainColorsFromImage:(UIImage *)image andLightenAmount:(float)amount;

@end
