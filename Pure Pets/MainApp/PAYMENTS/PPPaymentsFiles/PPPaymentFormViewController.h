//
//  PPPaymentFormViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/11/2025.
//


//
//  PPPaymentFormViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/11/2025.
//




#import "PPAddressesManager.h"
#import "XLForm.h"


NS_ASSUME_NONNULL_BEGIN


@class XLFormSectionDescriptor;
@class UserPaymentInstrument;
@protocol PaymentHeightDelegate <NSObject>
- (void)updatePaymentHeight:(CGFloat)newHeight animated:(BOOL)animated;
- (void)expandToLargeDetent:(BOOL)animated;
 @end


typedef NS_ENUM(NSInteger, PPPaymentFormMode) {
    PPPaymentFormModeAdd,
    PPPaymentFormModeEdit
};


  
@interface PPPaymentFormViewController : XLFormViewController

- (instancetype)initForEditingInstrument:(UserPaymentInstrument *)instrument;
- (instancetype)initForAddingMethod:(PaymentMethod * _Nullable)method;

 @property (nonatomic, assign) PPPaymentFormMode mode;

@property (nonatomic, assign) BOOL isEditingExisting;
@property (nonatomic, strong) UserPaymentInstrument *editingInstrument;

@property (nonatomic,
           nullable,
           strong) XLFormSectionDescriptor *cardSection;
@property (nonatomic,
           nullable,
           strong) XLFormSectionDescriptor *ooredooSection;
@property (nonatomic,
           nullable,
           strong) XLFormSectionDescriptor *cashSection;
@property (nonatomic,
           nullable,
           strong) XLFormSectionDescriptor *QNBSection;
@property (nonatomic,
           nullable,
           strong) XLFormSectionDescriptor *fawrySection;
@property (nonatomic,
           nullable,
           strong) XLFormSectionDescriptor *build;
@property (nonatomic,
           nullable,
           strong) XLFormSectionDescriptor *lastSelectedSection;




@end

//
//  PPGlassHeaderView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/11/2025.
//

 
 
@interface PPGlassHeaderView : UIView

/// Title label displayed on the left
@property (nonatomic, strong, readonly) UILabel *titleLabel;

/// Cancel button displayed on the right
@property (nonatomic, strong, readonly) UIButton *cancelButton;

/// Initialize with title and cancel action
- (instancetype)initWithTitle:(NSString *)title
                cancelHandler:(void (^)(void))handler;

@end

NS_ASSUME_NONNULL_END
