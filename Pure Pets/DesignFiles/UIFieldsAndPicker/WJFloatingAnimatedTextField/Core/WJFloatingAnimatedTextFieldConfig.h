//
//  WJFloatingAnimatedTextFieldConfig.h
//  WJFloatingAnimatedTextField
//
//  Created by VanJay on 2019/4/12.
//  Copyright © 2019 VanJay. All rights reserved.
//




UIKIT_EXTERN NSString *_Nonnull const kCharacterSetStringNumber;
UIKIT_EXTERN NSString *_Nonnull const kCharacterSetStringNumberAndLetter;

typedef void (^EventCallBackBlock)(void);

NS_ASSUME_NONNULL_BEGIN

@interface WJFloatingAnimatedTextFieldConfig : NSObject
@property (nonatomic, copy) NSString *placeholder; ///< Placeholder text
@property (nonatomic, copy) NSString *floatingText; ///< Floating text
@property (nonatomic, strong) NSAttributedString *attributedPlaceholder; ///< Placeholder attribute text
@property (nonatomic, strong) UIColor *textColor; ///< Input box text color
@property (nonatomic, strong) UIColor *placeholderColor; ///< Placeholder text color
@property (nonatomic, strong) UIColor *floatingLabelColor; ///< Floating text color
@property (nonatomic, strong) UIImage *leftIconImage; ///< Left icon image, UIImage for external input without restriction
@property (nonatomic, strong) UIImage *rightIconImage; ///< Right icon image, UIImage for external input without restriction
@property (nonatomic, copy) NSString *leftLabelString; ///< Left Label
@property (nonatomic, copy) NSString *rightLabelString; ///< Right Label
@property (nonatomic, assign) UIEdgeInsets leftViewEdgeInsets; ///< Left View inner margin
@property (nonatomic, assign) UIEdgeInsets rightViewEdgeInsets; ///< Right View inner margin
@property (nonatomic, assign) UIEdgeInsets placeholderEdgeInsets; ///< Placeholder text inner margin
@property (nonatomic, strong) UIColor *bottomLineNormalColor; ///< Bottom line default state color
@property (nonatomic, strong) UIColor *bottomLineSelectedColor; ///< Bottom line selected state color
@property (nonatomic, strong) UIColor *leftLabelColor; ///< Left text color
@property (nonatomic, strong) UIColor *rightLabelColor; ///< Right text color
@property (nonatomic, strong) UIFont *leftLabelFont; ///< Left text font
@property (nonatomic, strong) UIFont *rightLabelFont; ///< Right text font
@property (nonatomic, strong) UIFont *font; ///< Input box font
@property (nonatomic, strong) UIFont *placeholderFont; ///< Placeholder text default font
@property (nonatomic, strong) UIFont *floatingLabelFont; ///< Placeholder text selected font
@property (nonatomic, assign) CGFloat bottomLineNormalHeight; ///< Bottom line default height
@property (nonatomic, assign) CGFloat bottomLineSelectedHeight; ///< Bottom line selected height
@property (nonatomic, assign) float textFieldHeightRateExceptMargin; ///< The ratio of the input box to the remaining height except the fixed spacing
@property (nonatomic, assign) CGFloat marginFloatingLabelToTextField; ///< The vertical spacing between the floating text and the input box
@property (nonatomic, assign) CGFloat marginBottomLineToTextField; ///< The vertical spacing between the line and the input box
@property (nonatomic, assign) NSTimeInterval animationDuration; ///< Animation duration
@property (nonatomic, assign) BOOL needShowOrHideRightViewAnimation; ///< Whether animation is needed to show\hide the right side
@property (nonatomic, assign) BOOL hideRightViewWhenEditing; ///< Whether to hide the view on the right side when editing, the default is NO
@property (nonatomic, assign) BOOL hideLeftViewWhenEmptyInputUnFoucused; ///< Whether to hide the view on the left when the input is empty and the input focus is not obtained, the default is NO
@property (nonatomic, assign) NSInteger maxInputLength; ///< Maximum input length, the default is 0, no limit
@property (nonatomic, assign) BOOL shouldLimitInputLength; ///< Whether to limit the input length, the default is enabled
@property (nonatomic, copy) NSString *characterSetString; ///< Limit the input characters
@property (nonatomic, assign) double maxInputNumber; ///< Maximum input number, if the input exceeds this number, and the input content is allowed to be modified to the maximum input number, the input box content will be automatically modified to the maximum number, the default is 0, no limit
@property (nonatomic, assign) BOOL allowModifyInputToMaxInputNumber; ///< Whether to allow the input content to be modified to the maximum input number, the default is NO
@property (nonatomic, assign) NSInteger maxDecimalsCount; ///< Maximum number of decimal places, default is 0, unlimited
@property (nonatomic, assign) BOOL shouldAppendDecimalAfterEndEditing; ///< Whether to automatically fill in the decimal places after editing (fill according to the maximum number of decimal places), default is off
@property (nonatomic, assign) BOOL shouldRemoveDecimalAfterBeginEditing; ///< Whether to automatically remove decimal places after editing starts, default is off, if the input set is allowed to not contain decimal points, it will also be removed
@property (nonatomic, assign) BOOL shouldSeparatedTextWithSymbol; ///< Whether to separate characters according to the specified separator, default is NO
@property (nonatomic, copy) NSString *separatedFormat; ///< Separation format, such as xxxx-xxxx-xxxx, xx-xxx-xxxx
@property (nonatomic, copy) NSString *separatedSymbol; ///< Separator, such as space |, etc., supports length not 1, default is one space
@property (nonatomic, assign) UITextFieldViewMode clearButtonMode; ///< Clear button mode, default UITextFieldViewModeWhileEditing
@property (nonatomic, assign) UIKeyboardType keyboardType; ///< Keyboard type, default number
@property (nonatomic, assign) BOOL secureTextEntry; ///< Whether to input safely, default NO
@property (nonatomic, copy) EventCallBackBlock updatePropertyBlock; ///< Need to update properties
@property (nonatomic, copy) EventCallBackBlock updateConstraintBlock; ///< Need to update layout
@property (nonatomic, copy) EventCallBackBlock showRightViewBlock; ///< Need to show the right View

+ (instancetype)defaultConfig;
@end

NS_ASSUME_NONNULL_END
