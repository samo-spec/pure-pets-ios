//
//  PPProfileSelectorCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/9/26.
//


@interface PPProfileSelectorCell : PPProfileBaseCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *valueLabel;
@property (nonatomic, strong) UILabel *flagLabel;
@property (nonatomic, strong) UIImageView *chevronView;
- (void)configureWithTitle:(NSString *)title
                     value:(NSString *)value
                      flag:(NSString *)flag;
@end