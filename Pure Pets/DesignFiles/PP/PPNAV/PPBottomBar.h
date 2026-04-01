//
//  PPPaymentTabBar.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/11/2025.
//


#import <UIKit/UIKit.h>
#import "CartItem.h"
#import "PPInsetLabel.h"
#import "FavoriteButton.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPPaymentTab) {
    PPPaymentTabCard = 0,
    PPPaymentTabOoredooMoney,
    PPPaymentTabPayPal,
    PPPaymentTabFawry,
    PPPaymentTabQNB,
    PPPaymentTabCash
};



typedef NS_ENUM(NSInteger, PPBarTag) {
    PPBarTagHome = 0,
    PPBarTagCart,
    PPBarTagOrdersHistory,
    PPBarTagChats,
    PPBarTagNotifications,
    PPBarTagNewAd,
    PPBarTagSearch
};



typedef NS_ENUM(NSInteger, TabBarState) {
    TabBarStateExpanded,   // full height + titles
    TabBarStateHidden      // fully hidden
};



typedef void(^PPPaymentTabSelectionBlock)(PPPaymentTab selectedTab);

@interface PPPaymentTabBar : UIView
@property (nonatomic, copy) PPPaymentTabSelectionBlock onSelect;
@property (nonatomic, assign, readonly) PPPaymentTab selectedTab;

/// Programmatically update the selected tab
- (void)setSelectedTab:(PPPaymentTab)tab animated:(BOOL)animated;
@end




 


@interface BBCartBottomBar : UIView
@property (nonatomic, strong, readonly) UIButton *totalContainer;
@property (nonatomic, strong, readonly) UIButton *qtyContainer;
@property (nonatomic, strong, readonly) UIButton *minusButton;
@property (nonatomic, strong, readonly) UILabel *countLabel;
@property (nonatomic, strong, readonly) UIButton *plusButton;
@property (nonatomic, strong, readonly) PPInsetLabel *totalLabel;
@property (nonatomic, strong, readonly) PPInsetLabel *currencyLabel;
@property (nonatomic, strong, readonly) PPInsetLabel *amountLabel;
@property (nonatomic, strong, readonly) UIButton *addToCartButton;
@property (nonatomic, strong, readonly) UIStackView *qtyStack;

@property (nonatomic, assign) NSInteger cartItemquantity;
@property (nonatomic, assign) CGFloat totalAmount;
@property (nonatomic, assign) CGFloat itemAmount;

- (void)setInitItemAmount:(CGFloat)amount;
/// Called when user taps the add to cart button
@property (nonatomic, copy, nullable) void (^onAddToCart)(NSInteger quantity);

/// Called when quantity changes
@property (nonatomic, copy, nullable) void (^onQuantityChanged)(NSInteger quantity);

- (void)setTotalAmount:(CGFloat)totalAmount;

- (void)updateQuantityUI;

-(void)setFavForCollection:(NSString *)collection andID:(NSString *)ID andButton:(FavoriteFixedSizeButton *)favButton;
@property (nonatomic, strong) UIButton *favButton;

@end




@interface PPNewBottomBar : UIView
@property (nonatomic, strong) NSLayoutConstraint *tabBarHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *tabBarTralinfConstraint;
@property (nonatomic) TabBarState tabBarState;
@property (nonatomic, strong) NSArray<UIButton *> *tabButtons;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UIButton *searchButton;
@property (nonatomic, strong) UIButton *cartButton;
@property (nonatomic, assign) BOOL hideTitles; // defaults to NO

@property (nonatomic, strong) UITabBarItem *lastSelectedBarItem;
@property (nonatomic, copy) void (^onButtonTapped)(NSInteger index,UIButton *button);
@property (nonatomic, copy) void (^onTabBarTapped)(PPBarTag barTag,
                                                   UIBarItem *barItem);
@property (nonatomic, copy) void (^onSearchTapped)(void);
// PPTabBarController.m
@property (nonatomic, strong) UITabBar *tabBar;
- (void)selectItemWithTag:(PPBarTag)tag animated:(BOOL)animated ;

- (void)deselectTabberItems;
- (void)setActionButtonHidden:(BOOL)hidden;
- (void)configureWithItems:(NSArray<NSDictionary *> *)items; // each: @{@"icon":@"folder", @"title":@"Files"}
@property (nonatomic, assign) float blurBarViewHeight;

- (UIButton *)getButtonAtIndex:(NSInteger)index;
- (void)setBadgeOnButtonAtIndex:(NSInteger)index
                          value:(NSString *)value
                   backgroundColor:(UIColor *)bgColor
                      borderColor:(UIColor *)borderColor;

- (void)configureTabBarItems:(NSArray<NSDictionary *> *)items;
- (void)removeBadgeAtIndex:(NSInteger)index;
 
- (void)setTabBarHidden:(BOOL)tabBarHidden;


@end

 
NS_ASSUME_NONNULL_END
