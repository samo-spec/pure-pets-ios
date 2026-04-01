//
//  XLFormRowDescriptor.h
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

#import "FileModel.h"

#import "XLFormBaseCell.h"
#import "XLFormValidatorProtocol.h"
#import "XLFormValidationStatus.h"

#define kHasHXPhotoPicker (__has_include(<HXPhotoPicker.h>) || __has_include("HXPhotoPicker.h"))

#if kHasHXPhotoPicker
#import "HXPhotoPicker.h"
#endif


#define Jh_ScreenWidth [UIScreen mainScreen].bounds.size.width - 34
#define Jh_ScreenHeight [UIScreen mainScreen].bounds.size.height - 34

NS_ASSUME_NONNULL_BEGIN


extern CGFloat XLFormUnspecifiedCellHeight;

@class XLFormViewController;
@class XLFormSectionDescriptor;
@protocol XLFormValidatorProtocol;
@class XLFormAction;
@class XLFormBaseCell;

typedef NS_ENUM(NSUInteger, XLFormPresentationMode) {
    XLFormPresentationModeDefault = 0,
    XLFormPresentationModePush,
    XLFormPresentationModePresent
};

/// Select image type
 typedef NS_ENUM(NSInteger, JhSelectImageType) {
     JhSelectImageTypeImage = 0, // picture
     JhSelectImageTypeVideo, // video
     JhSelectImageTypeAll, // pictures and videos
 };

typedef void(^XLOnChangeBlock)(id __nullable oldValue,id __nullable newValue,XLFormRowDescriptor* __nonnull rowDescriptor);

@interface XLFormRowDescriptor : NSObject


@property (nonatomic, strong, nullable) id cellClass;
@property (nonatomic, copy, nullable) NSString *tagM;
@property (nonatomic, assign) NSInteger selectedKind;
@property (nonatomic, assign) BOOL isStart;
@property (nonatomic, copy, nonnull, readonly) NSString *rowType;
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, strong, nullable) id value;


@property (strong,nonatomic,nullable) Class valueTransformer;
@property UITableViewCellStyle cellStyle;
@property (nonatomic) CGFloat height;
@property (copy, nullable) XLOnChangeBlock onChangeBlock;
@property BOOL useValueFormatterDuringInput;
@property (nonatomic,nullable,assign) NSFormatter *valueFormatter;

// returns the display text for the row descriptor, taking into account NSFormatters and default placeholder values
- (nonnull NSString *) displayTextValue;

// returns the editing text value for the row descriptor, taking into account NSFormatters.
- (nonnull NSString *) editTextValue;

@property (strong,nonatomic, nonnull) NSMutableDictionary * cellConfig;
@property (nonatomic, readonly, nonnull) NSMutableDictionary * cellConfigForSelector;
@property (nonatomic, readonly, nonnull) NSMutableDictionary * cellConfigIfDisabled;
@property (nonatomic, readonly, nonnull) NSMutableDictionary * cellConfigAtConfigure;

@property (assign,nonnull) id disabled;
-(BOOL)isDisabled;
@property (assign,nonnull) id hidden;
-(BOOL)isHidden;
@property (getter=isRequired) BOOL required;

@property (strong,nonatomic, nonnull) XLFormAction * action;

@property (weak, null_unspecified) XLFormSectionDescriptor * sectionDescriptor;

+(nonnull instancetype)formRowDescriptorWithTag:(nullable NSString *)tag rowType:(nonnull NSString *)rowType;
+(nonnull instancetype)formRowDescriptorWithTag:(nullable NSString *)tag rowType:(nonnull NSString *)rowType title:(nullable NSString *)title;
+(nonnull instancetype)formRowDescriptorWithTag:(nullable NSString *)tag rowType:(nonnull NSString *)rowType title:(nullable NSString *)title images:(nullable NSArray *)images;
-(nonnull instancetype)initWithTag:(nullable NSString *)tag rowType:(nonnull NSString *)rowType title:(nullable NSString *)title images:(nullable NSArray *)images;

-(nonnull XLFormBaseCell *)cellForFormController:(nonnull XLFormViewController *)formController;

@property (strong,nullable) NSString *requireMsg;
-(void)addValidator:(nonnull id<XLFormValidatorProtocol>)validator;
-(void)removeValidator:(nonnull id<XLFormValidatorProtocol>)validator;
-(nullable XLFormValidationStatus *)doValidation;

@property (nonatomic,   copy) void(^ _Nullable Jh_imageSelectBlock)(NSArray * _Nullable imageArr);
// ===========================
// property used for SelectImage
// ===========================
#pragma mark - SelectImage Cell

@property (nonatomic, strong) NSArray *__nullable Jh_imageArr;

 /** Filter out a subset of the array whose type is UIImage in the images array to implement image upload filtering */
 @property (nonatomic, strong) NSArray *__nullable Jh_selectImageArr;

 /** Image selection Cell, selected video array, NSURL format (this parameter takes effect when Jh_selectImageType == JhSelectImageTypeVideo) */
 @property (nonatomic, strong) NSArray *__nullable Jh_selectVideoArr;

#if kHasHXPhotoPicker

 /** Image selection Cell, model array of all types of resources */
 @property (nonatomic, strong) NSArray<HXPhotoModel *> *__nullable Jh_imageAllList;

 /** Image selection Cell, mixed resource array, used during initialization, can display online images or video resources (Jh_imageArr can also initialize network images, this parameter has a higher priority than Jh_imageArr) */
 @property (nonatomic, strong) NSArray *__nullable Jh_mixImageArr;
 #endif

 /// Clear all image and video data, default false
 @property (nonatomic, assign) BOOL Jh_isClearImage;


