//
//  PickerSheetViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 06/02/2025.
//

#import <UIKit/UIKit.h>
 

typedef NS_ENUM(NSInteger, Pick)
{
    PickSunCountries,
    PickSunCage,
    PickSunKinds
};


@class SubKindModel;
@class CountryCodeModel;
@class CageModel;

@interface PickerSheetViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, XLFormRowDescriptorViewController>
-(void)setSubKindsArr:(NSMutableArray<SubKindModel *> *)subKindsAr;
@property (strong, nonatomic) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<SubKindModel *> *subKindsData; // Data for the picker
@property (nonatomic, strong) NSMutableArray<CountryCodeModel *> *pickerData; // Data for the picker
@property (nonatomic, copy) void (^completionHandler)(CountryCodeModel *selectedCountry); // Completion handler
@property (nonatomic, copy) void (^subCompletionHandler)(SubKindModel *selectedsubKind); // Completion handler
@property (nonatomic, copy) void (^cageCompletionHandler)(CageModel *selectedCage); // Completion handler
@property (nonatomic, assign) Pick pick;
@property (strong, nonatomic) UILabel *topTitle;
@end
