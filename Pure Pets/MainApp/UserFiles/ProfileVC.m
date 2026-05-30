//
//  ProfileVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 06/08/2024.
//

#import "ProfileVC.h"
#import "PPPermissionHelper.h"
#import "PPVerificationCodeViewController.h"
#import "PPSelectOptionViewController.h"
#import "SettingVC.h"
#import "PPNotificationsHubViewController.h"
#import "PPPetProfilesViewController.h"
#import "PPModernAvatarRenderer.h"
#import "PPRootTabBarController.h"


#import "PPProfileTextFieldCell.h"
#import "PPProfilePhoneCell.h"
#import "PPProfileTextViewCell.h"
#import "PPProfileSelectorCell.h"
#import "PPProfileAddressCell.h"
#import "PPProfileActionCell.h"



// ...


#define PPDispatchMain(block) dispatch_async(dispatch_get_main_queue(), block)

@import FirebaseAuth;
@import FirebaseStorage;
@import PhotosUI;

/// Bottom content inset that keeps the last row clear of the floating tab-bar
/// dock. The table is pinned to the safe-area bottom, while the dock's top
/// anchor sits `dockHeight` above it (see PPRootTabBarController). Returning
/// `dockHeight + 12` ends content 12pt above the dock's top anchor.
static CGFloat PPProfileBottomBarClearance(void) {
    CGFloat dockHeight = PPIOS26() ? 86.0 : 64.0; // mirrors PPRootTabBarController dock height
    return dockHeight + 12.0;                      // tab-bar top anchor + 12pt breathing room
}







@interface ProfileVC ()<UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UITextViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, AddressFormVCDelegate, TOCropViewControllerDelegate, PHPickerViewControllerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, assign) NSInteger petProfilesCount;
@property (nonatomic, strong) NSArray<PPAddressModel *> *addresses;
@property (nonatomic, strong) id<FIRListenerRegistration> addressListener;
@property (nonatomic, strong) NSMutableArray<CountryCodeModel *> *contriesArray;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *formDataArray;
@property (nonatomic, strong) CountryCodeModel *selectedCountry;

@property (nonatomic, copy) NSString *draftUserName;
@property (nonatomic, copy) NSString *draftFirstName;
@property (nonatomic, copy) NSString *draftLastName;
@property (nonatomic, copy) NSString *draftUserEmail;
@property (nonatomic, copy) NSString *draftUserAbout;
@property (nonatomic, copy) NSString *draftMobileLocal;

@property (nonatomic, assign) BOOL showingSave;
@property (nonatomic, assign) BOOL isSavingProfile;
@property (nonatomic, assign) BOOL suppressEditTracking;
@property (nonatomic, copy) NSDictionary<NSString *, id> *profileDraftBaseline;

@property (nonatomic, strong) UIView *headerRoot;
@property (nonatomic, strong) UIView *headerCardView;
@property (nonatomic, strong) UILabel *headerEyebrowLabel;
@property (nonatomic, strong) UILabel *headerNameLabel;
@property (nonatomic, strong) UILabel *headerHandleLabel;
@property (nonatomic, strong) UILabel *headerMetaLabel;
@property (nonatomic, strong) RoundedImageViewWithShadow *avatarIMV;
@property (nonatomic, strong) UIButton *addPhotoBtn;
@property (nonatomic, strong) UIView *backgroundGlowViewTop;
@property (nonatomic, strong) UIView *backgroundGlowViewBottom;
@property (nonatomic, strong, nullable) UIImage *pendingAvatarImage;
@property (nonatomic, strong) NSMutableSet<NSString *> *animatedCellKeys;
@property (nonatomic, assign) BOOL needsProfileEntranceAnimation;
@property (nonatomic, assign) BOOL isRunningProfileEntranceAnimation;
@property (nonatomic, assign) BOOL allowsCellDisplayAnimation;
@property (nonatomic, assign) NSUInteger profileEntranceAnimationToken;

@property (nonatomic, strong) UIBarButtonItem *saveDataBarButton;
@property (nonatomic, strong) UIBarButtonItem *logoutBarButton;
@end

@implementation ProfileVC

#pragma mark - Appearance

- (UIColor *)pp_profileCanvasColor
{
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
        }
        return [UIColor colorWithRed:0.969 green:0.961 blue:0.949 alpha:1.0];
    }];
}

- (UIColor *)pp_profileSurfaceColor
{
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.17 green:0.17 blue:0.19 alpha:0.92];
        }
        return [[UIColor whiteColor] colorWithAlphaComponent:0.82];
    }];
}

- (UIColor *)pp_profileSurfaceBorderColor
{
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.85 green:0.80 blue:0.78 alpha:0.10];
        }
        return [UIColor colorWithRed:0.25 green:0.17 blue:0.18 alpha:0.08];
    }];
}

- (void)pp_applyProfileCanvasBackground
{
    UIColor *canvasColor = [self pp_profileCanvasColor];
    self.view.backgroundColor = canvasColor;
    self.view.opaque = YES;
    self.navigationController.view.backgroundColor = AppClearClr;

    if (!self.tableView) {
        return;
    }

    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.opaque = NO;
    self.tableView.alwaysBounceVertical = YES;

    UIView *backgroundView = self.tableView.backgroundView;
    if (!backgroundView) {
        backgroundView = [[UIView alloc] initWithFrame:self.tableView.bounds];
        backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.tableView.backgroundView = backgroundView;
    }
    backgroundView.backgroundColor = canvasColor;
}

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.formDataArray = [NSMutableDictionary dictionary];
    self.animatedCellKeys = [NSMutableSet set];
    self.addresses = PPCurrentUser.Addresses ?: @[];
    self.suppressEditTracking = YES;

    [self pp_prepareDraftState];
    [self pp_buildTableView];
    [self setupModernBackdrop];
    [self setupHeaderUI];
    [self pp_applyProfileCanvasBackground];
    [self pp_refreshProfileHeaderContent];
    [self listenToAddresses];
    [self pp_captureProfileDraftBaseline];
    self.showingSave = NO;
    self.suppressEditTracking = NO;
    [self pp_refreshRightNavSaveState];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if ([self.tabBarController respondsToSelector:@selector(setPremiumTabDockViewHidden:animation:)]) {
        [(PPRootTabBarController *)self.tabBarController setPremiumTabDockViewHidden:YES animation:animated];
    }
    self.view.semanticContentAttribute = PPProfileCurrentSemanticAttribute();
    self.tableView.semanticContentAttribute = PPProfileCurrentSemanticAttribute();
    [self.animatedCellKeys removeAllObjects];
    self.profileEntranceAnimationToken += 1;
    self.needsProfileEntranceAnimation = YES;
    self.isRunningProfileEntranceAnimation = NO;
    self.allowsCellDisplayAnimation = NO;

    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.navigationController) {
                [self.navigationController popViewControllerAnimated:YES];
            } else {
                [self dismissViewControllerAnimated:YES completion:nil];
            }
        });
        return;
    }

    [self BellowIos26Buttons];
    [self pp_applyProfileCanvasBackground];
    [self pp_refreshAvatarImageView];
    [self.tableView reloadData];

    __weak typeof(self) weakSelf = self;
    [[UserManager sharedManager] fetchPetProfilesForCurrentUserWithCompletion:^(NSArray<PPPetProfile *> * _Nullable pets, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.petProfilesCount = pets.count;
            if (weakSelf.isViewLoaded) {
                // Use reloadData to avoid NSInternalInconsistencyException when the
                // address listener has already mutated self.addresses (section 2 row
                // count) between the prior reloadData and this callback.
                [weakSelf.tableView reloadData];
            }
        });
    }];

}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.tableView.contentInset = UIEdgeInsetsMake(6.0, 0.0, PPProfileBottomBarClearance(), 0.0);
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(6.0, 0.0, PPProfileBottomBarClearance(), 0.0);
    [self pp_runProfileEntranceAnimationIfNeeded];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.isRunningProfileEntranceAnimation = NO;
    self.allowsCellDisplayAnimation = NO;
    [PPHUD dismiss];
    if ((self.isMovingFromParentViewController || self.isBeingDismissed) &&
        [self.tabBarController respondsToSelector:@selector(setPremiumTabDockViewHidden:animation:)]) {
        [(PPRootTabBarController *)self.tabBarController setPremiumTabDockViewHidden:NO animation:animated];
    }
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self pp_refreshProfileHeaderContent];
    CGFloat headerWidth = CGRectGetWidth(self.tableView.bounds);
    if (headerWidth <= 0.0) {
        headerWidth = CGRectGetWidth(self.view.bounds);
    }
    CGRect headerBounds = self.headerRoot.bounds;
    if (ABS(headerBounds.size.width - headerWidth) > 0.5) {
        headerBounds.size.width = headerWidth;
        self.headerRoot.bounds = headerBounds;
    }
    [self.headerRoot setNeedsLayout];
    [self.headerRoot layoutIfNeeded];
    CGFloat headerHeight = [self.headerRoot systemLayoutSizeFittingSize:CGSizeMake(headerWidth, UILayoutFittingCompressedSize.height)
                                        withHorizontalFittingPriority:UILayoutPriorityRequired
                                              verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
    CGRect frame = self.headerRoot.frame;
    frame.size.width = headerWidth;
    frame.size.height = headerHeight;
    self.headerRoot.frame = frame;
    self.tableView.tableHeaderView = self.headerRoot;
    [Styling addLiquidGlassBorderToView:self.avatarIMV cornerRadius:54.0];
    
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    [self pp_applyProfileCanvasBackground];

    self.backgroundGlowViewTop.layer.cornerRadius = CGRectGetWidth(self.backgroundGlowViewTop.bounds) * 0.5;
    self.backgroundGlowViewBottom.layer.cornerRadius = CGRectGetWidth(self.backgroundGlowViewBottom.bounds) * 0.5;
    [self.view sendSubviewToBack:self.backgroundGlowViewBottom];
    [self.view sendSubviewToBack:self.backgroundGlowViewTop];

    self.avatarIMV.layer.borderWidth = 3.0;
    UIColor *avatarBorderDynamic = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat a = (tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.86 * 0.18 : 0.86;
        return [[UIColor whiteColor] colorWithAlphaComponent:a];
    }];
    [self.avatarIMV pp_setBorderColor:avatarBorderDynamic];

    self.headerCardView.layer.borderWidth = 1.0;
    UIColor *headerCardBorderDynamic = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat a = (tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.68 * 0.18 : 0.68;
        return [[UIColor whiteColor] colorWithAlphaComponent:a];
    }];
    [self.headerCardView pp_setBorderColor:headerCardBorderDynamic];

    UIColor *editBadgeBorderDynamic = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.17 green:0.17 blue:0.19 alpha:1.0];
        }
        return UIColor.whiteColor;
    }];
    [self.addPhotoBtn pp_setBorderColor:editBadgeBorderDynamic];
    [self.addPhotoBtn pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    self.addPhotoBtn.layer.shadowOpacity = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.06 : 0.18;
    self.addPhotoBtn.layer.shadowRadius = 6.0;
    self.addPhotoBtn.layer.shadowOffset = CGSizeMake(0.0, 2.0);
    self.tableView.backgroundView = nil;

    self.tableView.backgroundColor = AppClearClr;
    
}

- (void)dealloc
{
    [self.addressListener remove];
    self.addressListener = nil;
}

#pragma mark - Motion

- (BOOL)pp_profileReduceMotionEnabled
{
    return UIAccessibilityIsReduceMotionEnabled();
}

- (NSString *)pp_animationKeyForIndexPath:(NSIndexPath *)indexPath
{
    if (!indexPath) {
        return @"";
    }
    return [NSString stringWithFormat:@"%ld-%ld", (long)indexPath.section, (long)indexPath.row];
}

- (NSArray<UITableViewCell *> *)pp_sortedVisibleProfileCells
{
    NSArray<UITableViewCell *> *visibleCells = self.tableView.visibleCells ?: @[];
    return [visibleCells sortedArrayUsingComparator:^NSComparisonResult(UITableViewCell *cell1, UITableViewCell *cell2) {
        CGFloat y1 = CGRectGetMinY(cell1.frame);
        CGFloat y2 = CGRectGetMinY(cell2.frame);
        if (fabs(y1 - y2) < 0.5) {
            NSIndexPath *indexPath1 = [self.tableView indexPathForCell:cell1];
            NSIndexPath *indexPath2 = [self.tableView indexPathForCell:cell2];
            if (indexPath1.section == indexPath2.section) {
                if (indexPath1.row == indexPath2.row) {
                    return NSOrderedSame;
                }
                return indexPath1.row < indexPath2.row ? NSOrderedAscending : NSOrderedDescending;
            }
            return indexPath1.section < indexPath2.section ? NSOrderedAscending : NSOrderedDescending;
        }
        return y1 < y2 ? NSOrderedAscending : NSOrderedDescending;
    }];
}

