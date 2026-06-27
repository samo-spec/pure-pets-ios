//
//  PPHomeHelper.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 27/12/2025.
//

#import "PPHomeHelper.h"
#import "AccessViewerVC.h"
#import "PPSearchViewController.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

static void *kPPNavLastActionTimestampKey = &kPPNavLastActionTimestampKey;
static const CFTimeInterval kPPNavActionDebounce = 0.35;
static const CFTimeInterval kPPNavRetryDelay = 0.20;

@interface PPHomeHelper ()

+ (BOOL)pp_popToViewControllerSafely:(UIViewController *)viewController
              inNavigationController:(UINavigationController *)navigationController
                            animated:(BOOL)animated;

@end

#pragma mark - 🧩 PPItem (Diffable Item Wrapper)


@implementation PPItem

- (instancetype)init {
    if ((self = [super init])) {
        _identifier = [NSUUID UUID].UUIDString; // ✅ Unique every time
    }
    return self;
}

- (NSUInteger)hash {
    return self.identifier.hash;
}
- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:[PPItem class]]) return NO;
    NSString *otherIdentifier = ((PPItem *)object).identifier;
    if (!self.identifier && !otherIdentifier) {
        return YES;
    }
    return [self.identifier isEqualToString:otherIdentifier];
}
@end






@implementation PPHomeHelper

