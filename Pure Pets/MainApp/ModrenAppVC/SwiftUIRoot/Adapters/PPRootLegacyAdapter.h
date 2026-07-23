//
//  PPRootLegacyAdapter.h
//  Pure Pets
//
//  Typed Objective-C adapter wrapping legacy manager singletons
//  and PPRootTabBarController private selectors.
//
//  Swift imports ONLY this header via the bridging header.
//  This file imports the actual ObjC headers internally (.m).
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPRootLegacyAdapter : NSObject

#pragma mark - Session State (UserManager)

+ (BOOL)isUserLoggedIn;
+ (BOOL)isCurrentUserBlocked;
+ (BOOL)isCurrentUserEffectivelyBlocked;
+ (nullable NSString *)currentUserDisplayName;
+ (nullable NSURL *)currentUserImageURL;

#pragma mark - Cart State (CartManager)

+ (NSInteger)cartTotalItemsCount;
+ (double)cartTotalAmount;

#pragma mark - Unread Counts (ChManager)

+ (NSInteger)totalUnreadChatsCount;

#pragma mark - Bottom Surface (PPBottomSurfaceCoordinator)

+ (void)applySurfaceForController:(nullable UIViewController *)controller
                         animated:(BOOL)animated;

#pragma mark - Root Controller Actions (PPRootTabBarController)

/// Presents the create-option bottom sheet.
/// Falls back silently if the selector is unavailable.
+ (void)presentBottomSheetOn:(UITabBarController *)controller;

/// Opens the Nova chat interface.
+ (void)novaButtonTappedOn:(UITabBarController *)controller;

/// Opens the search experience from the current visible context.
+ (void)openSearchExperienceOn:(UITabBarController *)controller
            openingAccessories:(BOOL)openAccessories;

/// Opens a specific chat thread from a push notification.
+ (BOOL)openChatThreadOn:(UITabBarController *)controller
                  thread:(id)thread
                animated:(BOOL)animated;

/// Triggers the blocked-account customer-support action.
+ (void)blockedContactSupportTappedOn:(UITabBarController *)controller;

/// Triggers the blocked-account sign-out action.
+ (void)blockedSignOutTappedOn:(UITabBarController *)controller;

/// Shows the intro/onboarding flow if the user has not seen it.
+ (void)showIntroIfNeededOn:(UITabBarController *)controller;

/// Applies bottom-navigation clearance to visible scroll views.
+ (void)applyBottomNavigationClearanceOn:(UITabBarController *)controller;

@end

NS_ASSUME_NONNULL_END