- (void)pp_finishDisplayAnimationStateForCell:(UITableViewCell *)cell
{
    if (!cell) {
        return;
    }

    cell.alpha = 1.0;
    cell.transform = CGAffineTransformIdentity;
}

- (void)pp_prepareDisplayAnimationStateForCell:(UITableViewCell *)cell
{
    if (!cell) {
        return;
    }

    cell.alpha = 0.0;
    cell.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 18.0),
                                             CGAffineTransformMakeScale(0.985, 0.985));
}

- (void)pp_animateProfileDisplayCell:(UITableViewCell *)cell
                         atIndexPath:(NSIndexPath *)indexPath
                               delay:(NSTimeInterval)delay
{
    if (!cell || !indexPath) {
        return;
    }

    NSString *animationKey = [self pp_animationKeyForIndexPath:indexPath];
    if (animationKey.length == 0) {
        [self pp_finishDisplayAnimationStateForCell:cell];
        return;
    }

    if ([self.animatedCellKeys containsObject:animationKey]) {
        [self pp_finishDisplayAnimationStateForCell:cell];
        return;
    }

    [self.animatedCellKeys addObject:animationKey];

    if ([self pp_profileReduceMotionEnabled]) {
        [self pp_finishDisplayAnimationStateForCell:cell];
        return;
    }

    [self pp_prepareDisplayAnimationStateForCell:cell];
    [UIView animateWithDuration:0.40
                          delay:delay
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.08
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        [self pp_finishDisplayAnimationStateForCell:cell];
    } completion:nil];
}

- (void)pp_runProfileEntranceAnimationIfNeeded
{
    if (!self.needsProfileEntranceAnimation || !self.isViewLoaded || !self.view.window) {
        return;
    }

    self.needsProfileEntranceAnimation = NO;
    self.isRunningProfileEntranceAnimation = YES;
    self.allowsCellDisplayAnimation = NO;

    NSArray<UITableViewCell *> *visibleCells = [self pp_sortedVisibleProfileCells];
    NSUInteger animationToken = self.profileEntranceAnimationToken;

    if ([self pp_profileReduceMotionEnabled]) {
        for (UITableViewCell *cell in visibleCells) {
            NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
            NSString *animationKey = [self pp_animationKeyForIndexPath:indexPath];
            if (animationKey.length > 0) {
                [self.animatedCellKeys addObject:animationKey];
            }
            [self pp_finishDisplayAnimationStateForCell:cell];
        }
        self.isRunningProfileEntranceAnimation = NO;
        self.allowsCellDisplayAnimation = YES;
        return;
    }

    [visibleCells enumerateObjectsUsingBlock:^(UITableViewCell *cell, NSUInteger idx, BOOL *stop) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        [self pp_animateProfileDisplayCell:cell atIndexPath:indexPath delay:(0.04 + (idx * 0.045))];
    }];

    NSTimeInterval completionDelay = MAX(0.40, 0.04 + (MAX((NSInteger)visibleCells.count - 1, 0) * 0.045) + 0.40);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(completionDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.profileEntranceAnimationToken != animationToken) {
            return;
        }
        self.isRunningProfileEntranceAnimation = NO;
        self.allowsCellDisplayAnimation = YES;
    });
}

#pragma mark - Setup

- (void)pp_buildTableView
{
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.showsVerticalScrollIndicator = NO;
    tableView.showsHorizontalScrollIndicator = NO;
    tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    tableView.rowHeight = UITableViewAutomaticDimension;
    tableView.estimatedRowHeight = 84.0;
    tableView.contentInset = UIEdgeInsetsMake(6.0, 0.0, PPProfileBottomBarClearance(), 0.0);
    tableView.scrollIndicatorInsets = UIEdgeInsetsMake(6.0, 0.0, PPProfileBottomBarClearance(), 0.0);
    if (@available(iOS 15.0, *)) {
        tableView.sectionHeaderTopPadding = 0.0;
    }

    [tableView registerClass:PPProfileTextFieldCell.class forCellReuseIdentifier:@"PPProfileTextFieldCell"];
    [tableView registerClass:PPProfilePhoneCell.class forCellReuseIdentifier:@"PPProfilePhoneCell"];
    [tableView registerClass:PPProfileTextViewCell.class forCellReuseIdentifier:@"PPProfileTextViewCell"];
    [tableView registerClass:PPProfileSelectorCell.class forCellReuseIdentifier:@"PPProfileSelectorCell"];
    [tableView registerClass:PPProfileAddressCell.class forCellReuseIdentifier:@"PPProfileAddressCell"];
    [tableView registerClass:PPProfileActionCell.class forCellReuseIdentifier:@"PPProfileActionCell"];

    [self.view addSubview:tableView];
    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [tableView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
    self.tableView = tableView;
}

- (void)pp_prepareDraftState
{
    self.contriesArray = [GM getMiddleEastCountriesForLanguage:[Language currentLanguageCode]];
    self.selectedCountry = [self pp_resolvedSelectedCountry];
    [self pp_loadDraftValuesFromUser:PPCurrentUser];
    [self setformDataArray:@(self.selectedCountry.ID) forKey:@"CountryID"];
}

- (CountryCodeModel *)pp_resolvedSelectedCountry
{
    NSInteger selectedCountryID = PPCurrentUser.CountryID;
    CountryCodeModel *countryByID = selectedCountryID > 0
        ? [[self.contriesArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", selectedCountryID]] firstObject]
        : nil;
    CountryCodeModel *countryByMobile = [self pp_countryFromStoredMobileNumber:PPCurrentUser.MobileNo];
    NSString *carrierISO = [self pp_trimmedString:[GM getCurrentCountryFromCarrier]];
    CountryCodeModel *countryByCarrier = carrierISO.length > 0 ? [self pp_countryWithISOCode:carrierISO] : nil;
    NSString *currentISO = [self pp_trimmedString:CitiesManager.shared.CurrentCountry.iso];
    CountryCodeModel *countryByCurrent = currentISO.length > 0 ? [self pp_countryWithISOCode:currentISO] : nil;
    NSString *localeISO = [self pp_trimmedString:[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode]];
    CountryCodeModel *countryByLocale = localeISO.length > 0 ? [self pp_countryWithISOCode:localeISO] : nil;

    CountryCodeModel *resolved = countryByID ?: countryByMobile ?: countryByCarrier ?: countryByCurrent ?: countryByLocale ?: [self pp_qatarCountry];
    if (countryByID && countryByMobile && ![[self pp_trimmedString:countryByID.phoneCode] isEqualToString:[self pp_trimmedString:countryByMobile.phoneCode]]) {
        NSString *storedMobile = [self pp_trimmedString:PPCurrentUser.MobileNo];
        if ([storedMobile hasPrefix:[self pp_trimmedString:countryByMobile.phoneCode]]) {
            resolved = countryByMobile;
        }
    }
    return resolved ?: [self pp_qatarCountry];
}

- (void)pp_loadDraftValuesFromUser:(UserModel *)user
{
    self.draftUserName = [self pp_trimmedString:user.UserName];
    self.draftFirstName = [self pp_trimmedString:user.FirstName];
    self.draftLastName = [self pp_trimmedString:user.LastName];
    self.draftUserEmail = [self pp_trimmedString:user.UserEmail];
    self.draftUserAbout = [self pp_trimmedString:user.UserAbout];

    NSString *storedMobile = [self pp_trimmedString:user.MobileNo];
    if (storedMobile.length > 0 && self.selectedCountry.phoneCode.length > 0) {
        self.draftMobileLocal = [self pp_localPhonePartFromE164:storedMobile dialCode:self.selectedCountry.phoneCode];
    } else {
        self.draftMobileLocal = storedMobile ?: @"";
    }
}

- (void)pp_syncDraftStateFromCurrentUser
{
    self.suppressEditTracking = YES;
    self.selectedCountry = [self pp_resolvedSelectedCountry];
    [self pp_loadDraftValuesFromUser:PPCurrentUser];
    [self.formDataArray removeAllObjects];
    [self setformDataArray:@(self.selectedCountry.ID) forKey:@"CountryID"];
    [self pp_captureProfileDraftBaseline];
    self.pendingAvatarImage = nil;
    self.suppressEditTracking = NO;
    [self pp_refreshAvatarImageView];
    [self.tableView reloadData];
    [self pp_refreshProfileHeaderContent];
    [self pp_refreshRightNavSaveState];
}

- (void)pp_refreshAvatarImageView
{
    if (self.pendingAvatarImage) {
        self.avatarIMV.imageView.image = self.pendingAvatarImage;
        return;
    }
    NSURL *avatarURL = PPCurrentUser.UserImageUrl;
    if (avatarURL.absoluteString.length > 0) {
        [GM setImageFromUrlString:PPSafeString(avatarURL.absoluteString)
                        imageView:self.avatarIMV.imageView
                          phImage:@"person.crop.circle.fill"];
    } else {
        self.avatarIMV.imageView.image =
            [PPModernAvatarRenderer avatarImageForName:PPCurrentUser.UserName size:72];
    }
}

#pragma mark - Draft / Dirty State

- (NSDictionary<NSString *, id> *)pp_profileDraftSnapshot
{
    CountryCodeModel *country = self.selectedCountry ?: [self pp_qatarCountry];
    return @{
        @"firstName": [self pp_trimmedString:self.draftFirstName] ?: @"",
        @"lastName": [self pp_trimmedString:self.draftLastName] ?: @"",
        @"userName": [self pp_trimmedString:self.draftUserName] ?: @"",
        @"userEmail": [[self pp_trimmedString:self.draftUserEmail] lowercaseString] ?: @"",
        @"userAbout": [self pp_trimmedString:self.draftUserAbout] ?: @"",
        @"mobileLocal": [self pp_trimmedString:self.draftMobileLocal] ?: @"",
        @"countryID": @((long)(country ? country.ID : 0))
    };
}

- (void)pp_captureProfileDraftBaseline
{
    self.profileDraftBaseline = [self pp_profileDraftSnapshot];
}

- (BOOL)pp_hasPendingProfileChanges
{
    if (self.pendingAvatarImage != nil) {
        return YES;
    }

    NSDictionary<NSString *, id> *currentSnapshot = [self pp_profileDraftSnapshot];
    if (!self.profileDraftBaseline) {
        return currentSnapshot.count > 0;
    }
    return ![self.profileDraftBaseline isEqualToDictionary:currentSnapshot];
}

- (void)pp_refreshRightNavSaveState
{
    BOOL hasChanges = [self pp_hasPendingProfileChanges];
    self.showingSave = hasChanges;
    if (hasChanges) {
        [self pp_showSaveButton];
    } else {
        [self pp_navBarRemoveButtonForKey:@"saveOrLogout"];
        [self pp_navBarHideButtonForKey:@"saveOrLogout" hidden:YES animated:NO];
        //[self pp_navBarHideButtonForKey:@"saveOrLogout"];
    }
}

- (void)markFormAsEdited
{
    if (self.suppressEditTracking) {
        return;
    }
    [self pp_refreshRightNavSaveState];
}

- (void)setformDataArray:(id)obj forKey:(NSString *)key
{
    if (key.length == 0) {
        return;
    }
    if (!self.formDataArray) {
        self.formDataArray = [NSMutableDictionary dictionary];
    }
    if (!obj || obj == [NSNull null]) {
        [self.formDataArray removeObjectForKey:key];
        return;
    }
    if ([obj isKindOfClass:NSString.class]) {
        NSString *trimmed = [(NSString *)obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length == 0) {
            [self.formDataArray removeObjectForKey:key];
            return;
        }
        self.formDataArray[key] = trimmed;
        return;
    }
    self.formDataArray[key] = obj;
}

#pragma mark - Nav Bar

- (void)pp_showSaveButton
{
    if (!self.saveDataBarButton) {
        UIButton *sav = [PPButtonHelper pp_buttonWithTitle:kLang(@"Save") font:[GM fontWithSize:17] imageName:@"" target:self config:[UIButtonConfiguration tintedButtonConfiguration] action:@selector(updateUserData)];
        self.saveDataBarButton = [[UIBarButtonItem alloc] initWithCustomView:sav];
    }
    self.navigationItem.rightBarButtonItem = self.saveDataBarButton;

    UIButton *saveButton = [self pp_ButtonWithSystemName:@"checkmark" action:@selector(updateUserData)];
    [self pp_navBarRemoveButtonForKey:@"saveOrLogout"];
    [self _pp_addRightButton:saveButton key:@"saveOrLogout"];
}

- (void)pp_showLogoutButton
{
    UIButton *logoutButton = [self pp_ButtonWithSystemName:@"power" action:@selector(logoutTapped)];
    [self pp_navBarRemoveButtonForKey:@"saveOrLogout"];
    [self _pp_addRightButton:logoutButton key:@"saveOrLogout"];
}

- (void)BellowIos26Buttons
{
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"UserProfile") showBack:YES];

    if (!self.saveDataBarButton) {
        UIButton *sav = [PPButtonHelper pp_buttonWithTitle:kLang(@"Save") font:[GM fontWithSize:17] imageName:@"" target:self config:[UIButtonConfiguration tintedButtonConfiguration] action:@selector(updateUserData)];
        self.saveDataBarButton = [[UIBarButtonItem alloc] initWithCustomView:sav];
    }
    [self pp_refreshRightNavSaveState];
}

- (void)pp_setProfileSaving:(BOOL)isSaving
{
    self.isSavingProfile = isSaving;
    self.navigationItem.rightBarButtonItem.enabled = !isSaving;
    self.navigationItem.leftBarButtonItem.enabled = !isSaving;
    [self pp_navBarHideButtonForKey:@"saveOrLogout" hidden:isSaving animated:NO];
    self.tableView.userInteractionEnabled = !isSaving;
}

#pragma mark - Header

- (NSString *)pp_localizedProfileStringForKey:(NSString *)key fallback:(NSString *)fallback
{
    NSString *value = key.length ? kLang(key) : nil;
    if (![value isKindOfClass:NSString.class] || value.length == 0 || [value isEqualToString:key]) {
        return fallback ?: @"";
    }
    return value;
}

- (void)setupModernBackdrop
{
    if (self.backgroundGlowViewTop || self.backgroundGlowViewBottom) {
        return;
    }

    UIView *topGlow = [[UIView alloc] init];
    topGlow.translatesAutoresizingMaskIntoConstraints = NO;
    topGlow.userInteractionEnabled = NO;
    topGlow.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat a = (tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.12 * 0.40 : 0.12;
        return [UIColor colorWithRed:0.93 green:0.80 blue:0.69 alpha:a];
    }];
    [topGlow pp_setShadowColor:[UIColor colorWithRed:0.98 green:0.82 blue:0.60 alpha:1.0]];
    topGlow.layer.shadowOpacity = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.04 : 0.10;
    topGlow.layer.shadowRadius = 64.0;
    topGlow.layer.shadowOffset = CGSizeZero;

    UIView *bottomGlow = [[UIView alloc] init];
    bottomGlow.translatesAutoresizingMaskIntoConstraints = NO;
    bottomGlow.userInteractionEnabled = NO;
    bottomGlow.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat a = (tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.06 * 0.40 : 0.06;
        return [UIColor colorWithRed:0.72 green:0.45 blue:0.42 alpha:a];
    }];
    [bottomGlow pp_setShadowColor:[UIColor colorWithRed:0.68 green:0.27 blue:0.33 alpha:1.0]];
    bottomGlow.layer.shadowOpacity = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.03 : 0.08;
    bottomGlow.layer.shadowRadius = 72.0;
    bottomGlow.layer.shadowOffset = CGSizeZero;

    [self.view insertSubview:topGlow belowSubview:self.tableView];
    [self.view insertSubview:bottomGlow belowSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [topGlow.widthAnchor constraintEqualToConstant:220.0],
        [topGlow.heightAnchor constraintEqualToConstant:220.0],
        [topGlow.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:-72.0],
        [topGlow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:84.0],

        [bottomGlow.widthAnchor constraintEqualToConstant:200.0],
        [bottomGlow.heightAnchor constraintEqualToConstant:200.0],
        [bottomGlow.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:48.0],
        [bottomGlow.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-64.0]
    ]];

    self.backgroundGlowViewTop = topGlow;
    self.backgroundGlowViewBottom = bottomGlow;
}

