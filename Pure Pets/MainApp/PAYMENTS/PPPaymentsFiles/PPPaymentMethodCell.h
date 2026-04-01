//
//  iPPPaymentMethodCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 03/02/2026.
//

@class PPPaymentMethodCell;
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
@property (nonatomic, strong) NSIndexPath *indexPath;
@property (nonatomic, assign) BOOL isSelectedForUse;   // Temporary selection
@property (nonatomic, assign) BOOL isDefault;          // Permanent default

 
@property (nonatomic, assign, getter=isDefaultSelected) BOOL defaultSelected;
- (void)updateSelectionState:(BOOL)isSelected animated:(BOOL)animated;
@property (nonatomic, assign) BOOL isSeleted;
@property (nonatomic, strong) UIImageView *checkmarkView;
@property (nonatomic, strong) CALayer *selectionBorder;
- (void)configureWithInstrument:(UserPaymentInstrument *)instrument method:(PaymentMethod *)method indexPath:(NSIndexPath *)indexPath;
- (void)configureAsAddNewIndexPath:(NSIndexPath *)indexPath;
@property (nonatomic, weak) id <PPPaymentMethodCellDelegate> delegate;
@property (nonatomic, strong) UserPaymentInstrument* instrument;
@property (nonatomic, strong) PaymentMethod *method;

//@property (nonatomic, strong) UILabel *defaultBadge;

@end
