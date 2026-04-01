
#import "XLForm.h"
NS_ASSUME_NONNULL_BEGIN
extern NSString * const XLFormRowDescriptorTypeTwoOptions; // row type key
extern NSString * const XLFormRowDescriptorTypeTwoOptions;

@interface TwoOptionRowCell : XLFormBaseCell
@property (nonatomic, strong) NSMutableDictionary *options; // {"left":[], "right":[]}
- (void)reloadButtons;

@end

@interface ParrotSelectorFormViewController : XLFormViewController  @end

 

extern NSString * const XLFormRowFullWidthTitleSubtitleAndImage;


@interface XLFormRowFullWidthTitleSubtitleAndImageCell : XLFormBaseCell <UITextFieldDelegate>
@property (nonatomic, strong, nullable) UITextField *textField;
@property (nonatomic, strong, nullable) UILabel *titlelabel;
@property (nonatomic, strong, nullable) UILabel *subTitlelabel;
@property (nonatomic, strong, nullable) UIImage *iconImage;
@property (nonatomic, strong, nullable) UIButton *button;
 
@property (nonatomic, strong, nullable) NSString *subtitle;
@property (nonatomic, strong, nullable) NSString *icon;
 

-(BOOL)formDescriptorCellBecomeFirstResponder;
- (void)formDescriptorCellDidSelectedWithFormController:(XLFormViewController *)controller;
- (BOOL)becomeFirstResponder ;
@end



// Row type you’ll register/use
extern NSString * const XLFormRowDescriptorTypeFullWidthTextField;

typedef NS_ENUM(NSInteger, XLFormFullWidthTextFieldType) {
    XLFormFullWidthTextFieldTypeDefault,
    XLFormFullWidthTextFieldTypeEmail,
    XLFormFullWidthTextFieldTypeNumber,
    XLFormFullWidthTextFieldTypePassword,
    XLFormFullWidthTextFieldTypePhone,
    XLFormFullWidthTextFieldTypeButton,
    XLFormFullWidthTextFieldTypeTitleAndDetails
};


typedef NS_ENUM(NSInteger, XLFormFullWidthTextFieldTitlePos) {
    XLFormFullWidthTextFieldTitlePosDefault = 0,
    XLFormFullWidthTextFieldTitlePosTop     = 1,
    XLFormFullWidthTextFieldTitlePosCenter     = 2,
    XLFormFullWidthTextFieldTitleLeftRightText     = 3,
    XLFormFullWidthTextFieldFull = 4,
};


@interface XLFormRowFullWidthTextFieldCell : XLFormBaseCell <UITextFieldDelegate>


@property (nonatomic, assign) XLFormFullWidthTextFieldTitlePos TitlePos;

@property (nonatomic, assign) XLFormFullWidthTextFieldType inputType;
@property (nonatomic, assign) XLFormFullWidthTextFieldTitlePos titlePosition;
@property (nonatomic, strong, nullable) UITextField * textField;
@property (nonatomic, strong, nullable) UIButton *button;
@property (nonatomic, strong, nullable) UILabel * topField;

-(BOOL)formDescriptorCellBecomeFirstResponder;
- (void)formDescriptorCellDidSelectedWithFormController:(XLFormViewController *)controller;
- (BOOL)becomeFirstResponder ;
@end


extern NSString * const XLFormRowButtonKey;


@interface XLFormRowButton : XLFormBaseCell 
@property (nonatomic, strong, nullable) UIButton *button;
@property (nonatomic, assign) NSString *icon;
-(BOOL)formDescriptorCellBecomeFirstResponder;
- (void)formDescriptorCellDidSelectedWithFormController:(XLFormViewController *)controller;
 @end

NS_ASSUME_NONNULL_END
