//
//  PPPaymentSelectionViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/11/2025.
//


//
//  PPPaymentSelectionViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/11/2025.
//

#import <UIKit/UIKit.h>
#import "XLForm.h"
#import "BBCheckoutSummaryView.h"


NS_ASSUME_NONNULL_BEGIN

@class PPPaymentFormViewController;
@class UserPaymentInstrumentManager;
@class UserPaymentInstrument;
@class BBCheckoutSummaryView;
@class PPDefaultLocationView;
@class PaymentMethod;
@class PPPaymentSectionHeaderView;
@class PaymentMethod;



@interface PPSelectPaymentVC : XLFormViewController
@property (nonatomic, strong, nullable) PPPaymentFormViewController *paymentFormVC;
@property (nonatomic, strong) PPPaymentSectionHeaderView *expandedSection;
@property (nonatomic, strong) NSArray<PaymentMethod *> *availableMethods;
@property (nonatomic, strong) BBCheckoutSummaryView *summaryView;


@property (nonatomic, strong) UICollectionView *paymentCollection;
@property (nonatomic, strong) UserPaymentInstrumentManager *instrumentManager;
- (void)setPaymentFormVC:(PPPaymentFormViewController *)paymentFormVC;
@property (nonatomic, strong) NSArray<UserPaymentInstrument *> *userInstruments;
- (void)fetchUserPaymentInstruments ;
@end

 

@interface PPPaymentSectionHeaderView : UICollectionReusableView
@property (nonatomic, strong) UILabel *titleLabel;
- (void)configureWithTitle:(NSString *)title;
@end

NS_ASSUME_NONNULL_END




