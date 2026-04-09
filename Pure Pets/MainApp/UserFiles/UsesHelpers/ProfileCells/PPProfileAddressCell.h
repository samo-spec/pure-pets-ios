//
//  PPProfileAddressCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/9/26.
//

#import "PPProfileBaseCell.h"
@interface PPProfileAddressCell : PPProfileBaseCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, strong) UIImageView *chevronView;
- (void)configureWithAddress:(PPAddressModel *)address;
@end
