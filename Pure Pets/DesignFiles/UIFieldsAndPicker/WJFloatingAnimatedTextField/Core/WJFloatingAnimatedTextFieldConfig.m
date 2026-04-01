//
//  WJFloatingAnimatedTextFieldConfig.m
//  WJFloatingAnimatedTextField
//
//  Created by VanJay on 2019/4/12.
//  Copyright © 2019 VanJay. All rights reserved.
//

#import "WJFloatingAnimatedTextFieldConfig.h"
#import "WJDefine.h"

NSString *const kCharacterSetStringNumber = @"0123456789";
NSString *const kCharacterSetStringNumberAndLetter = @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

@implementation WJFloatingAnimatedTextFieldConfig
- (instancetype)init {
    self = [super init];
    if (self) {
        // default value
        self.placeholderColor = HexColor(0xadb6c8);
        self.floatingLabelColor = HexColor(0xadb6c8);
        self.leftViewEdgeInsets = UIEdgeInsetsMake(5, 0, 5, 10);
        self.rightViewEdgeInsets = UIEdgeInsetsMake(5, 10, 5, 0);
        self.placeholderEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 0);
        self.bottomLineNormalColor = HexColor(0xe4e5ea);
        self.bottomLineSelectedColor = HexColor(0xf83460);
        self.leftLabelColor = HexColor(0xadb6c8);
        self.rightLabelColor = HexColor(0xf83460);
        self.leftLabelFont = [GM MidFontWithSize:15];
        self.rightLabelFont =  [GM MidFontWithSize:15];
        self.font = [UIFont systemFontOfSize:16];
        self.textColor = UIColor.blackColor;
        self.placeholderFont = [GM MidFontWithSize:16];
        self.floatingLabelFont =  [GM MidFontWithSize:13];
        self.hideRightViewWhenEditing = NO;
        self.hideLeftViewWhenEmptyInputUnFoucused = NO;
        self.secureTextEntry = NO;
        self.bottomLineNormalHeight = 1.f;
        self.bottomLineSelectedHeight = 2.f;
        self.textFieldHeightRateExceptMargin = 0.6;
        self.clearButtonMode = UITextFieldViewModeWhileEditing;
        self.needShowOrHideRightViewAnimation = NO;
        self.animationDuration = 0;
        self.maxInputLength = 0;
        self.shouldLimitInputLength = YES;
        self.maxInputNumber = 0.f;
        self.allowModifyInputToMaxInputNumber = NO;
        self.maxDecimalsCount = 0;
        self.shouldAppendDecimalAfterEndEditing = NO;
        self.shouldRemoveDecimalAfterBeginEditing = NO;
        self.shouldSeparatedTextWithSymbol = NO;
        self.separatedSymbol = @" ";
        self.marginFloatingLabelToTextField = 0;
        self.marginBottomLineToTextField = 0;
        self.keyboardType = UIKeyboardTypeNumberPad;

        __weak __typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // Solve the animation bug that occurs when the keyboard layout is directly called externally
            if (weakSelf.animationDuration == 0) {
                weakSelf.animationDuration = 0.3;
            }
        });
    }
    return self;
}

+ (instancetype)defaultConfig {
    WJFloatingAnimatedTextFieldConfig *obj = [[self alloc] init];
    return obj;
}

- (void)setSeparatedFormat:(NSString *)separatedFormat {
    NSAssert([separatedFormat rangeOfString:@"-"].location != NSNotFound, @"The delimited format is xxxx-xxxx-xxxx, xx-xxx-xxxx, separated by -");

    _separatedFormat = separatedFormat;
}

#pragma mark - override system methods
- (BOOL)isEqual:(WJFloatingAnimatedTextFieldConfig *)object {
    BOOL isEqual = YES;
    BOOL isThereAtLeastOnePropertyNotEqual =
        ![self.placeholderColor isEqual:object.placeholderColor] ||
        ![self.floatingLabelColor isEqual:object.floatingLabelColor] ||
        ![self.bottomLineNormalColor isEqual:object.bottomLineNormalColor] ||
        ![self.bottomLineSelectedColor isEqual:object.bottomLineSelectedColor] ||
        ![self.leftLabelColor isEqual:object.leftLabelColor] ||
        ![self.rightLabelColor isEqual:object.rightLabelColor] ||
        ![self.leftIconImage isEqual:object.leftIconImage] ||
        ![self.rightIconImage isEqual:object.rightIconImage] ||
        ![self.placeholder isEqualToString:object.placeholder] ||
        ![self.floatingText isEqualToString:object.floatingText] ||
        ![self.leftLabelString isEqualToString:object.leftLabelString] ||
        ![self.rightLabelString isEqualToString:object.placeholder] ||
        ![self.placeholder isEqualToString:object.rightLabelString] ||
        ![self.attributedPlaceholder isEqual:object.attributedPlaceholder] ||
        ![self.leftLabelFont isEqual:object.leftLabelFont] ||
        ![self.rightLabelFont isEqual:object.rightLabelFont] ||
        ![self.font isEqual:object.font] ||
        ![self.placeholderFont isEqual:object.placeholderFont] ||
        ![self.floatingLabelFont isEqual:object.floatingLabelFont] ||
        !UIEdgeInsetsEqualToEdgeInsets(self.leftViewEdgeInsets, object.leftViewEdgeInsets) ||
        !UIEdgeInsetsEqualToEdgeInsets(self.rightViewEdgeInsets, object.rightViewEdgeInsets) ||
        !UIEdgeInsetsEqualToEdgeInsets(self.placeholderEdgeInsets, object.placeholderEdgeInsets) ||
        self.bottomLineNormalHeight != object.bottomLineNormalHeight ||
        self.bottomLineSelectedHeight != object.bottomLineSelectedHeight ||
        self.textFieldHeightRateExceptMargin != object.textFieldHeightRateExceptMargin ||
        self.marginFloatingLabelToTextField != object.marginFloatingLabelToTextField ||
        self.marginBottomLineToTextField != object.marginBottomLineToTextField ||
        self.maxInputLength != object.maxInputLength ||
        self.shouldLimitInputLength != object.shouldLimitInputLength ||
        ![self.characterSetString isEqualToString:object.characterSetString] ||
        self.maxInputNumber != object.maxInputNumber ||
        self.allowModifyInputToMaxInputNumber != object.allowModifyInputToMaxInputNumber ||
        self.maxDecimalsCount != object.maxDecimalsCount ||
        self.shouldAppendDecimalAfterEndEditing != object.shouldAppendDecimalAfterEndEditing ||
        self.shouldSeparatedTextWithSymbol != object.shouldSeparatedTextWithSymbol ||
        ![self.separatedFormat isEqualToString:object.separatedFormat] ||
        ![self.separatedSymbol isEqualToString:object.separatedSymbol];

    if (isThereAtLeastOnePropertyNotEqual) {
        isEqual = NO;
    }
    return isEqual;
}
@end
