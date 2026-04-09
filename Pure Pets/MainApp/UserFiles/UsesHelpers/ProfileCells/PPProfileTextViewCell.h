//
//  PPProfileTextViewCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/9/26.
//


@interface PPProfileTextViewCell : PPProfileBaseCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (nonatomic, strong) NSLayoutConstraint *textViewHeightConstraint;
- (void)configureWithTitle:(NSString *)title
                      text:(NSString *)text
               placeholder:(NSString *)placeholder
                 fieldKind:(PPProfileFieldKind)fieldKind
                  delegate:(id<UITextViewDelegate>)delegate;
- (void)updatePreferredHeight;
- (void)updatePlaceholderVisibility;
@end