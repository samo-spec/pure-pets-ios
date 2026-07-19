//
//  PetAdoptCollectionViewCell.h
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
// MARK: PetAdoptCollectionViewCell : UICollectionViewCell
// ============================================================
@interface PetAdoptCollectionViewCell : UICollectionViewCell
@property (nonatomic, copy, nullable) void (^onTap)(void);
// ============================================================
// MARK: UI Elements
// ============================================================
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;


@property (nonatomic, strong) LOTAnimationView *lottieHeaderView;

- (void)configureWithTitle:(NSString *)title
                  subtitle:(NSString *)subtitle
                 seedImage:(nullable UIImage *)seedImage;

@end
