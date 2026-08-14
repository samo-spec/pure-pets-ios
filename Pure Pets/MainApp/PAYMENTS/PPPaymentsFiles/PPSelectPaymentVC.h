//
//  PPSelectPaymentVC.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/11/2025.
//

#import <UIKit/UIKit.h>
#import "XLForm.h"

@class CartItem;

NS_ASSUME_NONNULL_BEGIN

@interface PPSelectPaymentVC : XLFormViewController

+ (BOOL)pushFromViewController:(UIViewController *)viewController;
+ (BOOL)pushFromViewController:(UIViewController *)viewController
                 checkoutItems:(NSArray<CartItem *> *)checkoutItems;
- (void)fetchUserPaymentInstruments;
- (void)showPaymentSheetFull:(BOOL)showFull;

@end

NS_ASSUME_NONNULL_END