+ (void)searchTappedFrom:(UIViewController *)controller {
    if (!controller) {
        return;
    }

    PPSearchViewController *searchController = [PPSearchViewController new];
    [searchController focusSearchField];
    PPNavigationController *nav = [[PPNavigationController alloc] initWithRootViewController:searchController];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewControllerSafely:nav from:controller animated:YES completion:nil];
}
+ (UIMenu *)actionsArrayFrom:(UIViewController *)controller
              layoutManager:(PPCollectionLayoutManager *)layoutManager
             collectionView:(UICollectionView *)collectionView
{
    
    NSMutableArray *searchGroup = [NSMutableArray array];
    NSMutableArray *filterGroup = [NSMutableArray array];
    NSMutableArray *layoutGroup = [NSMutableArray array];
    UIAction *searchPPAction = [PPActionButton actionWithTitle:kLang(@"searchOnly")
                                               systemImageName:@"magnifyingglass"
                                                          font:[GM MidFontWithSize:16]
                                                         color:AppSecondaryTextClr
                                                       handler:^(UIAction * _Nonnull action) {
        [self searchTappedFrom:controller];
    }];
    
    
    
    UIAction *filterPPAction = [PPActionButton actionWithTitle:kLang(@"filterPPAction")
                                               systemImageName:@"line.3.horizontal.decrease"
                                                          font:[GM MidFontWithSize:16]
                                                         color:AppSecondaryTextClr
                                                       handler:^(UIAction * _Nonnull action){  }]; //[self filterTapped];
    
    
    /// ------------------------------------------------------------------------------------------------------------------------------------------------------------------
    
    
    UIAction *layoutSquirePPAction = [PPActionButton actionWithTitle:kLang(@"PPCellLayoutSquare")
                                                     systemImageName:@"widget.small"
                                                                font:[GM MidFontWithSize:16]
                                                               color:AppPrimaryTextClr
                                                             handler:^(UIAction * _Nonnull action)  {
        PPManagerCellLayoutMode newMode = PPCellLayoutModeSquare; // or FullWidth, Square, Vertical
        [layoutManager applyLayoutMode:newMode toCollectionView:collectionView animated:YES];
        [[NSUserDefaults standardUserDefaults] setInteger:newMode forKey:kPPLayoutModeKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }];
    
    
    UIAction *layoutFullPPAction = [PPActionButton actionWithTitle:kLang(@"PPCellLayoutFullWidth")
                                                   systemImageName:@"widget.medium"
                                                              font:[GM MidFontWithSize:16]
                                                             color:AppPrimaryTextClr
                                                           handler:^(UIAction * _Nonnull action) {
        PPManagerCellLayoutMode newMode = PPCellLayoutModeFullWidth; // or FullWidth, Square, Vertical
        [layoutManager applyLayoutMode:newMode toCollectionView:collectionView animated:YES];
        [[NSUserDefaults standardUserDefaults] setInteger:newMode forKey:kPPLayoutModeKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }];
    
    
    UIAction *layoutLargePPAction = [PPActionButton actionWithTitle:kLang(@"PPCellLayoutVertical")
                                                    systemImageName:@"widget.extralarge"
                                                               font:[GM MidFontWithSize:16]
                                                              color:AppPrimaryTextClr
                                                            handler:^(UIAction * _Nonnull action) {
        
        PPManagerCellLayoutMode newMode = PPCellLayoutModeVertical; // or FullWidth, Square, Vertical
        [layoutManager applyLayoutMode:newMode toCollectionView:collectionView animated:YES];
        [[NSUserDefaults standardUserDefaults] setInteger:newMode forKey:kPPLayoutModeKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }];

   
    UIAction *layoutPintrestPPAction = [PPActionButton actionWithTitle:kLang(@"Pintrest")
                                                    systemImageName:@"widget.extralarge"
                                                               font:[GM MidFontWithSize:16]
                                                              color:AppPrimaryTextClr
                                                            handler:^(UIAction * _Nonnull action) {
        
        PPManagerCellLayoutMode newMode = PPCellLayoutModePinterest; // or FullWidth, Square, Vertical
        [layoutManager applyLayoutMode:newMode toCollectionView:collectionView animated:YES];
        [[NSUserDefaults standardUserDefaults] setInteger:newMode forKey:kPPLayoutModeKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }];
    
    [searchGroup addObject:searchPPAction];
    [filterGroup addObject:filterPPAction];
    
    [layoutGroup addObject:layoutSquirePPAction];
    [layoutGroup addObject:layoutFullPPAction];
    [layoutGroup addObject:layoutLargePPAction];
    [layoutGroup addObject:layoutPintrestPPAction];
    
    UIMenu *menu;
    
    if (@available(iOS 17.0, *)) {
        menu  = [UIMenu menuWithTitle:kLang(@"searchOnly")
                                image:nil
                           identifier:nil
                              options:UIMenuOptionsDisplayAsPalette
                             children:@[
            [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:searchGroup],
            [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:filterGroup],
            [UIMenu menuWithTitle:kLang(@"PPCellLayout") image:nil identifier:nil options:UIMenuOptionsDisplayInline children:layoutGroup]        ]];
        
        return  menu;
    } else {
     
        menu  = [UIMenu menuWithTitle:@""
                                image:nil
                           identifier:nil
                              options:UIMenuOptionsDisplayInline
                             children:@[
            [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:searchGroup],
            [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:filterGroup],
            [UIMenu menuWithTitle:kLang(@"PPCellLayout") image:nil identifier:nil options:UIMenuOptionsDisplayInline children:layoutGroup]
        ]];
        
    }
    
    return  menu;
}


+ (MainKindsModel *)allMainKind
{
    MainKindsModel *all = [MainKindsModel new];
    all.ID = -1; // reserved
    all.KindName = kLang(@"All");
    all.KindImageUrl = nil; // handled by UI
    return all;
}
+ (NSArray<MainKindsModel *> *)categoriesDataSource
{
    NSMutableArray *result = [NSMutableArray array];

    // 1️⃣ Add "All"
    [result addObject:[self allMainKind]];

    // 2️⃣ Add MainKinds
    if (PPMainKindsArray.count > 0) {
        [result addObjectsFromArray:PPMainKindsArray];
    }

    return result;
}



#pragma mark - Routing Helpers

+ (PPDataSection)sectionFromSourceTarget:(PPDeepLinkTarget)target
{
    switch (target) {

        case PPDeepLinkTargetAds:
            return PPDataSectionAds;

        case PPDeepLinkTargetAccessories:
            return PPDataSectionAccessories;

        case PPDeepLinkTargetFood:
            return PPDataSectionFood;

       //case PPDeepLinkTargetVet:
            //return PPDataSectionVets;

        case PPDeepLinkTargetServices:
            return PPDataSectionServices;

        default:
            return PPDataSectionAds; // safe default
    }
}


+ (NSArray<PPUniversalCellViewModel *> *) pp_generateNearbyAdViewModelsFromAds:(NSArray<PetAd *> *)ads
{
    if (ads.count == 0) return @[];

    NSMutableArray<PPUniversalCellViewModel *> *result =
    [NSMutableArray arrayWithCapacity:ads.count];

    for (PetAd *ad in ads) {

        PPUniversalCellViewModel *vm =
        [[PPUniversalCellViewModel alloc]
         initWithModel:ad
         context:PPCellForAds];

        // ===============================
        // Identity
        // ===============================
        vm.ModelID   = ad.adID ?: UUIDJoin(@"ADVM");
        vm.ppSection = PPSectionNearByAds;

        // ===============================
        // Image
        // ===============================
        NSString *imageURL = nil;
        UIImage *placeholder = [UIImage imageNamed:@"placeholder"];

        PetImageItem *firstItem = ad.imageItems.firstObject;
        if (firstItem) {
            imageURL = firstItem.url;

            if (firstItem.blurHash.length > 0) {
                placeholder =
                [PPBlurHashBridge  imageFrom:firstItem.blurHash
                             syncSize:CGSizeMake(40, 40)
                            punch:1.0];
            }
        }

        vm.imageURL = imageURL;
        vm.placeholder = placeholder;

        // ===============================
        // Text
        // ===============================
        vm.title =
        ad.adTitle.length ? ad.adTitle : kLang(@"PetAd");

        NSString *locationText = ad.locationName;
        if (locationText.length == 0 && ad.adLocation > 0) {
            locationText = [CitiesManager.shared cityNameForID:ad.adLocation];
        }
        vm.subtitle = locationText ?: @"";


        // ===============================
        // Flags
        // ===============================
        vm.isOwner  = ad.ownerID && [ad.ownerID isEqualToString:PPCurrentUser.ID];
 

        [result addObject:vm];
    }

    return result.copy;
}


+ (NSArray<MainKindsModel *> *)filteredMainKindsForHomeTraning {

    NSSet<NSNumber *> *allowedIDs =
    [NSSet setWithArray:@[@6, @5, @3]];

    NSPredicate *predicate =
    [NSPredicate predicateWithBlock:^BOOL(MainKindsModel *evaluatedObject,
                                          NSDictionary *bindings) {

        return [allowedIDs containsObject:@(evaluatedObject.ID)];
    }];

    return [MKM.MainKindsArray filteredArrayUsingPredicate:predicate];
}
+ (UIMenu *)trainingMenuWithHandler:(void (^)(MainKindsModel * _Nonnull))handler {
    return [PPActionButton generateActionsForMainKind:self.filteredMainKindsForHomeTraning tintColor:AppPrimaryTextClr handler:^(MainKindsModel * _Nonnull category) {
        // [weakSelf showAccessoriesVC:category];
        if (handler) {
                   handler(category);
               }
    }];
}

+ (NSArray<MainKindsModel *> *)filteredMainKindsForHomeGroomin {

    NSSet<NSNumber *> *allowedIDs =
    [NSSet setWithArray:@[@6,@5,@4, @3, @2, @10]];

    NSPredicate *predicate =
    [NSPredicate predicateWithBlock:^BOOL(MainKindsModel *evaluatedObject,
                                          NSDictionary *bindings) {

        return [allowedIDs containsObject:@(evaluatedObject.ID)];
    }];

    return [MKM.MainKindsArray filteredArrayUsingPredicate:predicate];
}
+ (UIMenu *)groomingMenuWithHandler:(void (^)(MainKindsModel * _Nonnull))handler {
    //__weak typeof(self) weakSelf = self;
    return [PPActionButton generateActionsForMainKind:self.filteredMainKindsForHomeGroomin tintColor:AppPrimaryTextClr handler:^(MainKindsModel * _Nonnull category) {
       // [weakSelf showAccessoriesVC:category];
        if (handler) {
                   handler(category);
               }
    }];
}

+ (UIMenu *)accessoriesMenu  {
    //__weak typeof(self) weakSelf = self;
    return [PPActionButton generateActionsForMainKind:MKM.MainKindsArray tintColor:AppPrimaryTextClr handler:^(MainKindsModel * _Nonnull category) {

    }];
}

+ (UIMenu *)MainKindsMenuWithHandler:(void (^)(MainKindsModel * _Nonnull))handler
{
    return [self accessoriesMenuWithHandler:handler];
}
+ (UIMenu *)accessoriesMenuWithHandler:(void (^)(MainKindsModel * _Nonnull))handler {
    //__weak typeof(self) weakSelf = self;
    return [PPActionButton generateActionsForMainKind:MKM.MainKindsArray tintColor:AppPrimaryTextClr handler:^(MainKindsModel * _Nonnull category) {
       // [weakSelf showAccessoriesVC:category];
        if (handler) {
                   handler(category);
               }
    }];
}

+ (UIMenu *)foodMenuWithHandler:(void (^)(MainKindsModel * _Nonnull))handler {
    //__weak typeof(self) weakSelf = self;
    return [PPActionButton generateActionsForMainKind:MKM.MainKindsArray tintColor:AppPrimaryTextClr handler:^(MainKindsModel * _Nonnull category) {
        if (handler) {
                   handler(category);
               }
       // [weakSelf showFoodVC:category];
    }];
}

+ (void)presentMenu:(UIMenu *)menu fromView:(UIView *)sourceView {

    if (!menu || !sourceView) return;

    if (@available(iOS 14.0, *)) {

        // Use a hidden button to present the menu correctly
        UIButton *menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
        menuButton.menu = menu;
        menuButton.showsMenuAsPrimaryAction = YES;

        // Invisible but interactive
        menuButton.frame = sourceView.bounds;
        menuButton.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        menuButton.alpha = 0.01;

        [sourceView addSubview:menuButton];

        // Trigger menu
        dispatch_async(dispatch_get_main_queue(), ^{
            [menuButton sendActionsForControlEvents:UIControlEventTouchUpInside];
        });
    }
}
+ (UINavigationController *)currentNavigationControllerFor:(UIViewController *)vc {

    if (!vc) {
        NSLog(@"❌ [NavResolver] vc is nil");
        return nil;
    }

    // 1️⃣ VC already inside a navigation controller
    if ([vc.navigationController isKindOfClass:UINavigationController.class]) {
        NSLog(@"✅ [NavResolver] Using vc.navigationController: %@",
              vc.navigationController);
        return vc.navigationController;
    }

    // 2️⃣ VC IS a tab bar controller (ROOT CASE)
    if ([vc isKindOfClass:UITabBarController.class]) {
        UITabBarController *tab = (UITabBarController *)vc;
        UIViewController *selected = tab.selectedViewController;

        if ([selected isKindOfClass:UINavigationController.class]) {
            NSLog(@"✅ [NavResolver] Using root tabBar.selectedViewController: %@",
                  selected);
            return (UINavigationController *)selected;
        }

        // Selected VC wrapped later
        if (selected.navigationController) {
            NSLog(@"✅ [NavResolver] Using selected.navigationController: %@",
                  selected.navigationController);
            return selected.navigationController;
        }
    }

    // 3️⃣ VC is inside a tab bar
    if ([vc.tabBarController.selectedViewController
         isKindOfClass:UINavigationController.class]) {

        NSLog(@"✅ [NavResolver] Using vc.tabBarController.selectedViewController: %@",
              vc.tabBarController.selectedViewController);

        return (UINavigationController *)vc.tabBarController.selectedViewController;
    }

    NSLog(@"⚠️ [NavResolver] No navigation controller found. "
          @"vc=%@ (%@)",
          vc,
          NSStringFromClass(vc.class));

    return nil;
}

+ (BOOL)pp_canNavigateWithNavigationController:(UINavigationController *)nav
{
    if (!nav) {
        return NO;
    }

    if (!nav.view.window) {
        return NO;
    }

    if (nav.transitionCoordinator) {
        return NO;
    }

    UIViewController *top = nav.topViewController;
    if (!top) {
        return NO;
    }

    if (top.isBeingPresented || top.isBeingDismissed) {
        return NO;
    }

    if (top.presentedViewController && !top.presentedViewController.isBeingDismissed) {
        return NO;
    }

    CFTimeInterval now = CACurrentMediaTime();
    NSNumber *lastTimestamp = objc_getAssociatedObject(nav, kPPNavLastActionTimestampKey);
    if (lastTimestamp && (now - lastTimestamp.doubleValue) < kPPNavActionDebounce) {
        return NO;
    }
    objc_setAssociatedObject(nav,
                             kPPNavLastActionTimestampKey,
                             @(now),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return YES;
}

+ (UIViewController *)pp_topMostPresenterFrom:(UIViewController *)sourceVC
{
    if (!sourceVC) {
        return nil;
    }

    UIViewController *presenter = sourceVC;

    if ([presenter isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tab = (UITabBarController *)presenter;
        UIViewController *selected = tab.selectedViewController;
        if ([selected isKindOfClass:[UINavigationController class]]) {
            presenter = ((UINavigationController *)selected).topViewController ?: selected;
        } else if (selected) {
            presenter = selected;
        }
    } else if ([presenter isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)presenter;
        presenter = nav.topViewController ?: nav;
    }

    while (presenter.presentedViewController && !presenter.presentedViewController.isBeingDismissed) {
        presenter = presenter.presentedViewController;
    }

    return presenter;
}

+ (BOOL)pushViewControllerSafely:(UIViewController *)viewController
                            from:(UIViewController *)sourceVC
                        animated:(BOOL)animated
{
    if (!viewController || !sourceVC) {
        return NO;
    }

    UINavigationController *nav = [self currentNavigationControllerFor:sourceVC];
    if (![self pp_canNavigateWithNavigationController:nav]) {
        // Retry once after transient transitions (e.g. just-dismissed sheet).
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kPPNavRetryDelay * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (![self pp_canNavigateWithNavigationController:nav]) {
                return;
            }
            if (viewController.navigationController || viewController.parentViewController || viewController.presentingViewController) {
                return;
            }
            [nav pushViewController:viewController animated:animated];
        });
        return NO;
    }

    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [nav pushViewController:viewController animated:animated];
        });
    } else {
        [nav pushViewController:viewController animated:animated];
    }
    return YES;
}

+ (BOOL)pp_popToViewControllerSafely:(UIViewController *)viewController
              inNavigationController:(UINavigationController *)navigationController
                            animated:(BOOL)animated
{
    if (!viewController || !navigationController) {
        return NO;
    }

    if (![self pp_canNavigateWithNavigationController:navigationController]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kPPNavRetryDelay * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (![self pp_canNavigateWithNavigationController:navigationController]) {
                return;
            }
            if (![navigationController.viewControllers containsObject:viewController]) {
                return;
            }
            [navigationController popToViewController:viewController animated:animated];
        });
        return NO;
    }

    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [navigationController popToViewController:viewController animated:animated];
        });
    } else {
        [navigationController popToViewController:viewController animated:animated];
    }
    return YES;
}

