//
//  XLFormTextFieldCell.m
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

#import "NSObject+XLFormAdditions.h"
#import "UIView+XLFormAdditions.h"
#import "XLFormRowDescriptor.h"
#import "XLForm.h"
#import "XLFormTextFieldCell.h"

NSString *const XLFormTextFieldLengthPercentage = @"textFieldLengthPercentage";
NSString *const XLFormTextFieldMaxNumberOfCharacters = @"textFieldMaxNumberOfCharacters";

@interface XLFormTextFieldCell() <UITextFieldDelegate>

@property NSMutableArray * dynamicCustomConstraints;

@end

@implementation XLFormTextFieldCell

@synthesize textField = _textField;
@synthesize textLabel = _textLabel;
@synthesize returnKeyType = _returnKeyType;
@synthesize nextReturnKeyType = _nextReturnKeyType;


#pragma mark - KVO

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ((object == self.textLabel && [keyPath isEqualToString:@"text"]) ||  (object == self.imageView && [keyPath isEqualToString:@"image"])){
        if ([[change objectForKey:NSKeyValueChangeKindKey] isEqualToNumber:@(NSKeyValueChangeSetting)]){
            [self.contentView setNeedsUpdateConstraints];
        }
    }
}

-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _returnKeyType = UIReturnKeyDone;
        _nextReturnKeyType = UIReturnKeyNext;
    }
    return self;
}

-(void)dealloc
{
    [self.textLabel removeObserver:self forKeyPath:@"text"];
    [self.imageView removeObserver:self forKeyPath:@"image"];
}

#pragma mark - XLFormDescriptorCell

-(void)configure
{
    [super configure];
    [self setSelectionStyle:UITableViewCellSelectionStyleNone];

    self.textLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.textField.translatesAutoresizingMaskIntoConstraints = NO;

    [self.contentView addSubview:self.textLabel];
    [self.contentView addSubview:self.textField];
   
    [self setupStaticConstraints];

    [self.textLabel addObserver:self forKeyPath:@"text"
                        options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
                        context:0];

    [self.imageView addObserver:self forKeyPath:@"image"
                        options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
                        context:0];

    [self.textField addTarget:self action:@selector(textFieldDidChange:)
             forControlEvents:UIControlEventEditingChanged];

    self.textLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
}


- (void)setupStaticConstraints {

    UILayoutGuide *content = self.contentView.layoutMarginsGuide;

    // Vertically center label + textfield
    [self.textLabel.centerYAnchor constraintEqualToAnchor:content.centerYAnchor].active = YES;
    [self.textField.centerYAnchor constraintEqualToAnchor:content.centerYAnchor].active = YES;

    // Prevent compression
   // [self.textLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
        //                                             forAxis:UILayoutConstraintAxisHorizontal];
   // [self.textField setContentHuggingPriority:UILayoutPriorityDefaultLow
          //                            forAxis:UILayoutConstraintAxisHorizontal];
    
    [_textField sizeToFit];
}