- (void)setupHeaderUI
{
    self.headerRoot = [[UIView alloc] init];
    self.headerRoot.backgroundColor = UIColor.clearColor;

    UIColor *brandColor = AppPrimaryClr ?: UIColor.systemOrangeColor;

    UIView *cardView = [[UIView alloc] init];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    cardView.backgroundColor = [self pp_profileSurfaceColor];
    cardView.layer.cornerRadius = 34.0;
    cardView.layer.masksToBounds = NO;
    cardView.layer.borderWidth = 1.0;
    UIColor *cardBorderColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat a = (tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.68 * 0.18 : 0.68;
        return [[UIColor whiteColor] colorWithAlphaComponent:a];
    }];
    [cardView pp_setBorderColor:cardBorderColor];
    [cardView pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    cardView.layer.shadowOpacity = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.03 : 0.08;
    cardView.layer.shadowRadius = 24.0;
    cardView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    [self.headerRoot addSubview:cardView];

    UIView *tintView = [[UIView alloc] init];
    tintView.translatesAutoresizingMaskIntoConstraints = NO;
    tintView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.22 green:0.19 blue:0.17 alpha:0.50];
        }
        return [[UIColor colorWithRed:0.99 green:0.96 blue:0.93 alpha:1.0] colorWithAlphaComponent:0.72];
    }];
    tintView.layer.cornerRadius = 34.0;
    tintView.layer.masksToBounds = YES;
    [cardView addSubview:tintView];

    UIView *ambientGlow = [[UIView alloc] init];
    ambientGlow.translatesAutoresizingMaskIntoConstraints = NO;
    ambientGlow.backgroundColor = [brandColor colorWithAlphaComponent:0.16];
    ambientGlow.userInteractionEnabled = NO;
    ambientGlow.layer.cornerRadius = 94.0;
    [ambientGlow pp_setShadowColor:[brandColor colorWithAlphaComponent:0.50]];
    ambientGlow.layer.shadowOpacity = 0.16;
    ambientGlow.layer.shadowRadius = 42.0;
    ambientGlow.layer.shadowOffset = CGSizeZero;
    [cardView addSubview:ambientGlow];

    UIView *secondaryGlow = [[UIView alloc] init];
    secondaryGlow.translatesAutoresizingMaskIntoConstraints = NO;
    secondaryGlow.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat a = (tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.40 * 0.18 : 0.40;
        return [[UIColor whiteColor] colorWithAlphaComponent:a];
    }];
    secondaryGlow.userInteractionEnabled = NO;
    secondaryGlow.layer.cornerRadius = 58.0;
    UIColor *secondaryGlowShadowColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat a = (tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.45 * 0.18 : 0.45;
        return [[UIColor whiteColor] colorWithAlphaComponent:a];
    }];
    [secondaryGlow pp_setShadowColor:secondaryGlowShadowColor];
    secondaryGlow.layer.shadowOpacity = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.04 : 0.20;
    secondaryGlow.layer.shadowRadius = 22.0;
    secondaryGlow.layer.shadowOffset = CGSizeZero;
    [cardView addSubview:secondaryGlow];

    UIView *accentBar = [[UIView alloc] init];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = brandColor;
    accentBar.layer.cornerRadius = 3.0;
    [cardView addSubview:accentBar];

    UIView *eyebrowPill = [[UIView alloc] init];
    eyebrowPill.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowPill.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat a = (tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.74 * 0.18 : 0.74;
        return [[UIColor whiteColor] colorWithAlphaComponent:a];
    }];
    eyebrowPill.layer.cornerRadius = 14.0;
    eyebrowPill.layer.borderWidth = 1.0;
    [eyebrowPill pp_setBorderColor:[brandColor colorWithAlphaComponent:0.10]];
    eyebrowPill.layer.masksToBounds = YES;
    [cardView addSubview:eyebrowPill];

    PPInsetLabel *eyebrowLabel = [[PPInsetLabel alloc] init];
    eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    eyebrowLabel.textColor = [brandColor colorWithAlphaComponent:0.92];
    eyebrowLabel.textAlignment = NSTextAlignmentCenter;
   // eyebrowLabel.textInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    [eyebrowPill addSubview:eyebrowLabel];

    UIView *avatarHalo = [[UIView alloc] init];
    avatarHalo.translatesAutoresizingMaskIntoConstraints = NO;
    avatarHalo.backgroundColor = [brandColor colorWithAlphaComponent:0.12];
    avatarHalo.layer.cornerRadius = 62.0;
    avatarHalo.layer.borderWidth = 0.0;
    UIColor *avatarHaloBorderColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat a = (tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.48 * 0.18 : 0.48;
        return [[UIColor whiteColor] colorWithAlphaComponent:a];
    }];
    [avatarHalo pp_setBorderColor:avatarHaloBorderColor];
    [avatarHalo pp_setShadowColor:[brandColor colorWithAlphaComponent:0.30]];
    avatarHalo.layer.shadowOpacity = 0.12;
    avatarHalo.layer.shadowRadius = 22.0;
    avatarHalo.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    [cardView addSubview:avatarHalo];

    RoundedImageViewWithShadow *avatarView = [[RoundedImageViewWithShadow alloc] initWithImage:[PPModernAvatarRenderer avatarImageForName:PPCurrentUser.UserName size:72]];
    avatarView.userInteractionEnabled = YES;
    if (PPCurrentUser.UserImageUrl) {
        [GM setImageFromUrlString:PPSafeString(PPCurrentUser.UserImageUrl.absoluteString)
                        imageView:avatarView.imageView
                          phImage:@"person.crop.circle.fill"];
    }
    else
    {
        avatarView.imageView.image =
        [PPModernAvatarRenderer avatarImageForName:PPCurrentUser.UserName size:72];
    }
    avatarView.layer.cornerRadius = 54.0;
    avatarView.layer.masksToBounds = YES;
    avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapAddPhoto)];
    [avatarView addGestureRecognizer:tap];
    [avatarHalo addSubview:avatarView];
    self.avatarIMV = avatarView;

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.font = [GM boldFontWithSize:29.0] ?: [UIFont systemFontOfSize:29.0 weight:UIFontWeightBold];
    nameLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.numberOfLines = 2;
    [cardView addSubview:nameLabel];

    PPInsetLabel *handleLabel = [[PPInsetLabel alloc] init];
    handleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    handleLabel.font = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    handleLabel.textColor = [UIColor secondaryLabelColor];
    handleLabel.textAlignment = NSTextAlignmentCenter;
    handleLabel.numberOfLines = 1;
    handleLabel.textInsets = UIEdgeInsetsMake(6, 12, 6, 12);
    [cardView addSubview:handleLabel];

    PPInsetLabel *metaLabel = [[PPInsetLabel alloc] init];
    metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    metaLabel.font = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    metaLabel.textColor = [brandColor colorWithAlphaComponent:0.92];
    metaLabel.textAlignment = NSTextAlignmentCenter;
    metaLabel.numberOfLines = 2;
    metaLabel.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat a = (tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.78 * 0.18 : 0.78;
        return [[UIColor whiteColor] colorWithAlphaComponent:a];
    }];
    metaLabel.layer.cornerRadius = 17.0;
    metaLabel.layer.borderWidth = 1.0;
    [metaLabel pp_setBorderColor:[brandColor colorWithAlphaComponent:0.10]];
    metaLabel.layer.masksToBounds = YES;
    metaLabel.textInsets = UIEdgeInsetsMake(6, 12, 6, 12);
    [cardView addSubview:metaLabel];

    // Pencil edit badge on avatar corner
    UIButton *editBadge = [UIButton buttonWithType:UIButtonTypeSystem];
    editBadge.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *pencilConfig = [UIImageSymbolConfiguration configurationWithPointSize:13.0 weight:UIImageSymbolWeightSemibold];
    [editBadge setImage:[[UIImage systemImageNamed:@"pencil" withConfiguration:pencilConfig] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    editBadge.tintColor = UIColor.whiteColor;
    editBadge.backgroundColor = brandColor;
    editBadge.layer.cornerRadius = 16.0;
    editBadge.layer.borderWidth = 2.5;
    [editBadge pp_setBorderColor:[UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.17 green:0.17 blue:0.19 alpha:1.0];
        }
        return UIColor.whiteColor;
    }]];
    [editBadge pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    editBadge.layer.shadowOpacity = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.06 : 0.18;
    editBadge.layer.shadowRadius = 6.0;
    editBadge.layer.shadowOffset = CGSizeMake(0.0, 2.0);
    [editBadge addTarget:self action:@selector(didTapAddPhoto) forControlEvents:UIControlEventTouchUpInside];
    [avatarHalo addSubview:editBadge];
    self.addPhotoBtn = editBadge;

    [NSLayoutConstraint activateConstraints:@[
        [cardView.topAnchor constraintEqualToAnchor:self.headerRoot.topAnchor constant:10.0],
        [cardView.leadingAnchor constraintEqualToAnchor:self.headerRoot.leadingAnchor constant:20.0],
        [cardView.trailingAnchor constraintEqualToAnchor:self.headerRoot.trailingAnchor constant:-20.0],
        [cardView.bottomAnchor constraintEqualToAnchor:self.headerRoot.bottomAnchor constant:-14.0],

        [tintView.topAnchor constraintEqualToAnchor:cardView.topAnchor],
        [tintView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor],
        [tintView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor],
        [tintView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor],

        [ambientGlow.widthAnchor constraintEqualToConstant:188.0],
        [ambientGlow.heightAnchor constraintEqualToConstant:188.0],
        [ambientGlow.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:-82.0],
        [ambientGlow.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:82.0],

        [secondaryGlow.widthAnchor constraintEqualToConstant:116.0],
        [secondaryGlow.heightAnchor constraintEqualToConstant:116.0],
        [secondaryGlow.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:42.0],
        [secondaryGlow.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:-34.0],

        [accentBar.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:22.0],
        [accentBar.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [accentBar.widthAnchor constraintEqualToConstant:72.0],
        [accentBar.heightAnchor constraintEqualToConstant:6.0],

        [eyebrowPill.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:16.0],
        [eyebrowPill.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [eyebrowPill.trailingAnchor constraintLessThanOrEqualToAnchor:cardView.trailingAnchor constant:-24.0],
        [eyebrowPill.heightAnchor constraintGreaterThanOrEqualToConstant:28.0],

        [eyebrowLabel.topAnchor constraintEqualToAnchor:eyebrowPill.topAnchor constant:6.0],
        [eyebrowLabel.leadingAnchor constraintEqualToAnchor:eyebrowPill.leadingAnchor constant:12.0],
        [eyebrowLabel.trailingAnchor constraintEqualToAnchor:eyebrowPill.trailingAnchor constant:-12.0],
        [eyebrowLabel.bottomAnchor constraintEqualToAnchor:eyebrowPill.bottomAnchor constant:-6.0],

        [avatarHalo.centerXAnchor constraintEqualToAnchor:cardView.centerXAnchor],
        [avatarHalo.topAnchor constraintEqualToAnchor:eyebrowPill.bottomAnchor constant:20.0],
        [avatarHalo.widthAnchor constraintEqualToConstant:124.0],
        [avatarHalo.heightAnchor constraintEqualToConstant:124.0],

        [avatarView.centerXAnchor constraintEqualToAnchor:avatarHalo.centerXAnchor],
        [avatarView.centerYAnchor constraintEqualToAnchor:avatarHalo.centerYAnchor],
        [avatarView.widthAnchor constraintEqualToConstant:108.0],
        [avatarView.heightAnchor constraintEqualToConstant:108.0],

        [nameLabel.topAnchor constraintEqualToAnchor:avatarHalo.bottomAnchor constant:12.0],
        [nameLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [nameLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-24.0],

        [handleLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:8.0],
        [handleLabel.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor],
        [handleLabel.trailingAnchor constraintEqualToAnchor:nameLabel.trailingAnchor],

        [metaLabel.topAnchor constraintEqualToAnchor:handleLabel.bottomAnchor constant:8],
        [metaLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:cardView.leadingAnchor constant:34.0],
        [metaLabel.centerXAnchor constraintEqualToAnchor:cardView.centerXAnchor],
        [metaLabel.trailingAnchor constraintLessThanOrEqualToAnchor:cardView.trailingAnchor constant:-34.0],
        [metaLabel.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-24.0],

        [editBadge.widthAnchor constraintEqualToConstant:32.0],
        [editBadge.heightAnchor constraintEqualToConstant:32.0],
        [editBadge.trailingAnchor constraintEqualToAnchor:avatarHalo.trailingAnchor constant:-2.0],
        [editBadge.bottomAnchor constraintEqualToAnchor:avatarHalo.bottomAnchor constant:-2.0],
    ]];

    self.headerCardView = cardView;
    self.headerEyebrowLabel = eyebrowLabel;
    self.headerNameLabel = nameLabel;
    self.headerHandleLabel = handleLabel;
    self.headerMetaLabel = metaLabel;

    CGSize fittingSize = [self.headerRoot systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    self.headerRoot.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), fittingSize.height);
    self.tableView.tableHeaderView = self.headerRoot;
}

- (void)pp_refreshProfileHeaderContent
{
    NSString *firstName = [self pp_trimmedString:self.draftFirstName];
    if (firstName.length == 0) {
        firstName = [self pp_trimmedString:PPCurrentUser.FirstName];
    }
    NSString *lastName = [self pp_trimmedString:self.draftLastName];
    if (lastName.length == 0) {
        lastName = [self pp_trimmedString:PPCurrentUser.LastName];
    }
    NSArray<NSString *> *nameParts = [@[firstName ?: @"", lastName ?: @""]
        filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
    NSString *fullName = [nameParts componentsJoinedByString:@" "];
    NSString *draftHandle = [self pp_trimmedString:self.draftUserName];
    if (fullName.length == 0) {
        fullName = draftHandle.length > 0 ? draftHandle : [self pp_trimmedString:PPCurrentUser.UserName];
    }
    if (fullName.length == 0) {
        fullName = [self pp_localizedProfileStringForKey:@"UserProfile" fallback:@"Profile"];
    }

    NSString *handle = draftHandle.length > 0 ? draftHandle : [self pp_trimmedString:PPCurrentUser.UserName];
    if (handle.length > 0 && ![handle hasPrefix:@"@"]) {
        handle = [@"@" stringByAppendingString:handle];
    }
    if (handle.length == 0) {
        handle = [self pp_localizedProfileStringForKey:@"profile_identity_hint"
                                              fallback:@"Account details and saved places"];
    }

    NSString *email = [self pp_trimmedString:self.draftUserEmail];
    if (email.length == 0) {
        email = [self pp_trimmedString:PPCurrentUser.UserEmail];
    }

    NSString *phone = @"";
    NSString *draftLocalMobile = [self pp_trimmedString:self.draftMobileLocal];
    NSString *dialCode = [self pp_trimmedString:self.selectedCountry.phoneCode];
    if (draftLocalMobile.length > 0 && dialCode.length > 0) {
        phone = [NSString stringWithFormat:@"%@%@", dialCode, draftLocalMobile];
    } else {
        phone = [self pp_trimmedString:PPCurrentUser.MobileNo];
    }

    NSString *meta = nil;
    if (email.length > 0 && phone.length > 0) {
        meta = [NSString stringWithFormat:@"%@  •  %@", email, phone];
    } else {
        meta = email.length > 0 ? email : phone;
    }
    if (meta.length == 0) {
        meta = [self pp_localizedProfileStringForKey:@"member_since"
                                            fallback:@"Keep your identity and delivery details up to date."];
    }

    self.headerEyebrowLabel.text = [self pp_localizedProfileStringForKey:@"account" fallback:@"Account"];
    self.headerNameLabel.text = fullName;
    self.headerHandleLabel.text = handle;
    self.headerMetaLabel.text = [NSString stringWithFormat:@"  %@  ", meta];
}

#pragma mark - Table Data

- (NSIndexPath *)pp_indexPathForFieldKind:(PPProfileFieldKind)fieldKind
{
    switch (fieldKind) {
        case PPProfileFieldKindUserName:
            return [NSIndexPath indexPathForRow:PPProfileDetailRowUserName inSection:PPProfileSectionDetails];
        case PPProfileFieldKindFirstName:
            return [NSIndexPath indexPathForRow:PPProfileDetailRowFirstName inSection:PPProfileSectionDetails];
        case PPProfileFieldKindLastName:
            return [NSIndexPath indexPathForRow:PPProfileDetailRowLastName inSection:PPProfileSectionDetails];
        case PPProfileFieldKindMobile:
            return [NSIndexPath indexPathForRow:PPProfileContactRowMobile inSection:PPProfileSectionContact];
        case PPProfileFieldKindEmail:
            return [NSIndexPath indexPathForRow:PPProfileContactRowEmail inSection:PPProfileSectionContact];
        case PPProfileFieldKindAbout:
            return [NSIndexPath indexPathForRow:PPProfileContactRowAbout inSection:PPProfileSectionContact];
        default:
            break;
    }
    return nil;
}

- (BOOL)pp_isAddressActionRow:(NSIndexPath *)indexPath
{
    return indexPath.section == PPProfileSectionAddresses && indexPath.row == self.addresses.count;
}

- (BOOL)pp_isAddressRow:(NSIndexPath *)indexPath
{
    return indexPath.section == PPProfileSectionAddresses && indexPath.row < self.addresses.count;
}

- (void)pp_reloadRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    if (!self.isViewLoaded || !self.tableView) {
        return;
    }
    NSArray<NSIndexPath *> *visibleSafeRows = [indexPaths filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSIndexPath *evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [self.tableView numberOfSections] > evaluatedObject.section &&
        [self.tableView numberOfRowsInSection:evaluatedObject.section] > evaluatedObject.row;
    }]];
    if (visibleSafeRows.count == 0) {
        [self.tableView reloadData];
        return;
    }
    [self.tableView reloadRowsAtIndexPaths:visibleSafeRows withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return PPProfileSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case PPProfileSectionDetails:
            return PPProfileDetailRowCount;
        case PPProfileSectionContact:
            return PPProfileContactRowCount;
        case PPProfileSectionAddresses:
            return self.addresses.count + 1;
        case PPProfileSectionPets:
            return 1;
        case PPProfileSectionLogout:
            return 1;
        default:
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == PPProfileSectionDetails) {
        PPProfileTextFieldCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProfileTextFieldCell" forIndexPath:indexPath];
        switch (indexPath.row) {
            case PPProfileDetailRowUserName:
                [cell configureWithTitle:kLang(@"UserName_Palce")
                                    text:self.draftUserName
                             placeholder:kLang(@"UserName_Palce")
                            keyboardType:UIKeyboardTypeDefault
                         textContentType:UITextContentTypeNickname
                           returnKeyType:UIReturnKeyNext
                  autocapitalizationType:UITextAutocapitalizationTypeWords
                               fieldKind:PPProfileFieldKindUserName
                                  target:self
                                  action:@selector(pp_textFieldEditingChanged:)
                                delegate:self];
                break;
            case PPProfileDetailRowFirstName:
                [cell configureWithTitle:kLang(@"firstName_Palce")
                                    text:self.draftFirstName
                             placeholder:kLang(@"Enter_First_Name")
                            keyboardType:UIKeyboardTypeDefault
                         textContentType:UITextContentTypeGivenName
                           returnKeyType:UIReturnKeyNext
                  autocapitalizationType:UITextAutocapitalizationTypeWords
                               fieldKind:PPProfileFieldKindFirstName
                                  target:self
                                  action:@selector(pp_textFieldEditingChanged:)
                                delegate:self];
                break;
            default:
                [cell configureWithTitle:kLang(@"LastName_Palce")
                                    text:self.draftLastName
                             placeholder:kLang(@"Enter_Last_Name")
                            keyboardType:UIKeyboardTypeDefault
                         textContentType:UITextContentTypeFamilyName
                           returnKeyType:UIReturnKeyNext
                  autocapitalizationType:UITextAutocapitalizationTypeWords
                               fieldKind:PPProfileFieldKindLastName
                                  target:self
                                  action:@selector(pp_textFieldEditingChanged:)
                                delegate:self];
                break;
        }
        return cell;
    }

    if (indexPath.section == PPProfileSectionContact) {
        switch (indexPath.row) {
            case PPProfileContactRowCountry: {
                PPProfileSelectorCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProfileSelectorCell" forIndexPath:indexPath];
                NSString *countryName = [self pp_trimmedString:self.selectedCountry.country];
                if (countryName.length == 0) {
                    countryName = kLang(@"TapToSelect");
                }
                [cell configureWithTitle:kLang(@"code_Palce")
                                   value:countryName
                                    flag:self.selectedCountry.flag ?: @""];
                return cell;
            }
            case PPProfileContactRowMobile: {
                PPProfilePhoneCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProfilePhoneCell" forIndexPath:indexPath];
                [cell configureWithTitle:kLang(@"MobileNo_Palce")
                                  prefix:[self pp_trimmedString:self.selectedCountry.phoneCode]
                                    text:self.draftMobileLocal
                             placeholder:kLang(@"MobileNo_Palce")
                               fieldKind:PPProfileFieldKindMobile
                                  target:self
                                  action:@selector(pp_textFieldEditingChanged:)
                                delegate:self];
                return cell;
            }
            case PPProfileContactRowEmail: {
                PPProfileTextFieldCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProfileTextFieldCell" forIndexPath:indexPath];
                [cell configureWithTitle:kLang(@"UserEmail_Palce")
                                    text:self.draftUserEmail
                             placeholder:kLang(@"UserEmail_Palce")
                            keyboardType:UIKeyboardTypeEmailAddress
                         textContentType:UITextContentTypeEmailAddress
                           returnKeyType:UIReturnKeyNext
                  autocapitalizationType:UITextAutocapitalizationTypeNone
                               fieldKind:PPProfileFieldKindEmail
                                  target:self
                                  action:@selector(pp_textFieldEditingChanged:)
                                delegate:self];
                cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
                cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
                return cell;
            }
            default: {
                PPProfileTextViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProfileTextViewCell" forIndexPath:indexPath];
                [cell configureWithTitle:kLang(@"UserAbout_Palce")
                                    text:self.draftUserAbout
                             placeholder:kLang(@"UserAbout_Palce")
                               fieldKind:PPProfileFieldKindAbout
                                delegate:self];
                return cell;
            }
        }
    }

    if (indexPath.section == PPProfileSectionPets) {
        PPProfileActionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProfileActionCell" forIndexPath:indexPath];
        NSString *title = self.petProfilesCount > 0
            ? [NSString stringWithFormat:@"%@ (%ld)",
               (kLang(@"pet_profiles_manage") ?: @"Manage pets"),
               (long)self.petProfilesCount]
            : (kLang(@"pet_profiles_add_first") ?: @"Add your first pet");
        [cell configureWithTitle:title iconName:@"pawprint.circle.fill"];
        cell.accessibilityIdentifier = @"profile_pet_profiles_card";
        cell.semanticContentAttribute = PPProfileCurrentSemanticAttribute();
        return cell;
    }

    if (indexPath.section == PPProfileSectionLogout) {
        PPProfileActionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProfileActionCell" forIndexPath:indexPath];
        [cell configureWithTitle:(kLang(@"logout") ?: @"Log Out") iconName:@"rectangle.portrait.and.arrow.right"];
        cell.contentView.backgroundColor = UIColor.systemRedColor;
        cell.contentView.layer.cornerRadius = 14;
        cell.contentView.layer.masksToBounds = YES;
        cell.titleLabel.textColor = AppForgroundColr;
        cell.iconView.tintColor = AppForgroundColr;
        cell.accessibilityIdentifier = @"profile_logout_button";
        cell.semanticContentAttribute = PPProfileCurrentSemanticAttribute();
        return cell;
    }

    if ([self pp_isAddressActionRow:indexPath]) {
        PPProfileActionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProfileActionCell" forIndexPath:indexPath];
        [cell configureWithTitle:kLang(@"Add New Address") iconName:@"plus"];
        return cell;
    }

    PPProfileAddressCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPProfileAddressCell" forIndexPath:indexPath];
    if (indexPath.row < self.addresses.count) {
        [cell configureWithAddress:self.addresses[indexPath.row]];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (!PPIOS26()) {
       // [Styling applyBackgroundStyleForTableView:tableView cell:cell indexPath:indexPath useRowCardMode:NO];
    }

    cell.backgroundColor = UIColor.clearColor;
    cell.clipsToBounds = NO;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.contentView.backgroundColor = indexPath.section == PPProfileSectionLogout ? [UIColor.redColor colorWithAlphaComponent:0.82]  :  [self pp_profileSurfaceColor];
    cell.contentView.layer.cornerRadius = 20.0;
    cell.contentView.layer.masksToBounds = YES;
    cell.contentView.layer.borderWidth = 1.0;
    [cell.contentView pp_setBorderColor:[self pp_profileSurfaceBorderColor]];
    [cell pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    cell.layer.shadowOpacity = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.02 : 0.05;
    cell.layer.shadowRadius = 12.0;
    cell.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    cell.layer.masksToBounds = NO;

    if (self.isRunningProfileEntranceAnimation) {
        return;
    }

    if (!self.allowsCellDisplayAnimation) {
        [self pp_finishDisplayAnimationStateForCell:cell];
        return;
    }

    [self pp_animateProfileDisplayCell:cell atIndexPath:indexPath delay:0.0];
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == PPProfileSectionContact && indexPath.row == PPProfileContactRowCountry) {
        return YES;
    }
    if (indexPath.section == PPProfileSectionPets) {
        return YES;
    }
    if (indexPath.section == PPProfileSectionLogout) {
        return YES;
    }
    return [self pp_isAddressRow:indexPath] || [self pp_isAddressActionRow:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == PPProfileSectionContact && indexPath.row == PPProfileContactRowCountry) {
        [self pp_presentCountryPicker];
        return;
    }

    if (indexPath.section == PPProfileSectionPets) {
        PPPetProfilesViewController *petsVC = [PPPetProfilesViewController new];
        [self.navigationController pushViewController:petsVC animated:YES];
        return;
    }

    if (indexPath.section == PPProfileSectionLogout) {
        [PPFunc triggerLightHaptic];
        [self logoutTapped];
        return;
    }

    if ([self pp_isAddressActionRow:indexPath]) {
        [self openAddressFormForNew];
        return;
    }

    if ([self pp_isAddressRow:indexPath]) {
        PPAddressModel *address = self.addresses[indexPath.row];
        [self openAddressFormFor:address];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self pp_isAddressRow:indexPath];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle != UITableViewCellEditingStyleDelete || ![self pp_isAddressRow:indexPath]) {
        return;
    }

    PPAddressModel *address = self.addresses[indexPath.row];
    if (!address) {
        return;
    }

    [[PPAddressesManager sharedManager] deleteAddress:address completion:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [PPHUD showSuccess:kLang(@"AddressesDeleted") subtitle:@""];
            } else {
                [PPHUD showError:kLang(@"DeleteFailed") subtitle:error.localizedDescription ?: @""];
            }
            [self reloadAddressesSection];
        });
    }];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case PPProfileSectionDetails:
        case PPProfileSectionContact:
        case PPProfileSectionAddresses:
        case PPProfileSectionPets:
            return 73.0;
        case PPProfileSectionLogout:
            return 24.0;
        default:
            return 0.000001;
    }
}

