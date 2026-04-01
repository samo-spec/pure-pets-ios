//
//  XLFormPhoneCodeItem.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/12/2025.
//


#import "XLForm.h"

extern NSString * const XLFormRowDescriptorTypePhoneCode;

@interface XLFormPhoneCodeItem : XLFormRowDescriptor

@property (nonatomic, strong) NSString *dialCode;
@property (nonatomic, strong) NSString *countryCode;
@property (nonatomic, strong) NSString *flag;


- (instancetype)initWithTag:(NSString *)tag
                     rowType:(NSString *)rowType
                       title:(NSString *)title;

@end
