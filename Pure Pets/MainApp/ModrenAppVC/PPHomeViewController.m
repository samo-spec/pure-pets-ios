#import "PPHomeViewController.h"

#import "AddNewAccessory.h"
#import "AddNewAd.h"
#import "AdoptPetsViewController.h"
#import "AppClasses.h"
#import "CartManager.h"
#import "CartViewController.h"
#import "LocationPickerViewController.h"
#import "MainKindsArrayManager.h"
#import "MainKindsModel.h"
#import "OrderDetailsViewController.h"
#import "OrderHistoryViewController.h"
#import "PPAdSharingHelper.h"
#import "PPBannersManager.h"
#import "PPBrowseHistoryManager.h"
#import "PPChatsFunc.h"
#import "PPDataViewInput.h"
#import "PPFunc.h"
#import "PPHomeHelper.h"
#import "PPHomeLocationSheetViewController.h"
#import "PPHUD.h"
#import "PPNavigationController.h"
#import "PPNovaChatViewController.h"
#import "PPOverlayCoordinator.h"
#import "PPPetCareViewController.h"
#import "PPPetProfile.h"
#import "PPPetProfileEditorViewController.h"
#import "PPPetProfilesViewController.h"
#import "PPRootTabBarController.h"
#import "PPSaveForLaterManager.h"
#import "PPSearchViewController.h"
#import "PPUniversalCell.h"
#import "PPUniversalCellViewModel.h"
#import "PetAccessory.h"
#import "PetAccessoryManager.h"
#import "PetAd.h"
#import "PetAdManager.h"
#import "ProviderCompaniesListVC.h"
#import <Pure_Pets-Swift.h>
#import <SafariServices/SafariServices.h>
#import <float.h>
#import <math.h>
#import <os/signpost.h>

static os_log_t PPHomeShellPerformanceLog(void)
{
    static os_log_t log;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        log = os_log_create("com.purepets", "HomeSwiftUI");
    });
    return log;
}

