//

//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/08/2024.
//


#import "XLFormOptionsObject.h"
NS_ASSUME_NONNULL_BEGIN

@interface CountryCodeModel : NSObject<XLFormOptionObject>

@property (nonatomic, assign) NSInteger ID;
@property (nonatomic, strong) NSString *country;
@property (nonatomic, strong) NSString *phoneCode;
@property (nonatomic, strong) NSString *isoCountryCode;

// Computed, auto-generated from isoCountryCode (e.g. "EG" -> "🇪🇬")
@property (nonatomic, strong, readonly) NSString *flag;

@end

NS_ASSUME_NONNULL_END
