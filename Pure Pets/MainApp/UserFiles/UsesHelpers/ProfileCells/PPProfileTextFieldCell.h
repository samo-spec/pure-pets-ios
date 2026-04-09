//
//  PPProfileTextFieldCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/9/26.
//



@interface PPProfileTextFieldCell : PPProfileBaseCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITextField *textField;
- (void)configureWithTitle:(NSString *)title
                      text:(NSString *)text
               placeholder:(NSString *)placeholder
              keyboardType:(UIKeyboardType)keyboardType
           textContentType:(UITextContentType)textContentType
             returnKeyType:(UIReturnKeyType)returnKeyType
    autocapitalizationType:(UITextAutocapitalizationType)autocapitalizationType
                 fieldKind:(PPProfileFieldKind)fieldKind
                    target:(id)target
                    action:(SEL)action
                  delegate:(id<UITextFieldDelegate>)delegate;
@end