-(void)update
{
    [super update];
   
    // Force left alignment for Arabic & English
    self.textField.textAlignment = NSTextAlignmentLeft;
    self.textField.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    
    
    self.textField.delegate = self;
       self.textField.clearButtonMode = UITextFieldViewModeNever;

      
    
    
    if ([self.rowDescriptor.rowType isEqualToString:XLFormRowDescriptorTypeText]){
        self.textField.autocorrectionType = UITextAutocorrectionTypeDefault;
        self.textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        self.textLabel.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
        //self.textField.clearButtonMode =  UITextFieldViewModeNever;
        self.textField.returnKeyType = UIReturnKeyDone;
    }
    else if ([self.rowDescriptor.rowType isEqualToString:XLFormRowDescriptorTypeName]){
        self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
    }
    else if ([self.rowDescriptor.rowType isEqualToString:XLFormRowDescriptorTypeEmail]){
        self.textField.keyboardType = UIKeyboardTypeEmailAddress;
        self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }
    else if ([self.rowDescriptor.rowType isEqualToString:XLFormRowDescriptorTypeNumber]){
        self.textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }
    else if ([self.rowDescriptor.rowType isEqualToString:XLFormRowDescriptorTypeInteger]){
        self.textField.keyboardType = UIKeyboardTypeNumberPad;
    }
    else if ([self.rowDescriptor.rowType isEqualToString:XLFormRowDescriptorTypeDecimal]){
        self.textField.keyboardType = UIKeyboardTypeDecimalPad;
    }
    else if ([self.rowDescriptor.rowType isEqualToString:XLFormRowDescriptorTypePassword]){
        self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.textField.keyboardType = UIKeyboardTypeASCIICapable;
        self.textField.secureTextEntry = YES;
    }
    else if ([self.rowDescriptor.rowType isEqualToString:XLFormRowDescriptorTypePhone]){
        self.textField.keyboardType = UIKeyboardTypePhonePad;
    }
    else if ([self.rowDescriptor.rowType isEqualToString:XLFormRowDescriptorTypeURL]){
        self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.textField.keyboardType = UIKeyboardTypeURL;
    }
    else if ([self.rowDescriptor.rowType isEqualToString:XLFormRowDescriptorTypeTwitter]){
        self.textField.keyboardType = UIKeyboardTypeTwitter;
        self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }
    else if ([self.rowDescriptor.rowType isEqualToString:XLFormRowDescriptorTypeAccount]){
        self.textField.keyboardType = UIKeyboardTypeASCIICapable;
        self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }
    else if ([self.rowDescriptor.rowType isEqualToString:XLFormRowDescriptorTypeZipCode]){
        self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.textField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        self.textField.keyboardType = UIKeyboardTypeDefault;
    }

    self.textLabel.text = ((self.rowDescriptor.required && self.rowDescriptor.title && self.rowDescriptor.sectionDescriptor.formDescriptor.addAsteriskToRequiredRowsTitle) ? [NSString stringWithFormat:@"%@", self.rowDescriptor.title] : self.rowDescriptor.title);

    self.textField.text = self.rowDescriptor.value ? [self.rowDescriptor displayTextValue] : self.rowDescriptor.noValueDisplayText;
    [self.textField setEnabled:!self.rowDescriptor.isDisabled];
    self.textField.textColor = self.rowDescriptor.isDisabled ? [AppPrimaryClr colorWithAlphaComponent:0.45] : AppPrimaryClr;
    //self.textField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.textField.font = [GM MidFontWithSize:14];
    self.textField.clearButtonMode =  UITextFieldViewModeWhileEditing;
    //self.textField.backgroundColor = AppPrimaryClr;
    [_textField sizeToFit];
    
    _textField.returnKeyType = UIReturnKeyDone;

    //[self.imageView setImage:PPSYSImage(@"plus")];
    
}

-(BOOL)formDescriptorCellCanBecomeFirstResponder
{
    return (!self.rowDescriptor.isDisabled);
}

-(BOOL)formDescriptorCellBecomeFirstResponder
{
    return [self.textField becomeFirstResponder];
}

-(void)highlight
{
    [super highlight];
    self.textLabel.textColor = self.tintColor;
}

-(void)unhighlight
{
    [super unhighlight];
    [self.formViewController updateFormRow:self.rowDescriptor];
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    [_textField sizeToFit];
}

#pragma mark - Properties

-(UILabel *)textLabel
{
    if (_textLabel) return _textLabel;
    _textLabel = [UILabel autolayoutView];
    _textLabel.font = [GM MidFontWithSize:14];
    return _textLabel;
}

-(UITextField *)textField
{
    if (_textField) return _textField;
    _textField = [UITextField autolayoutView];
    _textField.font = [GM MidFontWithSize:14];
    return _textField;
}
- (void)updateConstraints
{
    if (self.dynamicCustomConstraints) {
        [NSLayoutConstraint deactivateConstraints:self.dynamicCustomConstraints];
    }

    NSMutableArray *constraints = [NSMutableArray array];
    UILayoutGuide *content = self.contentView.layoutMarginsGuide;

    BOOL hasImage = (self.imageView.image != nil);
    BOOL hasLabel = (self.textLabel.text.length > 0);

    // Ensure imageView uses autolayout when needed
    self.imageView.translatesAutoresizingMaskIntoConstraints = NO;

    // Case A — IMAGE + LABEL + TEXTFIELD
    if (hasImage && hasLabel) {
        [constraints addObject:[self.imageView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor]];
        [constraints addObject:[self.imageView.centerYAnchor constraintEqualToAnchor:content.centerYAnchor]];

        [constraints addObject:[self.textLabel.leadingAnchor constraintEqualToAnchor:self.imageView.trailingAnchor constant:8]];
        [constraints addObject:[self.textField.leadingAnchor constraintEqualToAnchor:self.textLabel.trailingAnchor constant:12]];
        [constraints addObject:[self.textField.trailingAnchor constraintEqualToAnchor:content.trailingAnchor]];
    }

    // Case B — IMAGE + NO LABEL
    else if (hasImage && !hasLabel) {
        [constraints addObject:[self.imageView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor]];
        [constraints addObject:[self.imageView.centerYAnchor constraintEqualToAnchor:content.centerYAnchor]];

        [constraints addObject:[self.textField.leadingAnchor constraintEqualToAnchor:self.imageView.trailingAnchor constant:12]];
        [constraints addObject:[self.textField.trailingAnchor constraintEqualToAnchor:content.trailingAnchor]];
    }

    // Case C — NO IMAGE + LABEL + TEXTFIELD
    else if (!hasImage && hasLabel) {
        [constraints addObject:[self.textLabel.leadingAnchor constraintEqualToAnchor:content.leadingAnchor]];
        [constraints addObject:[self.textField.leadingAnchor constraintEqualToAnchor:self.textLabel.trailingAnchor constant:12]];
        [constraints addObject:[self.textField.trailingAnchor constraintEqualToAnchor:content.trailingAnchor]];
    }

    // Case D — TEXTFIELD ONLY
    else {
        [constraints addObject:[self.textField.leadingAnchor constraintEqualToAnchor:content.leadingAnchor]];
        [constraints addObject:[self.textField.trailingAnchor constraintEqualToAnchor:content.trailingAnchor]];
    }

    // Width constraint (if percentage specified)
    if (self.textFieldLengthPercentage) {
        CGFloat percent = [self.textFieldLengthPercentage floatValue];
        [constraints addObject:
            [self.textField.widthAnchor constraintEqualToAnchor:self.contentView.widthAnchor multiplier:percent]
        ];
    }

    self.dynamicCustomConstraints = constraints;
    [NSLayoutConstraint activateConstraints:self.dynamicCustomConstraints];

    [super updateConstraints];
}