static NSString *PPHomeShellString(id value)
{
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    return [(NSString *)value
        stringByTrimmingCharactersInSet:
            NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static NSArray<MainKindsModel *> *PPHomeShellMainKinds(void)
{
    NSArray<MainKindsModel *> *kinds = PPMainKindsArray;
    if (kinds.count == 0) {
        kinds = MainKindsArrayManager.shared.MainKindsArray;
    }
    return [kinds isKindOfClass:NSArray.class] ? kinds : @[];
}

@interface PPHomeViewController ()
@property (nonatomic, strong) PPHomeHostingController *homeHostingController;
@end

@implementation PPHomeViewController

#pragma mark - Lifecycle and compatibility host

- (instancetype)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _mainKindsLayoutMode = PPMainKindsLayoutModeCollapsed;
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil
                         bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _mainKindsLayoutMode = PPMainKindsLayoutModeCollapsed;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _mainKindsLayoutMode = PPMainKindsLayoutModeCollapsed;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.ppBackground;
    self.navigationItem.largeTitleDisplayMode =
        UINavigationItemLargeTitleDisplayModeNever;

    PPHomeHostingController *host =
        [[PPHomeHostingController alloc] initWithOwner:self];
    self.homeHostingController = host;
    [self addChildViewController:host];
    host.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:host.view];
    [NSLayoutConstraint activateConstraints:@[
        [host.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [host.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [host.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [host.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
    [host didMoveToParentViewController:self];

    if (self.initialSelectedMainKindID > 0) {
        [host setInitialMainKindID:self.initialSelectedMainKindID];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];

    if ([self.tabBarController
            isKindOfClass:PPRootTabBarController.class]) {
        PPRootTabBarController *root =
            (PPRootTabBarController *)self.tabBarController;
        [root setPremiumTabDockViewHidden:NO animation:NO];
        [root pp_setBottomNavigationHidden:NO animated:animated];
    }
    [self.homeHostingController homeWillAppear];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self.homeHostingController homeDidDisappear];
}

- (void)setInitialSelectedMainKindID:(NSInteger)initialSelectedMainKindID
{
    _initialSelectedMainKindID = initialSelectedMainKindID;
    if (self.isViewLoaded && initialSelectedMainKindID > 0) {
        [self.homeHostingController
            setInitialMainKindID:initialSelectedMainKindID];
    }
}

- (void)pp_homeRefresh
{
    [self.homeHostingController refresh];
}

- (CGFloat)pp_homeBottomContentClearance
{
    if ([self.tabBarController
            isKindOfClass:PPRootTabBarController.class]) {
        return [(PPRootTabBarController *)self.tabBarController
            pp_currentBottomNavigationContentClearance];
    }
    return 8.0;
}

- (void)pp_homeHandleReselection
{
    [self.homeHostingController handleReselection];
}

#pragma mark - Command routes

- (void)pp_homeOpenSearch
{
    PPSearchViewController *search = [PPSearchViewController new];
    PPNavigationController *navigation =
        [[PPNavigationController alloc] initWithRootViewController:search];
    navigation.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:navigation
                       animated:YES
                     completion:^{
        [search focusSearchField];
    }];
}

- (void)pp_homeOpenCart
{
    if (![PPFunc PPUserCheck]) {
        return;
    }
    CartViewController *cart = [CartViewController new];
    [PPHomeHelper pushViewControllerSafely:cart from:self animated:YES];
}

- (void)pp_homeOpenObject:(id)object
{
    if (!object) {
        return;
    }
    if ([object isKindOfClass:PetAd.class]) {
        PetAd *advertisement = object;
        [PPBrowseHistoryManager.shared
            trackItemWithType:PPBrowseItemTypeAd
                   mainKindID:advertisement.category];
    } else if ([object isKindOfClass:PetAccessory.class]) {
        PetAccessory *accessory = object;
        [PPBrowseHistoryManager.shared
            trackItemWithType:PPBrowseItemTypeAccessory
                   mainKindID:accessory.petMainCategoryID];
    }

    [PPOverlayCoordinator pp_openDetailForObject:object
                                         fromVC:self
                                     routingNav:nil];
}

- (void)pp_homeOpenMainKind:(NSObject *)object
{
    if (![object isKindOfClass:MainKindsModel.class]) {
        return;
    }
    MainKindsModel *mainKind = (MainKindsModel *)object;

    os_log_t log = PPHomeShellPerformanceLog();
    os_signpost_id_t signpostID = os_signpost_id_generate(log);
    os_signpost_interval_begin(
        log,
        signpostID,
        "home.category.route",
        "kind=%{public}@",
        mainKind.KindName ?: @""
    );

    PPDataViewInput *input =
        [PPDataViewInput inputWithMainKind:mainKind
                              sourceTarget:PPDeepLinkTargetAds
                                    source:PPInputSourceHomeMainKindsSection];
    input.mainKindsArr = PPHomeShellMainKinds();
    input.initialSectionOverride = @(PPDataSectionAds);

    PPMarketplaceDataViewController *destination =
        [[PPMarketplaceDataViewController alloc] initWithInput:input];
    destination.pp_transitionStyle = PPTransitionStyleNone;
    BOOL didPush =
        [PPHomeHelper pushViewControllerSafely:destination
                                          from:self
                                      animated:YES];
    os_signpost_interval_end(
        log,
        signpostID,
        "home.category.route",
        "status=%{public}@",
        didPush ? @"success" : @"failed"
    );
}

- (UIViewController *)buildDataViewVCForTarget:(PPDeepLinkTarget)target
                                  mainKind:(MainKindsModel *)mainKind
                                    source:(PPInputSource)source
{
    PPDataViewInput *input =
        [PPDataViewInput inputWithMainKind:mainKind
                              sourceTarget:target
                                    source:source];
    if (!input) {
        return nil;
    }
    input.mainKindsArr = PPHomeShellMainKinds();
    input.initialSectionOverride =
        @([PPHomeHelper sectionFromSourceTarget:target]);

    PPMarketplaceDataViewController *destination =
        [[PPMarketplaceDataViewController alloc] initWithInput:input];
    destination.pp_transitionStyle = PPTransitionStyleNone;
    return destination;
}

- (void)pp_homeOpenDeepLinkTarget:(PPDeepLinkTarget)target
                         mainKind:(NSObject *)object
                           source:(PPInputSource)source
{
    MainKindsModel *mainKind =
        [object isKindOfClass:MainKindsModel.class]
            ? (MainKindsModel *)object
            : nil;
    UIViewController *destination = nil;
    if (target == PPDeepLinkTargetAllCategories) {
        PPDataViewInput *input =
            [PPDataViewInput inputWithMainKindsArr:PPHomeShellMainKinds()
                                      sourceTarget:target
                                            source:source];
        destination = [[PPMarketplaceDataViewController alloc] initWithInput:input];
        destination.pp_transitionStyle = PPTransitionStyleNone;
    } else {
        destination =
            [self buildDataViewVCForTarget:target
                                  mainKind:mainKind
                                    source:source];
    }
    if (destination) {
        [PPHomeHelper pushViewControllerSafely:destination
                                          from:self
                                      animated:YES];
    }
}

- (void)pp_homeOpenPetProfiles
{
    UIViewController *destination = [PPPetProfilesViewController new];
    [PPHomeHelper pushViewControllerSafely:destination
                                      from:self
                                  animated:YES];
}

- (void)pp_homeOpenPetEditor:(NSObject *)object
{
    PPPetProfile *pet =
        [object isKindOfClass:PPPetProfile.class]
            ? (PPPetProfile *)object
            : nil;
    UIViewController *destination =
        [[PPPetProfileEditorViewController alloc] initWithPet:pet];
    [PPHomeHelper pushViewControllerSafely:destination
                                      from:self
                                  animated:YES];
}

- (void)pp_homeOpenOrder:(NSObject *)object
{
    if (![object isKindOfClass:PPOrder.class]) {
        return;
    }
    PPOrder *order = (PPOrder *)object;
    OrderDetailsViewController *destination =
        [[OrderDetailsViewController alloc] initWithOrder:order];
    destination.order = order;
    [PPHomeHelper pushViewControllerSafely:destination
                                      from:self
                                  animated:YES];
}

- (void)pp_homeOpenOrderHistory
{
    if (![PPFunc PPUserCheck]) {
        return;
    }
    [PPHomeHelper pushViewControllerSafely:[OrderHistoryViewController new]
                                      from:self
                                  animated:YES];
}

- (void)pp_homeOpenCareSection:(NSInteger)section
                      mainKind:(NSObject *)object
{
    MainKindsModel *mainKind =
        [object isKindOfClass:MainKindsModel.class]
            ? (MainKindsModel *)object
            : nil;
    PPPetCareInitialSection initialSection =
        section == PPPetCareInitialSectionVeterinarians
            ? PPPetCareInitialSectionVeterinarians
            : PPPetCareInitialSectionMedicines;
    PPPetCareViewController *destination =
        [[PPPetCareViewController alloc]
            initWithInitialSection:initialSection
                         mainKind:mainKind];
    destination.hidesBottomBarWhenPushed = YES;
    [PPHomeHelper pushViewControllerSafely:destination
                                      from:self
                                  animated:YES];
}

- (void)pp_homeOpenAdoption
{
    AdoptPetsViewController *destination =
        [AdoptPetsViewController new];
    destination.pp_transitionStyle = PPTransitionStyleNone;
    [PPHomeHelper pushViewControllerSafely:destination
                                      from:self
                                  animated:YES];
}

- (void)pp_homeOpenProviderCategoryIdentifier:(NSString *)identifier
                                     titleKey:(NSString *)titleKey
                                  subtitleKey:(NSString *)subtitleKey
{
    ProviderCompaniesListVC *destination =
        [ProviderCompaniesListVC new];
    destination.selectedProviderCategoryIdentifier =
        PPHomeShellString(identifier);
    destination.selectedProviderCategoryTitleKey =
        PPHomeShellString(titleKey);
    destination.selectedProviderCategorySubtitleKey =
        PPHomeShellString(subtitleKey);
    [PPHomeHelper pushViewControllerSafely:destination
                                      from:self
                                  animated:YES];
}

- (void)pp_homeOpenNova
{
    [PPNovaChatViewController presentNovaFromViewController:self];
}

#pragma mark - Promotion routes

- (MainKindsModel *)pp_homeMainKindWithID:(NSInteger)identifier
{
    for (MainKindsModel *kind in PPHomeShellMainKinds()) {
        if (kind.ID == identifier) {
            return kind;
        }
    }
    return nil;
}

- (void)pp_homeHandlePromotionAction:(PPBannerOnTapAction)action
                               value:(NSString *)value
{
    NSString *safeValue = PPHomeShellString(value);
    switch (action) {
        case PPBannerOnTapViewAccessory:
        case PPBannerOnTapViewAd: {
            MainKindsModel *kind =
                [self pp_homeMainKindWithID:safeValue.integerValue];
            PPDeepLinkTarget target =
                action == PPBannerOnTapViewAccessory
                    ? PPDeepLinkTargetAccessories
                    : PPDeepLinkTargetAds;
            PPInputSource source =
                action == PPBannerOnTapViewAccessory
                    ? PPInputSourceHomeAccessoriesSection
                    : PPInputSourceHomeNearBySection;
            [self pp_homeOpenDeepLinkTarget:target
                                   mainKind:kind
                                     source:source];
            break;
        }
        case PPBannerOnTapOpenUrl: {
            if (safeValue.length == 0) {
                return;
            }
            NSString *urlString = safeValue;
            if (![urlString containsString:@"://"]) {
                urlString =
                    [NSString stringWithFormat:@"https://%@", urlString];
            }
            NSURL *url = [NSURL URLWithString:urlString];
            if (!url) {
                return;
            }
            SFSafariViewController *browser =
                [[SFSafariViewController alloc] initWithURL:url];
            [PPFunc presentSheetFrom:self
                             sheetVC:browser
                         detentStyle:PPSheetDetentStyle80];
            break;
        }
        case PPBannerOnTapCallPhoneNumber:
            [AppClasses callPhoneNumber:safeValue
                     fromViewController:self];
            break;
        case PPBannerOnTapWhatsApp:
            [AppClasses startWhatsAppWith:safeValue
                       fromViewController:self];
            break;
    }
}

- (void)pp_homeOpenPromoCard:(NSObject *)object
                  interaction:(NSString *)interaction
{
    if (![object isKindOfClass:PPHomePromoCarouselCard.class]) {
        return;
    }
    PPHomePromoCarouselCard *card = (PPHomePromoCarouselCard *)object;
    if ([interaction isEqualToString:@"primary"]) {
        [self pp_homeHandlePromotionAction:card.primaryButtonTapAction
                                     value:card.primaryButtonTapValue];
    } else if ([interaction isEqualToString:@"secondary"]) {
        [self pp_homeHandlePromotionAction:card.secondaryButtonTapAction
                                     value:card.secondaryButtonTapValue];
    } else {
        [self pp_homeHandlePromotionAction:card.cardTapAction
                                     value:card.cardTapValue];
    }
}

#pragma mark - Location routes

- (void)pp_homeOpenLocationPicker
{
    LocationPickerViewController *picker =
        [LocationPickerViewController new];
    picker.hidesBottomBarWhenPushed = YES;

    __weak typeof(self) weakSelf = self;
    void (^applyCoordinate)(CLLocationCoordinate2D, NSString *) =
        ^(CLLocationCoordinate2D coordinate, NSString *title) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self ||
            !CLLocationCoordinate2DIsValid(coordinate) ||
            (fabs(coordinate.latitude) < DBL_EPSILON &&
             fabs(coordinate.longitude) < DBL_EPSILON)) {
            return;
        }
        NSString *resolvedTitle = PPHomeShellString(title);
        if (resolvedTitle.length == 0) {
            resolvedTitle =
                kLang(@"Select your location") ?: @"Select your location";
        }
        [self.homeHostingController
            applyManualLocationWithLatitude:coordinate.latitude
                                  longitude:coordinate.longitude
                                      title:resolvedTitle];
    };

    picker.onLocationConfirmed = ^(GMSAddress *address) {
        if (!address) {
            return;
        }
        NSString *title =
            [LocationPickerViewController titleFromAddress:address];
        if (title.length == 0 && address.lines.count > 0) {
            title = [address.lines componentsJoinedByString:@", "];
        }
        if (title.length == 0) {
            title = address.country;
        }
        applyCoordinate(address.coordinate, title);
    };
    picker.onCoordinateConfirmed =
        ^(CLLocationCoordinate2D coordinate, NSString *title) {
        applyCoordinate(coordinate, title);
    };

    if (self.navigationController) {
        [self.navigationController pushViewController:picker animated:YES];
    } else {
        [PPFunc presentFloatingSheetFrom:self
                                 sheetVC:picker
                             detentStyle:PPSheetDetentStyle80];
    }
}

- (void)pp_homePresentLocationOptions
{
    if (self.presentedViewController ||
        self.isBeingPresented ||
        self.isBeingDismissed) {
        return;
    }

    PPHomeLocationSheetViewController *sheet =
        [[PPHomeLocationSheetViewController alloc] init];
    sheet.sheetTitleText =
        kLang(@"home_location_sheet_title") ?: @"Choose your smart location";
    sheet.sheetSubtitleText =
        kLang(@"home_location_sheet_subtitle") ?:
            @"Use your current position or choose an area manually.";

    NSString *areaName =
        PPHomeShellString(self.homeHostingController.homeLocationAreaName);
    sheet.currentLocationTitle =
        areaName.length > 0
            ? areaName
            : (kLang(@"Select your location") ?: @"Select your location");

    NSInteger presentation =
        self.homeHostingController.homeLocationPresentationRawValue;
    BOOL needsSettings = presentation == 3 || presentation == 4;
    NSString *subtitleKey = @"home_location_sheet_current_subtitle_unset";
    if (needsSettings) {
        subtitleKey = @"home_location_sheet_current_subtitle_denied";
    } else if (self.homeHostingController.homeLocationUsesManualSelection) {
        subtitleKey = @"home_location_sheet_current_subtitle_manual";
    } else if (presentation == 2) {
        subtitleKey = @"home_location_sheet_current_subtitle_auto";
    }
    sheet.currentLocationSubtitle = kLang(subtitleKey) ?: @"";
    sheet.showsUseCurrentLocationAction = !needsSettings;
    sheet.showsOpenSettingsAction = needsSettings;
    sheet.recentLocations = @[];

    __weak typeof(self) weakSelf = self;
    sheet.onUseCurrentLocation = ^{
        [weakSelf.homeHostingController useAutomaticLocation];
    };
    sheet.onChangeArea = ^{
        [weakSelf pp_homeOpenLocationPicker];
    };
    sheet.onOpenSettings = ^{
        [weakSelf pp_homeOpenLocationSettings];
    };

    [PPFunc presentFloatingSheetFrom:self
                             sheetVC:sheet
                         detentStyle:PPSheetDetentStyle80];
}

- (void)pp_homeOpenLocationSettings
{
    NSURL *url =
        [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if ([UIApplication.sharedApplication canOpenURL:url]) {
        [UIApplication.sharedApplication
            openURL:url
            options:@{}
            completionHandler:nil];
    }
}

#pragma mark - Universal card delegate

- (void)PPUniversalCell_tapCard:
    (PPUniversalCellViewModel *)universalModel
{
    [self pp_homeOpenObject:universalModel.ModelObject];
}

- (void)PPUniversalCell_changeQuantity:
            (PPUniversalCellViewModel *)universalModel
                              quantity:(NSInteger)quantity
{
    if (![universalModel.ModelObject
            isKindOfClass:PetAccessory.class]) {
        return;
    }

    PetAccessory *accessory = universalModel.ModelObject;
    NSInteger stockLimit = MAX(accessory.quantity, 0);
    NSInteger safeQuantity = MAX(quantity, 0);
    if (stockLimit <= 0 && safeQuantity > 0) {
        [PPHUD showError:kLang(@"Out of stock")];
        safeQuantity = 0;
    } else if (safeQuantity > stockLimit) {
        safeQuantity = stockLimit;
        [PPHUD showInfo:
            [NSString stringWithFormat:@"%@ %ld %@",
                kLang(@"Only") ?: @"Only",
                (long)stockLimit,
                kLang(@"left in stock") ?: @"left in stock"]];
    }

    CartManager *cart = CartManager.sharedManager;
    if (safeQuantity == 0) {
        [PPFunc triggerWarningHaptic];
        [cart removeItemForAccessory:accessory];
        [self pp_homePublishCartMutation];
        return;
    }

    CartItem *existing = nil;
    if (accessory.accessoryID.length > 0) {
        existing = [cart getCartItemForItemID:accessory.accessoryID];
    }
    if (!existing && accessory.accessoryID.length > 0) {
        existing = [cart getCartItemForItemID:accessory.accessoryID];
    }

    CartItem *item =
        [[CartItem alloc] initWithAccessory:accessory
                                  quantity:safeQuantity];
    if (existing) {
        [cart updateQuantity:safeQuantity
                    forItem:item
                 completion:nil];
        safeQuantity == 1
            ? [PPFunc triggerLightHaptic]
            : [PPFunc triggerMediumHaptic];
        [self pp_homePublishCartMutation];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [cart addItem:item
        presentingViewController:self
                      completion:^(BOOL didAdd, BOOL didCancel) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        if (didCancel) {
            [self pp_homePublishCartMutation];
            return;
        }
        if (!didAdd) {
            [PPHUD showError:kLang(@"Out of stock")];
            return;
        }
        if (safeQuantity == 1) {
            [PPFunc triggerLightHaptic];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [PPAddToCartSuccessToast showWithTitle:(kLang(@"ItemAddedToCart") ?: @"Item added to cart")];
            });
        } else {
            [PPFunc triggerMediumHaptic];
        }
        [self pp_homePublishCartMutation];
    }];
}

- (void)pp_homePublishCartMutation
{
    [NSNotificationCenter.defaultCenter
        postNotificationName:kCartUpdatedNotification
                      object:nil];
}

- (void)PPUniversalCell_tapShare:
    (PPUniversalCellViewModel *)universalModel
{
    if (!PPIsUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }
    if ([universalModel.ModelObject isKindOfClass:PetAd.class]) {
        [PPAdSharingHelper
            sharePetAd:(PetAd *)universalModel.ModelObject
            fromViewController:self];
    }
}

- (void)PPUniversalCell_tapEdit:
    (PPUniversalCellViewModel *)universalModel
{
    id model = universalModel.ModelObject;
    if ([model isKindOfClass:PetAd.class]) {
        AddNewAd *editor = [AddNewAd new];
        editor.mode = AdEditorModeEdit;
        editor.editingAd = model;
        UINavigationController *navigation =
            [[UINavigationController alloc]
                initWithRootViewController:editor];
        navigation.modalPresentationStyle =
            UIModalPresentationFullScreen;
        [self presentViewController:navigation
                           animated:YES
                         completion:nil];
    } else if ([model isKindOfClass:PetAccessory.class]) {
        AddNewAccessory *editor = [AddNewAccessory new];
        editor.editingAccessory = model;
        __weak typeof(self) weakSelf = self;
        editor.onFinish = ^(__unused PetAccessory *result,
                            __unused BOOL isEdit) {
            [weakSelf pp_homeRefresh];
        };
        UINavigationController *navigation =
            [[UINavigationController alloc]
                initWithRootViewController:editor];
        navigation.modalPresentationStyle =
            UIModalPresentationFullScreen;
        [self presentViewController:navigation
                           animated:YES
                         completion:nil];
    }
}

- (void)PPUniversalCell_tapDelete:
    (PPUniversalCellViewModel *)universalModel
{
    if (!PPIsUserLoggedIn ||
        ![universalModel.ModelObject isKindOfClass:PetAd.class]) {
        if (!PPIsUserLoggedIn) {
            [UserManager showPromptOnTopController];
        }
        return;
    }
    __weak typeof(self) weakSelf = self;
    [GM showDeleteConfirmationFrom:self
                             title:kLang(@"Confirm Deletion")
                           message:kLang(
                               @"Are you sure you want to delete this item?"
                           )
                        completion:^(BOOL confirmed) {
        if (!confirmed) {
            return;
        }
        [PetAdManager.sharedManager
            deletePetAd:(PetAd *)universalModel.ModelObject
             completion:^(__unused NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf pp_homeRefresh];
            });
        }];
    }];
}

