//
//  XLFormPhoneCodeItem.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/12/2025.
//


#import "XLFormPhoneCodeItem.h"

NSString * const XLFormRowDescriptorTypePhoneCode = @"XLFormRowDescriptorTypePhoneCode";

@implementation XLFormPhoneCodeItem

- (instancetype)initWithTag:(NSString *)tag
                     rowType:(NSString *)rowType
                       title:(NSString *)title
{
    self = [super initWithTag:tag rowType:rowType title:title images:@[]];
    if (self) {
        self.dialCode = @"+20";   // default
        self.countryCode = @"EG"; // default
        self.flag = @""; // default
    }
    return self;
}

@end
