//
//  CartViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 29/06/2025.
//

#import "PPCartTableCell.h"

@protocol CartQuantityUpdateDelegate <NSObject>
-(void)loadItemsCountInBadge;
-(void)updateCartAndReloadCollection;
@end

@interface CartViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, weak) id <CartQuantityUpdateDelegate> delegate;
@end








#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPPaymentSheettHelper : NSObject

/// Presents a modern payment confirmation sheet.
/// - Parameters:
///   - vc: presenting controller
///   - methodName: selected payment method name
///   - confirm: called when Confirm is tapped
///   - cancel: called when Cancel is tapped
+ (void)showPaymentSheetIn:(UIViewController *)vc
             selectedMethod:(NSString *)methodName
                  onConfirm:(dispatch_block_t)confirm
                   onCancel:(dispatch_block_t)cancel;

@end

NS_ASSUME_NONNULL_END























//
//  PPBottomAlertSheet.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/11/2025.
//

#import <UIKit/UIKit.h>
#import "CartTableViewCell.h"
NS_ASSUME_NONNULL_BEGIN

typedef void(^PPBottomAlertActionBlock)(void);

@interface PPBottomAlertSheet : UIViewController

/// Title shown at the top of the sheet
@property (nonatomic, copy) NSString *sheetTitle;

/// Optional descriptive message
@property (nonatomic, copy) NSString *message;

/// Called when Confirm or Cancel are tapped
@property (nonatomic, copy) PPBottomAlertActionBlock onConfirm;
@property (nonatomic, copy) PPBottomAlertActionBlock onCancel;

/// Show the sheet in a given view controller
- (void)presentIn:(UIViewController *)parentVC;

@end

NS_ASSUME_NONNULL_END
