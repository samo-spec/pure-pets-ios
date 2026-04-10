//
//  PPSelectPaymentVC.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/11/2025.
//

#import <UIKit/UIKit.h>
#import "XLForm.h"

NS_ASSUME_NONNULL_BEGIN

@interface PPSelectPaymentVC : XLFormViewController

- (void)fetchUserPaymentInstruments;
- (void)showPaymentSheetFull:(BOOL)showFull;

@end

NS_ASSUME_NONNULL_END
