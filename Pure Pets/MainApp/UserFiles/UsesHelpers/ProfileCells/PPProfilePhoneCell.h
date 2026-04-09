//
//  PPProfilePhoneCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/9/26.
//


@interface PPProfilePhoneCell : PPProfileBaseCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *prefixLabel;
@property (nonatomic, strong) UITextField *textField;
- (void)configureWithTitle:(NSString *)title
                    prefix:(NSString *)prefix
                      text:(NSString *)text
               placeholder:(NSString *)placeholder
                 fieldKind:(PPProfileFieldKind)fieldKind
                    target:(id)target
                    action:(SEL)action
                  delegate:(id<UITextFieldDelegate>)delegate;
@end