/** Whether to hide the add picture button, displayed by default */
 @property (nonatomic, assign) BOOL Jh_noShowAddImgBtn;

 /** Whether to hide the delete button in the upper right corner of the image, displayed by default */
 @property (nonatomic, assign) BOOL Jh_hideDeleteButton;

 /** Represents the maximum number of selected images in the JhFormCellTypeImage category, the default is 8 */
 @property (nonatomic, assign) NSUInteger Jh_maxImageCount;

/**
  Select the image type (only images are selected by default, you can set to select only videos, or select both)
 
  Only select images, use Jh_imageArr or J h_selectImageArr to obtain image resources
  To select only videos, use Jh_selectVideoArr to get the video URL link
  Select pictures and videos, use Jh_imageArr and Jh_selectVideoArr to obtain data respectively, or use Jh_imageAllList to customize all resources
  */
@property (nonatomic, assign) JhSelectImageType Jh_selectImageType;

 /** Whether the photos/videos taken are not saved to the system album, they are saved by default*/
 @property (nonatomic, assign) BOOL Jh_imageNoSaveAblum;

 /** Minimum number of seconds for camera video recording - default 3s */
 @property (nonatomic, assign) NSTimeInterval Jh_videoMinimumDuration;



// ===========================
// property used for Selectors
@property (nonatomic, copy, nullable) NSString *noValueDisplayText;
@property (nonatomic, copy, nullable) NSString *selectorTitle;
@property (nonatomic, copy, nullable) NSArray *selectorOptions;
@property (nonatomic, copy, nullable) NSString *selectorLeftSubKind;
@property (nonatomic, strong, null_unspecified) id leftRightSelectorLeftOptionSelected;


// =====================================
// Deprecated
// =====================================
@property (null_unspecified) Class buttonViewController DEPRECATED_ATTRIBUTE DEPRECATED_MSG_ATTRIBUTE("Use action.viewControllerClass instead");
@property XLFormPresentationMode buttonViewControllerPresentationMode DEPRECATED_ATTRIBUTE DEPRECATED_MSG_ATTRIBUTE("use action.viewControllerPresentationMode instead");
@property (null_unspecified) Class selectorControllerClass DEPRECATED_ATTRIBUTE DEPRECATED_MSG_ATTRIBUTE("Use action.viewControllerClass instead");


@end
NS_ASSUME_NONNULL_END









typedef NS_ENUM(NSUInteger, XLFormLeftRightSelectorOptionLeftValueChangePolicy)
{
    XLFormLeftRightSelectorOptionLeftValueChangePolicyNullifyRightValue = 0,
    XLFormLeftRightSelectorOptionLeftValueChangePolicyChooseFirstOption,
    XLFormLeftRightSelectorOptionLeftValueChangePolicyChooseLastOption
};

NS_ASSUME_NONNULL_BEGIN
// =====================================
// helper object used for LEFTRIGHTSelector Descriptor
// =====================================
@interface XLFormLeftRightSelectorOption : NSObject

@property (nonatomic, assign) XLFormLeftRightSelectorOptionLeftValueChangePolicy leftValueChangePolicy;
@property (assign, nonnull) id leftValue;
@property (assign, nonnull) NSArray *  rightOptions;
@property (readonly, null_unspecified) NSString * httpParameterKey;
@property (assign,nullable) Class rightSelectorControllerClass;

@property (nonatomic, copy, nullable)  NSString * noValueDisplayText;
@property (nonatomic, copy, nullable)  NSString * selectorTitle;


+(nonnull XLFormLeftRightSelectorOption *)formLeftRightSelectorOptionWithLeftValue:(nonnull id)leftValue
                                                          httpParameterKey:(null_unspecified NSString *)httpParameterKey
                                                              rightOptions:(nonnull NSArray *)rightOptions;

+ (nonnull instancetype)formOptionWithLeftValue:(nonnull id)leftValue rightOptions:(nonnull NSArray *)rightOptions;
+ (nonnull instancetype)formOptionWithLeftValue:(nonnull id)leftValue rightOptions:(nonnull NSArray *)rightOptions leftTitle:(NSArray *)leftTitle ;
@end
NS_ASSUME_NONNULL_END





NS_ASSUME_NONNULL_BEGIN
@protocol XLFormOptionObject
@required
-(nonnull NSString *)formDisplayText;
-(nonnull id)formValue;
@end
NS_ASSUME_NONNULL_END





NS_ASSUME_NONNULL_BEGIN
@interface XLFormAction : NSObject

@property (nullable, nonatomic, strong) Class viewControllerClass;
@property (nullable, nonatomic, strong) NSString * viewControllerStoryboardId;
@property (nullable, nonatomic, strong) NSString * viewControllerNibName;

@property (nonatomic) XLFormPresentationMode viewControllerPresentationMode;

@property (nullable, nonatomic, strong) void (^formBlock)(XLFormRowDescriptor * __nonnull sender);
@property (nullable, nonatomic) SEL formSelector;
@property (nullable, nonatomic, strong) NSString * formSegueIdenfifier DEPRECATED_ATTRIBUTE DEPRECATED_MSG_ATTRIBUTE("Use formSegueIdentifier instead");
@property (nullable, nonatomic, strong) NSString * formSegueIdentifier;
@property (nullable, nonatomic, strong) Class formSegueClass;

@end
NS_ASSUME_NONNULL_END