// Leave heightForFooterInSection unchanged.
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 0.000001;
}

/*
    - (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
    {
        if (indexPath.section == PPProfileSectionPets) {
            return 60.0;
        }
        return UITableViewAutomaticDimension;
    }*/
// New method: heightForRowAtIndexPath
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == PPProfileSectionPets) {
        return 64.0;
    }
    if (indexPath.section == PPProfileSectionLogout) {
        return 56.0;
    }
        else  if ([self pp_isAddressActionRow:indexPath]) {
            return 64.0;
        }
    
    return UITableViewAutomaticDimension;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    return [UIView new];
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForFooterInSection:(NSInteger)section
{
    return 0.000001;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section
{
    return [self tableView:tableView heightForHeaderInSection:section];
}



- (NSArray<NSString *> *)pp_sectionHeaderContentForSection:(NSInteger)section
{
    switch (section) {
        case PPProfileSectionDetails:
            return @[
                kLang(@"profile_details"),
                kLang(@"profile_details_hint")
            ];
        case PPProfileSectionContact:
            return @[
                kLang(@"contact_and_bio"),
                kLang(@"contact_and_bio_hint")
            ];
        case PPProfileSectionAddresses:
            return @[
                kLang(@"saved_addresses"),
                kLang(@"saved_addresses_hint")
            ];
        case PPProfileSectionPets:
            return @[
                (kLang(@"pet_profiles_title") ?: @"Pet Profiles"),
                (kLang(@"pet_profiles_subtitle") ?: @"Manage your pets, vaccines, and default pet")
            ];
        default:
            return @[@"", @""];
    }
}

- (UIView *)pp_profileSectionHeaderViewWithTitle:(NSString *)title subtitle:(NSString *)subtitle
{
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = UIColor.clearColor;

    UIView *accentBar = [[UIView alloc] init];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    accentBar.layer.cornerRadius = 2.0;
    [container addSubview:accentBar];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.text = title ?: @"";
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [container addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.9];
    subtitleLabel.text = subtitle ?: @"";
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.numberOfLines = 2;
    [container addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [accentBar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20.0],
        [accentBar.topAnchor constraintEqualToAnchor:container.topAnchor constant:14.0],
        [accentBar.widthAnchor constraintEqualToConstant:28.0],
        [accentBar.heightAnchor constraintEqualToConstant:4.0],

        [titleLabel.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:9.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:accentBar.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:container.bottomAnchor constant:-8.0]
    ]];

    return container;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == PPProfileSectionLogout || section >= PPProfileSectionCount) {
        return [UIView new];
    }
    NSArray<NSString *> *content = [self pp_sectionHeaderContentForSection:section];
    return [self pp_profileSectionHeaderViewWithTitle:content.firstObject subtitle:content.lastObject];
}

#pragma mark - Editing

- (void)pp_textFieldEditingChanged:(UITextField *)textField
{
    NSString *value = textField.text ?: @"";
    switch ((PPProfileFieldKind)textField.tag) {
        case PPProfileFieldKindUserName:
            self.draftUserName = value;
            [self setformDataArray:value forKey:@"UserName"];
            break;
        case PPProfileFieldKindFirstName:
            self.draftFirstName = value;
            [self setformDataArray:value forKey:@"firstName"];
            break;
        case PPProfileFieldKindLastName:
            self.draftLastName = value;
            [self setformDataArray:value forKey:@"LastName"];
            break;
        case PPProfileFieldKindMobile: {
            self.draftMobileLocal = value;
            NSString *countryCode = [self pp_trimmedString:self.selectedCountry.phoneCode];
            NSString *localNumber = [self pp_trimmedString:value];
            NSString *combined = localNumber.length > 0 ? [NSString stringWithFormat:@"%@%@", countryCode ?: @"", localNumber] : @"";
            [self setformDataArray:combined forKey:@"MobileNo"];
            [self setformDataArray:localNumber forKey:kMobileNoRow];
            break;
        }
        case PPProfileFieldKindEmail:
            self.draftUserEmail = value;
            [self setformDataArray:value forKey:@"UserEmail"];
            break;
        default:
            break;
    }

    [self pp_refreshProfileHeaderContent];
    [self markFormAsEdited];
}

- (void)textViewDidChange:(UITextView *)textView
{
    if ((PPProfileFieldKind)textView.tag == PPProfileFieldKindAbout) {
        self.draftUserAbout = textView.text ?: @"";
        [self setformDataArray:textView.text forKey:@"UserAbout"];
    }

    UIView *view = textView;
    while (view && ![view isKindOfClass:PPProfileTextViewCell.class]) {
        view = view.superview;
    }
    if ([view isKindOfClass:PPProfileTextViewCell.class]) {
        PPProfileTextViewCell *cell = (PPProfileTextViewCell *)view;
        [cell updatePlaceholderVisibility];
        [cell updatePreferredHeight];
    }

    [self.tableView beginUpdates];
    [self.tableView endUpdates];
    [self markFormAsEdited];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    switch ((PPProfileFieldKind)textField.tag) {
        case PPProfileFieldKindUserName:
            [self pp_focusFieldKind:PPProfileFieldKindFirstName];
            return NO;
        case PPProfileFieldKindFirstName:
            [self pp_focusFieldKind:PPProfileFieldKindLastName];
            return NO;
        case PPProfileFieldKindLastName:
            [self pp_focusFieldKind:PPProfileFieldKindEmail];
            return NO;
        case PPProfileFieldKindEmail:
            [self pp_focusFieldKind:PPProfileFieldKindAbout];
            return NO;
        default:
            [textField resignFirstResponder];
            return YES;
    }
}

- (void)pp_focusFieldKind:(PPProfileFieldKind)fieldKind
{
    NSIndexPath *indexPath = [self pp_indexPathForFieldKind:fieldKind];
    if (!indexPath) {
        return;
    }

    [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        if ([cell isKindOfClass:PPProfileTextFieldCell.class]) {
            [((PPProfileTextFieldCell *)cell).textField becomeFirstResponder];
        } else if ([cell isKindOfClass:PPProfilePhoneCell.class]) {
            [((PPProfilePhoneCell *)cell).textField becomeFirstResponder];
        } else if ([cell isKindOfClass:PPProfileTextViewCell.class]) {
            [((PPProfileTextViewCell *)cell).textView becomeFirstResponder];
        }
    });
}