- (void)PPUniversalCell_tapVisibilityToggle:
    (PPUniversalCellViewModel *)universalModel
{
    if (!PPIsUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }
    BOOL visible = !universalModel.isPubliclyVisible;
    __weak typeof(self) weakSelf = self;
    void (^completion)(NSError *) = ^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            if (error) {
                [PPHUD showError:kLang(@"Error")
                        subtitle:error.localizedDescription];
                return;
            }
            [self pp_homeRefresh];
        });
    };

    if ([universalModel.ModelObject isKindOfClass:PetAd.class]) {
        PetAd *advertisement = universalModel.ModelObject;
        [PetAdManager.sharedManager
            updatePetAdID:advertisement.adID
               visibility:visible
                    ? PetAdVisibilityPublic
                    : PetAdVisibilityHidden
               completion:completion];
    } else if ([universalModel.ModelObject
                   isKindOfClass:PetAccessory.class]) {
        PetAccessory *accessory = universalModel.ModelObject;
        [PetAccessoryManager.sharedManager
            updateAccessoryID:accessory.accessoryID
              showInAppMarket:visible
                   completion:completion];
    }
}

- (NSString *)pp_homeOwnerIDForViewModel:
    (PPUniversalCellViewModel *)viewModel
{
    id model = viewModel.ModelObject;
    for (NSString *key in @[
             @"ownerID",
             @"serviceOwnerID",
             @"userID",
             @"providerId",
         ]) {
        SEL selector = NSSelectorFromString(key);
        if ([model respondsToSelector:selector]) {
            id value = [model valueForKey:key];
            NSString *identifier = PPHomeShellString(value);
            if (identifier.length > 0) {
                return identifier;
            }
        }
    }
    return @"";
}

