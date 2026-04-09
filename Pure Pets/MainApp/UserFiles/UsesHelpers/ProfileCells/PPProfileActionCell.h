//
//  PPProfileActionCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/9/26.
//



@interface PPProfileActionCell : PPProfileBaseCell
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
- (void)configureWithTitle:(NSString *)title iconName:(NSString *)iconName;
@end
