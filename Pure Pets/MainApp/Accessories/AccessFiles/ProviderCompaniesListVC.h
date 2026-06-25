//
//  ProviderCompaniesListVC.h
//  Pure Pets
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ProviderCompaniesListVC : UIViewController

@property (nonatomic, copy) NSString *selectedProviderCategoryIdentifier;
@property (nonatomic, copy, nullable) NSString *selectedProviderCategoryTitleKey;
@property (nonatomic, copy, nullable) NSString *selectedProviderCategorySubtitleKey;

@end

NS_ASSUME_NONNULL_END