- (void)PPUniversalCell_tapChat:
    (PPUniversalCellViewModel *)universalModel
{
    if (!PPIsUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }
    NSString *ownerID =
        [self pp_homeOwnerIDForViewModel:universalModel];
    if (ownerID.length == 0) {
        [PPHUD showInfo:
            kLang(@"bb_dataview_full_details_contact_unavailable")];
        return;
    }
    NSString *currentUserID =
        UserManager.sharedManager.currentUser.ID ?: @"";
    if ([ownerID isEqualToString:currentUserID]) {
        [PPHUD showInfo:
            kLang(@"bb_dataview_full_details_chat_self_unavailable")];
        return;
    }

    [PPHUD showLoading:
        kLang(@"bb_dataview_full_details_opening_chat")];
    __weak typeof(self) weakSelf = self;
    [UsrMgr
        getOtherUserModelFromFirestoreWithUID:ownerID
                                   completion:
        ^(UserModel *user, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            [PPHUD dismiss];
            if (error || user.ID.length == 0) {
                [PPHUD showError:
                    kLang(
                        @"bb_dataview_full_details_contact_unavailable"
                    )];
                return;
            }
            [ChManager.sharedManager
                createOrGetChatThreadWithUser:user
                                    completion:
                ^(ChatThreadModel *thread, NSError *chatError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (chatError || !thread) {
                        [PPHUD
                            showError:kLang(@"SomethingWentWrong")
                            subtitle:chatError.localizedDescription ?: @""];
                        return;
                    }
                    [PPOverlayCoordinator
                        pp_openChatThread:thread
                                  fromVC:self];
                });
            }];
        });
    }];
}

- (void)PPUniversalCell_tapReport:
    (PPUniversalCellViewModel *)universalModel
{
    (void)universalModel;
    [PPHUD showSuccess:kLang(@"reported_successfully")];
}

- (void)PPUniversalCell_tapSaveForLater:
    (PPUniversalCellViewModel *)universalModel
{
    NSString *itemID = PPHomeShellString(universalModel.ModelID);
    if (itemID.length == 0) {
        [PPHUD showError:kLang(@"SomethingWentWrong")];
        return;
    }
    PPSaveForLaterManager *manager =
        PPSaveForLaterManager.sharedManager;
    if ([manager isItemSaved:itemID]) {
        CartItem *item = [CartItem new];
        item.itemID = itemID;
        item.name = universalModel.title ?: @"";
        [manager removeItem:item];
        [PPHUD showInfo:kLang(@"saved_for_later_removed_toast")
               subtitle:nil
                  delay:2.5];
    } else {
        [manager saveViewModelForLater:universalModel];
        [PPHUD showSuccess:kLang(@"saved_for_later_added_toast")
                  subtitle:nil
                     delay:2.5];
    }
}

@end