#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    return [self.formViewController textFieldShouldClear:textField];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    return [self.formViewController textFieldShouldReturn:textField];
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    return [self.formViewController textFieldShouldBeginEditing:textField];
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    return [self.formViewController textFieldShouldEndEditing:textField];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if (self.textFieldMaxNumberOfCharacters) {
        // Check maximum length requirement
        NSString *newString = [textField.text stringByReplacingCharactersInRange:range withString:string];
        if (newString.length > self.textFieldMaxNumberOfCharacters.integerValue) {
            return NO;
        }
    }

    // Otherwise, leave response to view controller
    return [self.formViewController textField:textField shouldChangeCharactersInRange:range replacementString:string];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    [self.formViewController beginEditing:self.rowDescriptor];
    [self.formViewController textFieldDidBeginEditing:textField];
    // set the input to the raw value if we have a formatter and it shouldn't be used during input
    if (self.rowDescriptor.valueFormatter) {
        self.textField.text = [self.rowDescriptor editTextValue];
    }
    self.textField.clearButtonMode = UITextFieldViewModeNever;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    // process text change before we stick a formatted value in the UITextField
    [self textFieldDidChange:textField];
    
    // losing input, replace the text field with the formatted value
    if (self.rowDescriptor.valueFormatter) {
        self.textField.text = [self.rowDescriptor.value displayText];
    }
    self.textField.clearButtonMode = UITextFieldViewModeNever;
    [self.formViewController endEditing:self.rowDescriptor];
    [self.formViewController textFieldDidEndEditing:textField];
}


#pragma mark - Helper

- (void)textFieldDidChange:(UITextField *)textField{
    if([self.textField.text length] > 0) {
        BOOL didUseFormatter = NO;
        
        if (self.rowDescriptor.valueFormatter && self.rowDescriptor.useValueFormatterDuringInput)
        {
            // use generic getObjectValue:forString:errorDescription and stringForObjectValue
            NSString *errorDescription = nil;
            NSString *objectValue = nil;
            
            if ([ self.rowDescriptor.valueFormatter getObjectValue:&objectValue forString:textField.text errorDescription:&errorDescription]) {
                NSString *formattedValue = [self.rowDescriptor.valueFormatter stringForObjectValue:objectValue];
                
                self.rowDescriptor.value = objectValue;
                textField.text = formattedValue;
                didUseFormatter = YES;
            }
        }
        
        // only do this conversion if we didn't use the formatter
        if (!didUseFormatter)
        {
            if ([self.rowDescriptor.rowType isEqualToString:XLFormRowDescriptorTypeNumber] || [self.rowDescriptor.rowType isEqualToString:XLFormRowDescriptorTypeDecimal]){
                self.rowDescriptor.value =  [NSDecimalNumber decimalNumberWithString:self.textField.text locale:NSLocale.currentLocale];
            } else if ([self.rowDescriptor.rowType isEqualToString:XLFormRowDescriptorTypeInteger]){
                self.rowDescriptor.value = @([self.textField.text integerValue]);
            } else {
                self.rowDescriptor.value = self.textField.text;
            }
        }
    } else {
        self.rowDescriptor.value = nil;
    }
}

-(void)setReturnKeyType:(UIReturnKeyType)returnKeyType
{
    _returnKeyType = returnKeyType;
    self.textField.returnKeyType = returnKeyType;
}

-(UIReturnKeyType)returnKeyType
{
    return _returnKeyType;
}


@end
