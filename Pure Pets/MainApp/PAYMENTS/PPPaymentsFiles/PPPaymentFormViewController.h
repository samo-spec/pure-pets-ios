//
//  PPPaymentFormViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/11/2025.
//  Refactored: Removed XLForm, pure UIKit + modern design.
//

#import <UIKit/UIKit.h>
#import "PPAddressesManager.h"

NS_ASSUME_NONNULL_BEGIN

@class UserPaymentInstrument;

@protocol PaymentHeightDelegate <NSObject>
- (void)updatePaymentHeight:(CGFloat)newHeight animated:(BOOL)animated;
- (void)expandToLargeDetent:(BOOL)animated;
@end

typedef NS_ENUM(NSInteger, PPPaymentFormMode) {
    PPPaymentFormModeAdd,
    PPPaymentFormModeEdit
};

@interface PPPaymentFormViewController : UIViewController

- (instancetype)initForEditingInstrument:(UserPaymentInstrument *)instrument;
- (instancetype)initForAddingMethod:(PaymentMethod * _Nullable)method;

@property (nonatomic, assign) PPPaymentFormMode mode;
@property (nonatomic, assign) BOOL isEditingExisting;
@property (nonatomic, strong) UserPaymentInstrument *editingInstrument;

@end

@interface PPGlassHeaderView : UIView
@property (nonatomic, strong, readonly) UILabel *titleLabel;
@property (nonatomic, strong, readonly) UIButton *cancelButton;
- (instancetype)initWithTitle:(NSString *)title cancelHandler:(void (^)(void))handler;
@end

NS_ASSUME_NONNULL_END