- (void)pp_presentCountryPicker
{
    NSMutableArray<CountryCodeModel *> *countries = [GM getMiddleEastCountriesForLanguage:[Language currentLanguageCode]];
    if (countries.count == 0) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    PPSelectOptionViewController *vc = [[PPSelectOptionViewController alloc]
        initWithOptions:countries
                  title:kLang(@"code_Palce")
                    row:nil
       presentationStyle:PPSelectOptionPresentationSheet
             completion:^(id _Nullable selectedObject) {
        PPDispatchMain(^{
            if (![selectedObject isKindOfClass:[CountryCodeModel class]]) {
                return;
            }
            [weakSelf pp_updateSelectedCountry:(CountryCodeModel *)selectedObject userInitiated:YES];
        });
    }];
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)pp_updateSelectedCountry:(CountryCodeModel *)country userInitiated:(BOOL)userInitiated
{
    if (![country isKindOfClass:CountryCodeModel.class]) {
        return;
    }

    self.selectedCountry = country;
    [self setformDataArray:@(country.ID) forKey:@"CountryID"];
    [self pp_refreshProfileHeaderContent];
    [self pp_reloadRowsAtIndexPaths:@[
        [NSIndexPath indexPathForRow:PPProfileContactRowCountry inSection:PPProfileSectionContact],
        [NSIndexPath indexPathForRow:PPProfileContactRowMobile inSection:PPProfileSectionContact]
    ]];

    if (userInitiated) {
        [self markFormAsEdited];
    }
}

#pragma mark - Addresses

- (void)listenToAddresses
{
    [self.addressListener remove];
    self.addressListener = nil;

    if (PPCurrentUser.Addresses.count > 0) {
        [self pp_applyLatestAddresses:PPCurrentUser.Addresses];
    }

    NSString *authenticatedUID = [PPADDRESS currentAuthenticatedUserID] ?: @"";
    if (authenticatedUID.length == 0) {
        [self pp_applyLatestAddresses:@[]];
        return;
    }

    __weak typeof(self) weakSelf = self;
    self.addressListener = [[PPAddressesManager sharedManager]
        listenToAddressesWithBlock:^(NSArray<PPAddressModel *> * _Nullable addresses, NSError * _Nullable error) {
        if (error) {
            BOOL isUnauthenticatedError = [error.domain isEqualToString:@"PPAddressesManager"] && error.code == 401;
            if (isUnauthenticatedError || [PPADDRESS currentAuthenticatedUserID].length == 0) {
                [weakSelf pp_applyLatestAddresses:@[]];
                return;
            }
            NSLog(@"Address listener error: %@", error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                [PPHUD showError:kLang(@"SomethingWentWrong") subtitle:error.localizedDescription ?: @""];
            });
            return;
        }
        [weakSelf pp_applyLatestAddresses:addresses ?: @[]];
    }];
}

- (void)pp_applyLatestAddresses:(NSArray<PPAddressModel *> *)addresses
{
    self.addresses = addresses ?: @[];
    UserModel *currentUser = UserManager.sharedManager.currentUser;
    if (currentUser) {
        currentUser.Addresses = self.addresses.mutableCopy;
        [UserManager.sharedManager cacheUser:currentUser];
    }
    [self pp_refreshProfileHeaderContent];
    [self debouncedReloadAddresses];
}

- (void)debouncedReloadAddresses
{
    static BOOL isScheduled = NO;
    if (isScheduled) {
        return;
    }
    isScheduled = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self reloadAddressesSection];
        isScheduled = NO;
    });
}

- (void)reloadAddressesSection
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:PPProfileSectionAddresses];
        if (self.tableView.window) {
            [self.tableView reloadSections:indexSet withRowAnimation:UITableViewRowAnimationNone];
        } else {
            [self.tableView reloadData];
        }
    });
}

- (void)openAddressFormForNew
{
    AddressFormVC *vc = [[AddressFormVC alloc] init];
    vc.delegate = self;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openAddressFormFor:(PPAddressModel *)address
{
    AddressFormVC *vc = [[AddressFormVC alloc] initWithAddress:address];
    vc.delegate = self;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)addressFormVC:(AddressFormVC *)controller didSaveAddress:(PPAddressModel *)address
{
    __weak typeof(self) weakSelf = self;
    [PPADDRESS getAllAddressesWithCompletion:^(NSArray<PPAddressModel *> * _Nonnull addresses, NSError * _Nullable error) {
        if (error) {
            return;
        }
        [weakSelf pp_applyLatestAddresses:addresses ?: @[]];
    }];
}

- (void)addressFormVC:(AddressFormVC *)controller didDeleteAddress:(PPAddressModel *)address
{
    __weak typeof(self) weakSelf = self;
    [PPADDRESS getAllAddressesWithCompletion:^(NSArray<PPAddressModel *> * _Nonnull addresses, NSError * _Nullable error) {
        if (error) {
            return;
        }
        [weakSelf pp_applyLatestAddresses:addresses ?: @[]];
    }];
}

#pragma mark - Avatar

- (void)didTapAddPhoto
{
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    sheet.view.semanticContentAttribute = PPProfileCurrentSemanticAttribute();

    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Camera")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            [self openCamera];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Photo_Library")
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *action) {
        [self openPhotoPicker];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    sheet.popoverPresentationController.sourceView = self.addPhotoBtn;
    sheet.popoverPresentationController.sourceRect = self.addPhotoBtn.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (BOOL)pp_isRenderableAvatarImage:(UIImage *)image
{
    return [image isKindOfClass:UIImage.class] &&
           image.size.width > 0.0 &&
           image.size.height > 0.0;
}

- (void)pp_processPickedAvatarImage:(UIImage *)image error:(NSError *)error
{
    if (error) {
        NSLog(@"Profile avatar picker failed: %@", error.localizedDescription ?: @"Unknown error");
        return;
    }

    if (![self pp_isRenderableAvatarImage:image]) {
        NSLog(@"Profile avatar picker returned a non-renderable image.");
        return;
    }

    PPDispatchMain(^{
        [self handlePickedImage:image];
    });
}

- (void)pp_loadAvatarImageFromItemProvider:(NSItemProvider *)itemProvider
{
    if (!itemProvider) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    if ([itemProvider canLoadObjectOfClass:UIImage.class]) {
        [itemProvider loadObjectOfClass:UIImage.class completionHandler:^(id<NSItemProviderReading>  _Nullable object, NSError * _Nullable error) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            UIImage *image = [object isKindOfClass:UIImage.class] ? (UIImage *)object : nil;
            [self pp_processPickedAvatarImage:image error:error];
        }];
        return;
    }

    if ([itemProvider hasItemConformingToTypeIdentifier:@"public.image"]) {
        [itemProvider loadDataRepresentationForTypeIdentifier:@"public.image"
                                            completionHandler:^(NSData * _Nullable data, NSError * _Nullable error) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }

            UIImage *image = data.length > 0 ? [UIImage imageWithData:data] : nil;
            [self pp_processPickedAvatarImage:image error:error];
        }];
    }
}

- (void)openPhotoPicker
{
    if (@available(iOS 14.0, *)) {
        PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
        config.filter = [PHPickerFilter imagesFilter];
        config.selectionLimit = 1;

        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    } else {
        [self openLegacyPicker];
    }
}

- (void)openLegacyPicker
{
    [PPPermissionHelper requestPhotoLibraryPermissionFromViewController:self completion:^(BOOL granted) {
        if (!granted) {
            return;
        }

        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        [self presentViewController:picker animated:YES completion:nil];
    }];
}

- (void)openCamera
{
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        return;
    }

    [PPPermissionHelper requestCameraPermissionFromViewController:self completion:^(BOOL granted) {
        if (!granted) {
            return;
        }
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        picker.sourceType = UIImagePickerControllerSourceTypeCamera;
        [self presentViewController:picker animated:YES completion:nil];
    }];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) {
        return;
    }

    PHPickerResult *result = results.firstObject;
    [self pp_loadAvatarImageFromItemProvider:result.itemProvider];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info
{
    UIImage *image = info[UIImagePickerControllerEditedImage];
    if (![self pp_isRenderableAvatarImage:image]) {
        image = info[UIImagePickerControllerOriginalImage];
    }
    [picker dismissViewControllerAnimated:YES completion:^{
        [self handlePickedImage:image];
    }];
}

- (void)handlePickedImage:(UIImage *)image
{
    if (![self pp_isRenderableAvatarImage:image]) {
        return;
    }
    [UIImage pp_presentCircularCropperWithImage:image fromController:self];
}

- (void)cropViewController:(TOCropViewController *)cropViewController
     didCropToCircularImage:(UIImage *)image
                   withRect:(CGRect)cropRect
                      angle:(NSInteger)angle
{
    [self updateAvatar:image];
    [cropViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)updateAvatar:(UIImage *)image
{
    [UIView transitionWithView:self.avatarIMV
                      duration:0.3
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        self.pendingAvatarImage = image;
        self.avatarIMV.imageView.image = image;
        self.avatarIMV.tintColor = nil;
        self.avatarIMV.backgroundColor = UIColor.clearColor;
        [self markFormAsEdited];
    } completion:nil];

    [PPFunc triggerLightHaptic];
}

#pragma mark - Save / Validation

