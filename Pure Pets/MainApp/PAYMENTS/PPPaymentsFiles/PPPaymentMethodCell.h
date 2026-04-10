//
//  PPPaymentMethodCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 03/02/2026.
//

@class PPPaymentMethodCell;
@class UserPaymentInstrument;
@class PaymentMethod;

@protocol PPPaymentMethodCellDelegate <NSObject>
@optional
- (void)paymentMethodCellDidSelect:(PPPaymentMethodCell *)cell instrument:(UserPaymentInstrument *)instrument method:(PaymentMethod *)method;
- (void)paymentMethodCellDidRequestEdit:(PPPaymentMethodCell *)cell instrument:(UserPaymentInstrument *)instrument method:(PaymentMethod *)method;
- (void)paymentMethodCellDidRequestDelete:(PPPaymentMethodCell *)cell instrument:(UserPaymentInstrument *)instrument method:(PaymentMethod *)method;
- (void)paymentMethodCellDidRequestDefault:(PPPaymentMethodCell *)cell instrument:(UserPaymentInstrument *)instrument method:(PaymentMethod *)method;
- (void)showPaymentSheetFull:(BOOL)showFull;
- (void)paymentMethodCellDidSelectForUse:(PPPaymentMethodCell *)cell
                               instrument:(UserPaymentInstrument *)instrument
                                   method:(PaymentMethod *)method;
@end

@interface PPPaymentMethodCell : UICollectionViewCell

@property (nonatomic, weak) id<PPPaymentMethodCellDelegate> delegate;
@property (nonatomic, strong, nullable) NSIndexPath *indexPath;
@property (nonatomic, strong, nullable) UserPaymentInstrument *instrument;
@property (nonatomic, strong, nullable) PaymentMethod *method;

- (void)configureWithInstrument:(UserPaymentInstrument *)instrument
                         method:(PaymentMethod *)method
                      indexPath:(NSIndexPath *)indexPath;
- (void)configureAsAddNewIndexPath:(NSIndexPath *)indexPath;
- (void)updateSelectionState:(BOOL)isSelected animated:(BOOL)animated;

@end
