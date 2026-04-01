//
//  XLForm.h
//  XLForm ( https://github.com/xmartlabs/XLForm )
//
//  Copyright (c) 2015 Xmartlabs ( http://xmartlabs.com )
//
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.



//Descriptors
#import "XLFormDescriptor.h"
#import "XLFormRowDescriptor.h"
#import "XLFormSectionDescriptor.h"

// Categories
#import "NSArray+XLFormAdditions.h"
#import "NSExpression+XLFormAdditions.h"
#import "NSObject+XLFormAdditions.h"
#import "NSPredicate+XLFormAdditions.h"
#import "NSString+XLFormAdditions.h"
#import "UIView+XLFormAdditions.h"

//helpers
#import "XLFormOptionsObject.h"

//Controllers
#import "XLFormOptionsViewController.h"
#import "XLFormViewController.h"

//Protocols
#import "XLFormDescriptorCell.h"
#import "XLFormInlineRowDescriptorCell.h"
#import "XLFormRowDescriptorViewController.h"

//Cells
#import "XLFormBaseCell.h"
#import "XLFormButtonCell.h"
#import "XLFormCheckCell.h"
#import "XLFormDateCell.h"
#import "XLFormDatePickerCell.h"
#import "XLFormInlineSelectorCell.h"
#import "XLFormLeftRightSelectorCell.h"
#import "XLFormPickerCell.h"
#import "XLFormRightDetailCell.h"
#import "XLFormRightImageButton.h"
#import "XLFormSegmentedCell.h"
#import "XLFormSelectorCell.h"
#import "XLFormSliderCell.h"
#import "XLFormStepCounterCell.h"
#import "XLFormSwitchCell.h"
#import "XLFormTextFieldCell.h"
#import "XLFormTextViewCell.h"
#import "XLFormImageCell.h"
#import "XLFormCustomCell.h"
#import "StepperFormCell.h"
#import "HXPhotosFormCell.h"


//Validation
#import "XLFormRegexValidator.h"

extern NSString *const XLFormRowPPLeftRight;
extern NSString *const XLFormRowDescriptorTypeHXPhotos;
extern NSString *const XLFormRowDescriptorTypeAccount;
extern NSString *const XLFormRowDescriptorTypeBooleanCheck;
extern NSString *const XLFormRowDescriptorTypeBooleanSwitch;
extern NSString *const XLFormRowDescriptorTypeButton;
extern NSString *const XLFormRowDescriptorTypeCountDownTimer;
extern NSString *const XLFormRowDescriptorTypeCountDownTimerInline;
extern NSString *const XLFormRowDescriptorTypeDate;
extern NSString *const XLFormRowDescriptorTypeDateInline;
extern NSString *const XLFormRowDescriptorTypeDatePicker;
extern NSString *const XLFormRowDescriptorTypeDateTime;
extern NSString *const XLFormRowDescriptorTypeDateTimeInline;
extern NSString *const XLFormRowDescriptorTypeDecimal;
extern NSString *const XLFormRowDescriptorTypeEmail;
extern NSString *const XLFormRowDescriptorTypeImage;
extern NSString *const XLFormRowDescriptorTypeHXPhoto;
extern NSString *const XLFormRowDescriptorTypeInfo;
extern NSString *const XLFormRowDescriptorTypeInteger;
extern NSString *const XLFormRowDescriptorTypeMultipleSelector;
extern NSString *const XLFormRowDescriptorTypeMultipleSelectorPopover;
extern NSString *const XLFormRowDescriptorTypeName;
extern NSString *const XLFormRowDescriptorTypeNumber;
extern NSString *const XLFormRowDescriptorTypePassword;
extern NSString *const XLFormRowDescriptorTypePhone;
extern NSString *const XLFormRowDescriptorTypePicker;
extern NSString *const XLFormRowDescriptorTypeSelectorActionSheet;
extern NSString *const XLFormRowDescriptorTypeSelectorAlertView;
extern NSString *const XLFormRowDescriptorTypeSelectorLeftRight;
extern NSString *const XLFormRowDescriptorTypeSelectorPickerView;
extern NSString *const XLFormRowDescriptorTypeSelectorPickerViewInline;
extern NSString *const XLFormRowDescriptorTypeSelectorPopover;
extern NSString *const XLFormRowDescriptorTypeSelectorPush;
extern NSString *const XLFormRowDescriptorTypeSelectorSegmentedControl;
extern NSString *const XLFormRowDescriptorTypeSlider;
extern NSString *const XLFormRowDescriptorTypeStepCounter;
extern NSString *const XLFormRowDescriptorTypeText;
extern NSString *const XLFormRowDescriptorTypeTextView;
extern NSString *const XLFormRowDescriptorTypeTime;
extern NSString *const XLFormRowDescriptorTypeTimeInline;
extern NSString *const XLFormRowDescriptorTypeTwitter;
extern NSString *const XLFormRowDescriptorTypeURL;
extern NSString *const XLFormRowDescriptorTypeZipCode;
extern NSString *const XLFormRowDescriptorTypeCustomButton;


#define Jh_SetValueAndDefault(value,defaultValue) (value ?: defaultValue)

 /// Form Cell, height of image
 #define Jh_OnePhotoViewWidth (Jh_ScreenWidth-Jh_ImageLeftMargin-Jh_ImageRightMargin-(Jh_ImageOneLineCount-1)*Jh_ImageMargin)
 /// Form Cell, height of image
 #define Jh_ImageHeight (Jh_OnePhotoViewWidth)/Jh_ImageOneLineCount

 /// Form Cell, select picture, left spacing, default 15
 UIKIT_EXTERN NSUInteger const Jh_ImageLeftMargin;
 /// Form Cell, select picture, right spacing, default 15
 UIKIT_EXTERN NSUInteger const Jh_ImageRightMargin;
 /// Form Cell, select picture, picture spacing, default 3
 UIKIT_EXTERN NSUInteger const Jh_ImageMargin;
 /// Form Cell, select pictures, several pictures in one line, default 4 pictures

/// Form Cell, select picture, photo top and bottom spacing, default 10
UIKIT_EXTERN NSUInteger const Jh_OnePhotoViewTopMargin;

/// Form Cell, select the number of image attachments, the default is 8
 UIKIT_EXTERN NSUInteger const Jh_GlobalMaxImages;
 /// Form Cell, select picture and add icon
 UIKIT_EXTERN NSString *const Jh_AddIcon;

 ///// Form Cell, select image, failed to load placeholder image, not used
 //UIKIT_EXTERN NSString *const Jh_PlaceholderImage;
 ///// Form Cell, select picture, delete icon, not used
 //UIKIT_EXTERN NSString *const Jh_DeleteIcon;


#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending


