#import "PPSelectPaymentVC.h"
#import "PPPaymentFormViewController.h"
#import "PPPaymentMethodCell.h"
#import "BBCheckoutSummaryView.h"

NS_ASSUME_NONNULL_BEGIN

@class UserPaymentInstrument;
@class UserPaymentInstrumentManager;
@class PaymentMethod;

@interface PPSelectPaymentVC ()

@property (nonatomic, strong, nullable) PPPaymentFormViewController *paymentFormVC;
@property (nonatomic, strong) NSArray<PaymentMethod *> *availableMethods;
@property (nonatomic, strong) BBCheckoutSummaryView *summaryView;
@property (nonatomic, strong) UICollectionView *paymentCollection;
@property (nonatomic, strong) UserPaymentInstrumentManager *instrumentManager;
@property (nonatomic, strong) NSArray<UserPaymentInstrument *> *userInstruments;

@end

@interface PPPaymentSectionHeaderView : UICollectionReusableView

@property (nonatomic, copy, nullable) void (^actionHandler)(void);
- (void)configureWithTitle:(NSString *)title
                  subtitle:(nullable NSString *)subtitle
               actionTitle:(nullable NSString *)actionTitle;

@end

@interface PPSelectPaymentVC (PPPaymentHelper) <UICollectionViewDelegate, UICollectionViewDataSource, UISheetPresentationControllerDelegate, PaymentHeightDelegate, PPPaymentMethodCellDelegate>

- (void)setSummuryViewAtBottom;
- (PaymentMethod *)method:(NSString *)title icon:(NSString *)icon color:(UIColor *)color;
- (void)onSelectPayment:(UIButton *)sender;
- (void)pp_applyDefaultSelectionIfNeeded;
- (NSArray<UserPaymentInstrument *> *)pp_displayedInstruments;
- (nullable UserPaymentInstrument *)pp_resolvedSelectedInstrument;
- (NSString *)pp_selectedCheckoutPaymentMethodID;
- (void)pp_refreshCheckoutCallToAction;

@end

NS_ASSUME_NONNULL_END
