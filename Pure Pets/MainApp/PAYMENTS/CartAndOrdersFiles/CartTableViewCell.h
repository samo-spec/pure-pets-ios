//
//  CartTableViewCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 30/06/2025.
//

#import <UIKit/UIKit.h>
#import "FloatingQuantityButton.h"
NS_ASSUME_NONNULL_BEGIN

@interface CartTableViewCell : UITableViewCell
@property (nonatomic, strong) UIImageView *itemImageView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *priceLabel;
@property (nonatomic, strong) FloatingQuantityButton *qtyButton;

@property (nonatomic, strong) UIViewController *ParentVC;
@end

NS_ASSUME_NONNULL_END