+ (BOOL)presentViewControllerSafely:(UIViewController *)viewController
                               from:(UIViewController *)sourceVC
                           animated:(BOOL)animated
                         completion:(void (^ _Nullable)(void))completion
{
    if (!viewController || !sourceVC) {
        return NO;
    }

    UIViewController *presenter = [self pp_topMostPresenterFrom:sourceVC];
    if (!presenter || presenter.isBeingPresented || presenter.isBeingDismissed) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kPPNavRetryDelay * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            UIViewController *retryPresenter = [self pp_topMostPresenterFrom:sourceVC];
            if (!retryPresenter || retryPresenter.isBeingPresented || retryPresenter.isBeingDismissed) {
                return;
            }
            if (viewController.presentingViewController || viewController.parentViewController) {
                return;
            }
            [retryPresenter presentViewController:viewController animated:animated completion:completion];
        });
        return NO;
    }

    if (presenter.presentedViewController && !presenter.presentedViewController.isBeingDismissed) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kPPNavRetryDelay * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            UIViewController *retryPresenter = [self pp_topMostPresenterFrom:sourceVC];
            if (!retryPresenter || retryPresenter.presentedViewController) {
                return;
            }
            if (viewController.presentingViewController || viewController.parentViewController) {
                return;
            }
            [retryPresenter presentViewController:viewController animated:animated completion:completion];
        });
        return NO;
    }

    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [presenter presentViewController:viewController animated:animated completion:completion];
        });
    } else {
        [presenter presentViewController:viewController animated:animated completion:completion];
    }
    return YES;
}
@end




@implementation PPHomeProfileView

- (CGSize)intrinsicContentSize {
    return self.fixedSize.width > 0 ? self.fixedSize : [super intrinsicContentSize];
}

- (CGSize)sizeThatFits:(CGSize)size {
    return self.fixedSize.width > 0 ? self.fixedSize : [super sizeThatFits:size];
}


@end





@implementation PPHomeAdoptItem
@end


@implementation PPCategoryItem
@end
