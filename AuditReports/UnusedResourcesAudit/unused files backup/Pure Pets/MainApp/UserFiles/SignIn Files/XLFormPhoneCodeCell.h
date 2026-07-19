//
//  XLFormPhoneCodeCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/12/2025.
//


#import "XLForm.h"
#import "XLFormPhoneCodeItem.h"
#import "PPSelectOptionViewController.h"
@class CountryCodeModel;


@interface XLFormPhoneCodeCell : XLFormBaseCell

@property (nonatomic, strong) UIButton *countryButton;
@property (nonatomic, strong) UILabel *dialCodeLabel;
@property (nonatomic, strong) UITextField *numberField;

@end