- (void)updateUserData
{
    if (self.isSavingProfile) {
        return;
    }

    FIRUser *authUser = [FIRAuth auth].currentUser;
    if (!authUser.uid.length) {
        [PPAlertHelper showErrorIn:self title:kLang(@"PleaseRegister") subtitle:@""];
        return;
    }

    [self.view endEditing:YES];

    NSString *firstName = [self pp_trimmedString:self.draftFirstName];
    NSString *lastName = [self pp_trimmedString:self.draftLastName];
    NSString *userName = [self pp_trimmedString:self.draftUserName];
    NSString *userEmail = [[self pp_trimmedString:self.draftUserEmail] lowercaseString];
    NSString *about = [self pp_trimmedString:self.draftUserAbout];

    if (userName.length == 0) {
        NSString *composed = [NSString stringWithFormat:@"%@ %@", firstName ?: @"", lastName ?: @""];
        userName = [self pp_trimmedString:composed];
    }
    if (userName.length == 0) {
        [self pp_showValidationErrorForField:PPProfileFieldKindUserName subtitle:kLang(@"UserName_Palce")];
        return;
    }

    if (![self pp_isValidEmail:userEmail]) {
        [self pp_showValidationErrorForField:PPProfileFieldKindEmail subtitle:kLang(@"UserEmail_Palce")];
        return;
    }

    CountryCodeModel *country = self.selectedCountry;
    if (!country) {
        NSInteger fallbackCountryID = PPCurrentUser.CountryID;
        if (fallbackCountryID > 0) {
            country = [[self.contriesArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %ld", fallbackCountryID]] firstObject];
        }
        if (!country) {
            country = [self pp_countryWithISOCode:[GM getCurrentCountryFromCarrier]];
        }
        if (!country) {
            country = [self pp_countryWithISOCode:CitiesManager.shared.CurrentCountry.iso];
        }
        if (!country) {
            country = [self pp_countryWithISOCode:[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode]];
        }
    }
    if (!country && self.contriesArray.count > 0) {
        country = [self pp_qatarCountry];
    }
    if (!country || country.ID <= 0) {
        [self pp_showCountryValidationError];
        return;
    }
    self.selectedCountry = country;

    NSString *countryDialCode = [self pp_trimmedString:country.phoneCode];
    if (countryDialCode.length > 0 && ![countryDialCode hasPrefix:@"+"]) {
        countryDialCode = [@"+" stringByAppendingString:countryDialCode];
    }
    NSString *countryISOCode = [[self pp_trimmedString:country.isoCountryCode] uppercaseString];
    if (countryDialCode.length == 0 || countryISOCode.length != 2) {
        [self pp_showCountryValidationError];
        return;
    }

    NSString *rawMobileInput = [self pp_trimmedString:self.draftMobileLocal];
    NSString *normalizedMobile = [self pp_normalizedE164FromInput:rawMobileInput dialCode:countryDialCode];
    NSString *existingMobile = [self pp_trimmedString:PPCurrentUser.MobileNo];
    if (rawMobileInput.length == 0 && existingMobile.length > 0) {
        NSString *fallbackDialCode = [existingMobile hasPrefix:@"+"] ? @"" : countryDialCode;
        normalizedMobile = [self pp_normalizedE164FromInput:existingMobile dialCode:fallbackDialCode];
    }
    if (rawMobileInput.length > 0 && normalizedMobile.length == 0) {
        [self pp_showValidationErrorForField:PPProfileFieldKindMobile subtitle:kLang(@"MobileNo_Palce")];
        return;
    }
    NSInteger mobileDigitsCount = [[normalizedMobile stringByReplacingOccurrencesOfString:@"+" withString:@""] length];
    if (normalizedMobile.length > 0 && (mobileDigitsCount < 8 || mobileDigitsCount > 15)) {
        [self pp_showValidationErrorForField:PPProfileFieldKindMobile subtitle:kLang(@"MobileNo_Palce")];
        return;
    }
    if (normalizedMobile.length > 0 && countryDialCode.length > 0 && ![normalizedMobile hasPrefix:countryDialCode]) {
        CountryCodeModel *mobileCountry = [self pp_countryFromStoredMobileNumber:normalizedMobile];
        if (!mobileCountry) {
            [self pp_showCountryValidationError];
            return;
        }
        self.selectedCountry = mobileCountry;
        country = mobileCountry;
        countryDialCode = [self pp_trimmedString:mobileCountry.phoneCode];
        if (countryDialCode.length > 0 && ![countryDialCode hasPrefix:@"+"]) {
            countryDialCode = [@"+" stringByAppendingString:countryDialCode];
        }
        countryISOCode = [[self pp_trimmedString:mobileCountry.isoCountryCode] uppercaseString];
        if (countryDialCode.length == 0 || countryISOCode.length != 2) {
            [self pp_showCountryValidationError];
            return;
        }
        [self setformDataArray:@(mobileCountry.ID) forKey:@"CountryID"];
        [self pp_reloadRowsAtIndexPaths:@[
            [NSIndexPath indexPathForRow:PPProfileContactRowCountry inSection:PPProfileSectionContact],
            [NSIndexPath indexPathForRow:PPProfileContactRowMobile inSection:PPProfileSectionContact]
        ]];
    }

    NSString *currentEmail = [[self pp_trimmedString:authUser.email] lowercaseString];
    NSString *baselineEmail = @"";
    id baselineEmailValue = self.profileDraftBaseline[@"userEmail"];
    if ([baselineEmailValue isKindOfClass:NSString.class]) {
        baselineEmail = [[self pp_trimmedString:baselineEmailValue] lowercaseString];
    }
    BOOL emailFieldEdited = ![userEmail isEqualToString:baselineEmail];
    if (userEmail.length == 0) {
        userEmail = currentEmail;
    }
    BOOL emailChanged = emailFieldEdited && ![userEmail isEqualToString:currentEmail];
    if (emailChanged) {
        NSString *authProviderID = @"";
        for (id<FIRUserInfo> provider in authUser.providerData) {
            NSString *providerID = [[self pp_trimmedString:provider.providerID] lowercaseString];
            if (providerID.length == 0 || [providerID isEqualToString:@"firebase"]) {
                continue;
            }
            authProviderID = providerID;
            break;
        }

        if ([authProviderID isEqualToString:@"google.com"] || [authProviderID isEqualToString:@"apple.com"]) {
            [PPAlertHelper showWarningIn:self title:kLang(@"UserEmail_Palce") subtitle:kLang(@"profile_email_managed_by_provider")];
            return;
        }

        if ([authProviderID isEqualToString:@"password"]) {
            [PPAlertHelper showWarningIn:self title:kLang(@"UserEmail_Palce") subtitle:kLang(@"profile_email_reauth_required")];
            return;
        }
    }

    NSString *existingAuthMobile = [self pp_trimmedString:authUser.phoneNumber];
    NSString *baselineMobileForCompare = existingAuthMobile.length > 0 ? existingAuthMobile : existingMobile;
    NSString *baselineDialHint = [baselineMobileForCompare hasPrefix:@"+"] ? @"" : countryDialCode;
    NSString *baselineNormalizedMobile = [self pp_normalizedE164FromInput:baselineMobileForCompare dialCode:baselineDialHint];

    NSString *draftBaselineLocalMobile = @"";
    id draftBaselineMobileValue = self.profileDraftBaseline[@"mobileLocal"];
    if ([draftBaselineMobileValue isKindOfClass:NSString.class]) {
        draftBaselineLocalMobile = [self pp_trimmedString:draftBaselineMobileValue];
    }
    NSString *draftBaselineRawMobile = draftBaselineLocalMobile.length > 0 ? draftBaselineLocalMobile : existingMobile;
    NSString *draftBaselineDialHint = draftBaselineRawMobile.length > 0 && ![draftBaselineRawMobile hasPrefix:@"+"] ? countryDialCode : @"";
    NSString *draftBaselineNormalizedMobile = [self pp_normalizedE164FromInput:draftBaselineRawMobile dialCode:draftBaselineDialHint];
    BOOL mobileFieldEdited = ![normalizedMobile isEqualToString:draftBaselineNormalizedMobile];
    BOOL editedDataIncludesMobileNumber = (self.formDataArray[@"MobileNo"] != nil) || (self.formDataArray[kMobileNoRow] != nil);
    BOOL mobileChanged = mobileFieldEdited && normalizedMobile.length > 0 && ![normalizedMobile isEqualToString:baselineNormalizedMobile];
    BOOL authUsesPhoneProvider = [self pp_authUser:authUser hasProviderID:@"phone"];

    NSMutableDictionary<NSString *, id> *updates = [NSMutableDictionary dictionary];
    updates[@"FirstName"] = firstName ?: @"";
    updates[@"LastName"] = lastName ?: @"";
    updates[@"UserName"] = userName;
    updates[@"UserAbout"] = about ?: @"";
    updates[@"CountryID"] = @(country.ID);
    updates[@"CountryName"] = country.country ?: @"";
    updates[@"CountryDialCode"] = countryDialCode;
    updates[@"CountryIsoCode"] = countryISOCode;
    if (normalizedMobile.length > 0) {
        updates[@"MobileNo"] = normalizedMobile;
    }
    if (emailChanged) {
        updates[@"UserEmail"] = userEmail ?: @"";
        updates[@"email"] = userEmail ?: @"";
    }
    updates[FUUpdateKeyDisplayName] = userName;

    __weak typeof(self) weakSelf = self;
    void (^commitUpdates)(void) = ^{
        [UsrMgr updateCurrentUserProfileWithValues:updates completion:^(NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) {
                    return;
                }

                [self pp_setProfileSaving:NO];
                [PPHUD dismiss];

                if (error) {
                    NSLog(@"Profile update failed: %@", error.localizedDescription);
                    [PPAlertHelper showErrorIn:self title:kLang(@"StatusSaveFailed") subtitle:error.localizedDescription ?: @""];
                    return;
                }

                [UsrMgr reloadCurrentUserWithCompletion:^(UserModel * _Nullable user, NSError * _Nullable loadError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (user && !loadError) {
                            [UsrMgr cacheUser:user];
                        }
                        [self pp_syncDraftStateFromCurrentUser];
                        [PPHUD showSuccess:kLang(@"Saved")];
                        if ([self.delegate respondsToSelector:@selector(refereshAvatar)]) {
                            [self.delegate refereshAvatar];
                        }
                    });
                }];
            });
        }];
    };

    void (^performSavePipeline)(void) = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        [self pp_setProfileSaving:YES];
        [PPHUD showLoading:kLang(@"Saving")];

        if (self.pendingAvatarImage) {
            [self uploadAvatar:self.pendingAvatarImage forUserID:authUser.uid completion:^(NSURL * _Nullable url, NSError * _Nullable err) {
                if (url.absoluteString.length > 0) {
                    updates[FUUpdateKeyPhotoURL] = url.absoluteString;
                    updates[@"UserImageUrl"] = url.absoluteString;
                    updates[@"photoURL"] = url.absoluteString;
                } else if (err) {
                    NSLog(@"Avatar upload failed, continuing without new avatar: %@", err.localizedDescription);
                }
                commitUpdates();
            }];
            return;
        }

        commitUpdates();
    };

    if (authUsesPhoneProvider && editedDataIncludesMobileNumber && mobileChanged) {
        [self pp_presentPhoneVerificationForProfileMobileChange:normalizedMobile completion:^(NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) {
                    return;
                }

                if (error) {
                    [PPAlertHelper showErrorIn:self title:kLang(@"StatusSaveFailed") subtitle:error.localizedDescription ?: @""];
                    return;
                }

                if (PPCurrentUser) {
                    PPCurrentUser.MobileNo = normalizedMobile;
                }
                performSavePipeline();
            });
        }];
        return;
    }

    performSavePipeline();
}

- (void)pp_showValidationErrorForField:(PPProfileFieldKind)fieldKind subtitle:(NSString *)subtitle
{
    NSIndexPath *indexPath = [self pp_indexPathForFieldKind:fieldKind];
    if (indexPath) {
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UITableViewCell *badCell = [self.tableView cellForRowAtIndexPath:indexPath];
            [self animateCell:badCell];
        });
    }
    [PPAlertHelper showInfoIn:self title:kLang(@"PleaseFillFields") subtitle:subtitle ?: @""];
}

- (void)pp_showCountryValidationError
{
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:PPProfileContactRowCountry inSection:PPProfileSectionContact];
    [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UITableViewCell *badCell = [self.tableView cellForRowAtIndexPath:indexPath];
        [self animateCell:badCell];
    });
    [PPAlertHelper showInfoIn:self title:kLang(@"PleaseFillFields") subtitle:kLang(@"SelectCountry")];
}

- (void)animateCell:(UITableViewCell *)cell
{
    if (!cell) {
        return;
    }
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animation];
    animation.keyPath = @"position.x";
    animation.values = @[@0, @20, @-20, @10, @0];
    animation.keyTimes = @[@0, @(1 / 6.0), @(3 / 6.0), @(5 / 6.0), @1];
    animation.duration = 0.3;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    animation.additive = YES;
    [cell.layer addAnimation:animation forKey:@"shake"];
}

#pragma mark - Phone Verification / Upload

- (void)uploadAvatar:(UIImage *)image
           forUserID:(NSString *)userID
          completion:(void (^)(NSURL * _Nullable url, NSError * _Nullable error))completion
{
    if (!image || userID.length == 0) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"app.profile" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Missing image or user id"}]);
        }
        return;
    }

    NSData *jpeg = UIImageJPEGRepresentation(image, 0.82);
    if (!jpeg) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"app.profile" code:-2 userInfo:@{NSLocalizedDescriptionKey: kLang(@"error_could_not_encode_image")}]);
        }
        return;
    }

    NSString *fileName = [NSString stringWithFormat:@"avatar_%@", @((long long)(NSDate.date.timeIntervalSince1970 * 1000))];
    NSString *path = [NSString stringWithFormat:@"users/%@/%@.jpg", userID, fileName];

    FIRStorage *storage = [FIRStorage storage];
    FIRStorageReference *ref = [[storage reference] child:path];

    FIRStorageMetadata *meta = [FIRStorageMetadata new];
    meta.contentType = @"image/jpeg";

    [ref putData:jpeg metadata:meta completion:^(FIRStorageMetadata * _Nullable metadata, NSError * _Nullable error) {
        if (error) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }
        [ref downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error2) {
            if (completion) {
                completion(URL, error2);
            }
        }];
    }];
}

