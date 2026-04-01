//
//  AppClasses.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/05/2025.
//

#import <Foundation/Foundation.h>
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
typedef NS_ENUM(NSInteger, titleAlign)
{
    titleAlignCenter = 1,
    titleAlignLeft = 2,
    titleAlignRigth = 3
};


NS_ASSUME_NONNULL_BEGIN

@interface AppClasses : NSObject
+(void)addShadowToView:(UIView *)view;

+ (void)callPhoneNumber:(NSString *)phoneNumber  fromViewController:(UIViewController *)viewController;
+ (void)startWhatsAppWith:(NSString *)phoneNumber  fromViewController:(UIViewController *)viewController;

+ (void)reloadThisCollectionView:(UICollectionView *)collectionView;

+ (void)gardToView:(UIView *)theView colorOne:(UIColor *)colorOne colorTwo:(UIColor *)colorTwo colorThree:(UIColor *)colorThree rds:(float)rds;

+ (void)setTitle:(NSString *)title onController:(UIViewController *)controller backgroundColor:(UIColor *)bgColor align:(titleAlign)align  masked:(CACornerMask)masked;
+ (UILabel *)getTitleLabel:(NSString *)title onController:(UIViewController *)controller backgroundColor:(UIColor *)bgColor align:(titleAlign)align masked:(CACornerMask)masked fromLabel:(UILabel *)fromLabel;
+ (void)reloadThisCollectionView:(UICollectionView *)collectionView
                      completion:(void (^ __nullable)(BOOL finished))completion;

+ (CGFloat)navigationBarHeightController:(UIViewController *)controller;

+ (void)fetchLottieJSONFromFirebasePath:(NSString *)storagePath
                             completion:(void (^)(NSDictionary *jsonDict, NSError *error))completion;

+(void)reloadThisTableView:(UITableView *)tableView;
+ (void)reloadThisTableView:(UITableView *)tableView
                 completion:(void (^ __nullable)(BOOL finished))completion;
+ (void)smartReloadCollectionView:(UICollectionView *)collectionView
                      oldItemCount:(NSInteger)oldCount
                      newItemCount:(NSInteger)newCount
                       completion:(void (^ __nullable)(BOOL finished))completion;
+ (void)setAnimationNamed:(NSString *)fileName
                   ToView:(LOTAnimationView *)lot
               withSpeed:(float)animationSpeed
              completion:(void (^)(BOOL success))completion;



@end




@interface PetAdCardView : UIView

@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UIImageView *genderIcon;
@property (nonatomic, strong) UILabel *breedLabel;
@property (nonatomic, strong) UIImageView *ageIcon;
@property (nonatomic, strong) UILabel *ageLabel;
@property (nonatomic, strong) UIImageView *locationIcon;
@property (nonatomic, strong) UILabel *locationLabel;

- (void)configureWithPetAd:(PetAd *)pet;

@end













/* ===================================================  PPBannerCollectionCell ======================================================================================================*/

NS_ASSUME_NONNULL_END
