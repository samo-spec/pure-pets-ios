//
//  PPHomeHelper.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 27/12/2025.
//

#import <Foundation/Foundation.h>
#import "PPCarouselContainerCell.h"
#import "PPHomeSectionDividerView.h"
#import "PPHomeSectionBackgroundView.h"
#import "PPCarouselItem.h"
#import "PPSectionHeaderView.h"
#import "PPUniversalCellViewModel.h"
#import "PetAd.h"
#import "PPCollectionLayoutManager.h"

NS_ASSUME_NONNULL_BEGIN
 
@interface PPItem : NSObject
@property (nonatomic,
           copy) NSString *identifier; ///< Unique item identifier (UUID)
@property (nonatomic, strong) PPUniversalCellViewModel *universalViewModel;
@property (nonatomic, assign) CGSize imageSize;

@end
 




@interface PPHomeProfileView : UIButton
@property (nonatomic, assign) CGSize fixedSize;
@end

@interface PPHomeHelper : NSObject


+ (UIMenu *)actionsArrayFrom:(UIViewController *)controller
              layoutManager:(PPCollectionLayoutManager *)layoutManager
             collectionView:(UICollectionView *)collectionView;
+ (NSArray<MainKindsModel *> *)categoriesDataSource;
+ (MainKindsModel *)allMainKind;
+ (PPDataSection)sectionFromSourceTarget:(PPDeepLinkTarget)target;
+ (NSArray<PPUniversalCellViewModel *> *)pp_generateNearbyAdViewModelsFromAds:(NSArray<PetAd *> *)ads;
+ (UINavigationController *)currentNavigationControllerFor:(UIViewController *)vc ;
+ (BOOL)pushViewControllerSafely:(UIViewController *)viewController
                            from:(UIViewController *)sourceVC
                        animated:(BOOL)animated;
+ (BOOL)presentViewControllerSafely:(UIViewController *)viewController
                               from:(UIViewController *)sourceVC
                           animated:(BOOL)animated
                         completion:(void (^ _Nullable)(void))completion;
+ (UIMenu *)accessoriesMenuWithHandler: (void (^)(MainKindsModel *category))handler;

+ (UIMenu *)foodMenuWithHandler:
    (void (^)(MainKindsModel *category))handler;
+ (UIMenu *)accessoriesMenu;
+ (void)presentMenu:(UIMenu *)menu fromView:(UIView *)sourceView ;


+ (UIMenu *)groomingMenuWithHandler: (void (^)(MainKindsModel *category))handler;
+ (UIMenu *)trainingMenuWithHandler: (void (^)(MainKindsModel *category))handler;
+ (UIMenu *)MainKindsMenuWithHandler:(void (^)(MainKindsModel * _Nonnull))handler;
//+ (UIMenu *)actionsArray;

@property (nonatomic, strong) UICollectionView *collectionView;
@end


 


@protocol PPImageLoader <NSObject>

- (void)loadImageWithURL:(NSURL *)url
                intoView:(UIImageView *)imageView
              placeholder:(UIImage *)placeholder;

- (void)cancelLoadForView:(UIImageView *)imageView;

@end


@interface PPHomeAdoptItem : NSObject
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *systemIconName;
@property (nonatomic, assign) PPHomeItemType type;
@end


@interface PPCategoryItem : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *imageName;
@end


 
NS_ASSUME_NONNULL_END