- (void)pp_presentPhoneVerificationForProfileMobileChange:(NSString *)newMobile
                                              completion:(void (^)(NSError * _Nullable error))completion
{
    NSString *safePhone = [self pp_trimmedString:newMobile];
    if (safePhone.length == 0) {
        if (completion) {
            NSError *invalidPhoneError = [NSError errorWithDomain:@"ProfileVC.PhoneUpdate"
                                                             code:1001
                                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"auth_phone_required_message")}];
            completion(invalidPhoneError);
        }
        return;
    }

    [PPHUD showLoading:kLang(@"auth_sending_code_title")];

    __weak typeof(self) weakSelf = self;
    __block NSString *currentVerificationID = @"";
    void (^sendCodeToPhone)(PPVerificationResendCompletion resendCompletion) = ^(PPVerificationResendCompletion resendCompletion) {
        [[FIRPhoneAuthProvider provider] verifyPhoneNumber:safePhone UIDelegate:nil completion:^(NSString * _Nullable verificationID, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error || verificationID.length == 0) {
                    if (resendCompletion) {
                        NSError *resolvedError = error ?: [NSError errorWithDomain:@"ProfileVC.PhoneUpdate"
                                                                              code:1002
                                                                          userInfo:@{NSLocalizedDescriptionKey: kLang(@"auth_sending_code_failed_title")}];
                        resendCompletion(NO, resolvedError);
                    }
                    return;
                }

                currentVerificationID = verificationID ?: @"";
                [[NSUserDefaults standardUserDefaults] setObject:currentVerificationID forKey:@"authVerificationID"];
                [[NSUserDefaults standardUserDefaults] synchronize];

                if (resendCompletion) {
                    resendCompletion(YES, nil);
                }
            });
        }];
    };

    sendCodeToPhone(^(BOOL success, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            if (completion) {
                NSError *deallocatedError = [NSError errorWithDomain:@"ProfileVC.PhoneUpdate"
                                                                code:1003
                                                            userInfo:@{NSLocalizedDescriptionKey: kLang(@"error_session_expired")}];
                completion(deallocatedError);
            }
            return;
        }

        [PPHUD dismiss];

        if (!success) {
            if (completion) {
                completion(error);
            }
            return;
        }

        PPVerificationCodeViewController *vc = [[PPVerificationCodeViewController alloc] initWithPhone:safePhone];
        vc.onCodeVerificationRequested = ^(NSString *code, PPVerificationCodeCheckCompletion codeCompletion) {
            NSString *verificationID = currentVerificationID.length
                ? currentVerificationID
                : ([[NSUserDefaults standardUserDefaults] stringForKey:@"authVerificationID"] ?: @"");
            if (verificationID.length == 0) {
                NSError *missingVerificationError = [NSError errorWithDomain:@"ProfileVC.PhoneUpdate"
                                                                        code:1004
                                                                    userInfo:@{NSLocalizedDescriptionKey: kLang(@"invalid_code_message")}];
                if (codeCompletion) {
                    codeCompletion(NO, missingVerificationError);
                }
                return;
            }

            FIRUser *currentAuthUser = [FIRAuth auth].currentUser;
            if (!currentAuthUser) {
                NSError *authMissingError = [NSError errorWithDomain:@"ProfileVC.PhoneUpdate"
                                                                code:1005
                                                            userInfo:@{NSLocalizedDescriptionKey: kLang(@"PleaseRegister")}];
                if (codeCompletion) {
                    codeCompletion(NO, authMissingError);
                }
                return;
            }

            FIRPhoneAuthCredential *credential = [[FIRPhoneAuthProvider provider] credentialWithVerificationID:verificationID verificationCode:code ?: @""];
            [currentAuthUser updatePhoneNumberCredential:credential completion:^(NSError * _Nullable updateError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (updateError) {
                        if (codeCompletion) {
                            codeCompletion(NO, updateError);
                        }
                        return;
                    }

                    if (completion) {
                        completion(nil);
                    }
                    if (codeCompletion) {
                        codeCompletion(YES, nil);
                    }
                });
            }];
        };
        vc.onResendRequested = ^(PPVerificationResendCompletion resendCompletion) {
            sendCodeToPhone(resendCompletion);
        };

        [PPFunc presentSheetFrom:self sheetVC:vc detentStyle:PPSheetDetentStyleMediumOnly];
    });
}

#pragma mark - Logout / Language

- (void)logoutTapped
{
    NSString *lastSelectedLanguage = Language.currentLanguageCode;
    LeaveFeedbackViewController *feedbackVC = [[LeaveFeedbackViewController alloc] init];
    feedbackVC.onLogout = ^{
        [Language userSelectedLanguage:lastSelectedLanguage];
        [self applyLanguageChangeAndReloadUIFrom:self];
        [AppData stopAllListeners];
    };
    [PPFunc presentSheetFrom:self sheetVC:feedbackVC detentStyle:PPSheetDetentStyle70];
}

- (void)applyLanguageChangeAndReloadUIFrom:(UIViewController *)sourceVC
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [self keyWindow];
        if (!window) {
            return;
        }

        window.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

        UIViewController *newRoot = [self buildRootController];
        if (!newRoot) {
            return;
        }

        [UIView transitionWithView:window
                          duration:0.35
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            BOOL old = [UIView areAnimationsEnabled];
            [UIView setAnimationsEnabled:NO];
            window.rootViewController = newRoot;
            [window makeKeyAndVisible];
            [UIView setAnimationsEnabled:old];
        } completion:nil];
    });
}

- (UIWindow *)keyWindow
{
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        if (window.isKeyWindow) {
            return window;
        }
    }
    return UIApplication.sharedApplication.windows.firstObject;
}

- (UIViewController *)buildRootController
{
    return [[PPRootTabBarController alloc] init];
}

#pragma mark - Navigation Guard

- (BOOL)navigationShouldPopOnBackButton
{
    if (!self.showingSave) {
        return YES;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"Confirm")
                                                                   message:kLang(@"changes_not_saved")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Discard")
                                              style:UIAlertActionStyleDestructive
                                            handler:^(__unused UIAlertAction *action) {
        self.showingSave = NO;
        [self.navigationController popViewControllerAnimated:YES];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
    return NO;
}

- (void)onBack
{
    if (self.showingSave) {
        [PPAlertHelper showConfirmationIn:self
                                    title:kLang(@"unsaved_changes_title")
                                 subtitle:kLang(@"unsaved_changes_message")
                            confirmButton:kLang(@"leave_button")
                             cancelButton:kLang(@"stay_button")
                                     icon:nil
                              confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
            if (!didConfirm) {
                return;
            }
            [super onBack];
        } cancelBlock:nil];
        return;
    }

    [super onBack];
}

#pragma mark - Helpers

- (NSString *)pp_trimmedString:(id)value
{
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (BOOL)pp_isValidEmail:(NSString *)email
{
    if (email.length == 0) {
        return YES;
    }
    NSString *pattern = @"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES[c] %@", pattern];
    return [predicate evaluateWithObject:email];
}

- (NSString *)pp_digitsOnlyString:(NSString *)value
{
    NSString *raw = [self pp_trimmedString:value];
    if (raw.length == 0) {
        return @"";
    }

    NSMutableString *digits = [NSMutableString string];
    NSCharacterSet *digitSet = NSCharacterSet.decimalDigitCharacterSet;
    for (NSUInteger i = 0; i < raw.length; i++) {
        unichar ch = [raw characterAtIndex:i];
        if (ch >= '0' && ch <= '9') {
            [digits appendFormat:@"%c", (char)ch];
            continue;
        }
        if (ch >= 0x0660 && ch <= 0x0669) {
            [digits appendFormat:@"%c", (char)('0' + (ch - 0x0660))];
            continue;
        }
        if (ch >= 0x06F0 && ch <= 0x06F9) {
            [digits appendFormat:@"%c", (char)('0' + (ch - 0x06F0))];
            continue;
        }
        if (ch >= 0xFF10 && ch <= 0xFF19) {
            [digits appendFormat:@"%c", (char)('0' + (ch - 0xFF10))];
            continue;
        }
        if ([digitSet characterIsMember:ch]) {
            NSString *scalar = [NSString stringWithCharacters:&ch length:1];
            NSInteger numeric = [scalar integerValue];
            if (numeric >= 0 && numeric <= 9) {
                [digits appendFormat:@"%ld", (long)numeric];
            }
        }
    }
    return digits;
}

- (CountryCodeModel *)pp_countryFromStoredMobileNumber:(NSString *)mobile
{
    NSString *trimmed = [self pp_trimmedString:mobile];
    if (trimmed.length == 0 || ![trimmed hasPrefix:@"+"]) {
        return nil;
    }

    CountryCodeModel *best = nil;
    NSUInteger bestLength = 0;
    for (CountryCodeModel *candidate in self.contriesArray ?: @[]) {
        NSString *dial = [self pp_trimmedString:candidate.phoneCode];
        if (dial.length == 0 || ![dial hasPrefix:@"+"]) {
            continue;
        }
        if ([trimmed hasPrefix:dial] && dial.length > bestLength) {
            best = candidate;
            bestLength = dial.length;
        }
    }
    return best;
}

- (CountryCodeModel *)pp_countryWithISOCode:(NSString *)isoCode
{
    NSString *trimmedISO = [[self pp_trimmedString:isoCode] uppercaseString];
    if (trimmedISO.length != 2) {
        return nil;
    }

    for (CountryCodeModel *candidate in self.contriesArray ?: @[]) {
        NSString *candidateISO = [[self pp_trimmedString:candidate.isoCountryCode] uppercaseString];
        if ([candidateISO isEqualToString:trimmedISO]) {
            return candidate;
        }
    }
    return nil;
}

- (CountryCodeModel *)pp_qatarCountry
{
    CountryCodeModel *qatar = [self pp_countryWithISOCode:@"QA"];
    return qatar ?: self.contriesArray.firstObject;
}

- (NSString *)pp_localPhonePartFromE164:(NSString *)mobile dialCode:(NSString *)dialCode
{
    NSString *trimmedMobile = [self pp_trimmedString:mobile];
    NSString *trimmedDialCode = [self pp_trimmedString:dialCode];
    if (trimmedMobile.length == 0 || trimmedDialCode.length == 0) {
        return trimmedMobile;
    }

    NSString *dialDigits = [trimmedDialCode stringByReplacingOccurrencesOfString:@"+" withString:@""];
    NSString *mobileDigits = [[trimmedMobile stringByReplacingOccurrencesOfString:@"+" withString:@""]
        stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (dialDigits.length > 0 && [mobileDigits hasPrefix:dialDigits]) {
        return [mobileDigits substringFromIndex:dialDigits.length];
    }
    return trimmedMobile;
}

- (NSString *)pp_normalizedE164FromInput:(id)input dialCode:(NSString *)dialCode
{
    NSString *raw = [self pp_trimmedString:input];
    if (raw.length == 0) {
        return @"";
    }

    NSString *digits = [self pp_digitsOnlyString:raw];
    if (digits.length == 0) {
        return @"";
    }

    NSString *dialDigits = [[self pp_trimmedString:dialCode] stringByReplacingOccurrencesOfString:@"+" withString:@""];
    if (dialDigits.length > 0) {
        if ([digits hasPrefix:dialDigits] || [raw hasPrefix:@"+"]) {
            return [NSString stringWithFormat:@"+%@", digits];
        }
        return [NSString stringWithFormat:@"+%@%@", dialDigits, digits];
    }
    return [NSString stringWithFormat:@"+%@", digits];
}

- (BOOL)pp_authUser:(FIRUser *)authUser hasProviderID:(NSString *)providerID
{
    NSString *targetProviderID = [[self pp_trimmedString:providerID] lowercaseString];
    if (!authUser || targetProviderID.length == 0) {
        return NO;
    }

    for (id<FIRUserInfo>provider in authUser.providerData) {
        NSString *candidate = [[self pp_trimmedString:provider.providerID] lowercaseString];
        if ([candidate isEqualToString:targetProviderID]) {
            return YES;
        }
    }
    return NO;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (![self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        return;
    }

    [self pp_applyProfileCanvasBackground];

    UITraitCollection *tc = self.traitCollection;
    BOOL isDark = (tc.userInterfaceStyle == UIUserInterfaceStyleDark);

    // Avatar border
    UIColor *avatarBorderDyn = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        CGFloat a = (t.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.86 * 0.18 : 0.86;
        return [[UIColor whiteColor] colorWithAlphaComponent:a];
    }];
    [self.avatarIMV pp_setBorderColor:avatarBorderDyn];

    // Header card border + shadow
    UIColor *headerCardBorderDyn = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        CGFloat a = (t.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.68 * 0.18 : 0.68;
        return [[UIColor whiteColor] colorWithAlphaComponent:a];
    }];
    [self.headerCardView pp_setBorderColor:headerCardBorderDyn];
    self.headerCardView.layer.shadowOpacity = isDark ? 0.03 : 0.08;

    // Add-photo button
    UIColor *photoBorderDyn = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        CGFloat a = (t.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.18 : 1.0;
        return [[UIColor whiteColor] colorWithAlphaComponent:a];
    }];
    [self.addPhotoBtn pp_setBorderColor:photoBorderDyn];

    // Backdrop glows
    [self.backgroundGlowViewTop pp_setShadowColor:[UIColor colorWithRed:0.98 green:0.82 blue:0.60 alpha:1.0]];
    [self.backgroundGlowViewBottom pp_setShadowColor:[UIColor colorWithRed:0.68 green:0.27 blue:0.33 alpha:1.0]];

    // Refresh cell layer CGColors
    for (UITableViewCell *cell in self.tableView.visibleCells) {
        [cell.contentView pp_setBorderColor:[self pp_profileSurfaceBorderColor]];
        cell.layer.shadowOpacity = isDark ? 0.02 : 0.05;
    }
}

@end
/*
 .05;
     }
 }

 @end

 */
