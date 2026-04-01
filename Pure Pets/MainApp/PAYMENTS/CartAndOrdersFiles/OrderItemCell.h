//
//  OrderItemCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/07/2025.
//


#import <UIKit/UIKit.h>

@class OrderItem;

@interface OrderItemCell : UITableViewCell

@property (nonatomic, strong) UIImageView *itemImageView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *quantityLabel;
@property (nonatomic, strong) UILabel *priceLabel;

- (void)configureWithItem:(CartItem *)item;

@end
