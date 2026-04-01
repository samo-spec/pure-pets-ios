//
//  OptionTableViewCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 13/08/2025.
//


// OptionTableViewCell.h
#import <UIKit/UIKit.h>
@class OptionModel;

@interface OptionTableViewCell : UITableViewCell
- (void)configureWithOption:(OptionModel *)option;
- (void)configureWithAddressTitleModel:(PPAddressModel *)Address;
@property (nonatomic, strong) PPAddressModel *Address;


@end
