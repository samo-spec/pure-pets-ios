#import "PPSelectPaymentVC.h"
#import "PPPaymentFormViewController.h"
#import "PPPaymentMethodCell.h"
 

NS_ASSUME_NONNULL_BEGIN

@class UserPaymentInstrument;
@class UserPaymentInstrumentManager;
@class PaymentMethod;
@class PPPaymentSectionHeaderView;

@interface PPSelectPaymentVC ()

@property (nonatomic, strong, nullable) PPPaymentFormViewController *paymentFormVC;
@property (nonatomic, strong) NSArray<PaymentMethod *> *availableMethods;
@property (nonatomic, strong) PPContextAwareCheckoutView *summaryView;
@property (nonatomic, strong) UICollectionView *paymentCollection;
@property (nonatomic, strong) UserPaymentInstrumentManager *instrumentManager;
@property (nonatomic, strong) NSArray<UserPaymentInstrument *> *userInstruments;
@property (nonatomic, assign) BOOL paymentSelectionWasExplicit;
@property (nonatomic, copy, nullable) NSString *initialPaymentSelectionID;

- (void)pp_configurePaymentHeader:(PPPaymentSectionHeaderView *)header;
- (CGFloat)pp_paymentHeaderHeightForWidth:(CGFloat)width;
- (void)pp_updateCheckoutReview;
- (BOOL)pp_checkoutInteractionLocked;
- (nullable NSString *)pp_checkoutRequiredActionTitle;

@end

@interface PPPaymentSectionHeaderView : UICollectionReusableView
@end

@interface PPSelectPaymentVC (PPPaymentHelper) <UICollectionViewDelegate,
                                                UICollectionViewDataSource,
                                                UICollectionViewDelegateFlowLayout,
                                                UISheetPresentationControllerDelegate,
                                                PaymentHeightDelegate,
                                                PPPaymentMethodCellDelegate>

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
