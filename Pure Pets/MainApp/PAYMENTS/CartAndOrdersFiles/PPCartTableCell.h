//
//  PPCartTableCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/11/2025.
//


//
//  PPCartTableCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/11/2025.
//  Modern Cart Cell with adaptive blur and iOS 26 glass buttons
//

#import <UIKit/UIKit.h>
@class CartItem;

NS_ASSUME_NONNULL_BEGIN

/// ✅ Callback for cell actions (add/remove/change quantity/delete)
typedef void(^PPCartCellActionBlock)(CartItem *item, NSString *action);

@interface PPCartTableCell : UITableViewCell

@property (nonatomic, strong, readonly) UIImageView *itemImageView;
@property (nonatomic, strong, readonly) UILabel *nameLabel;
@property (nonatomic, strong, readonly) UILabel *priceLabel;
@property (nonatomic, strong, readonly) UILabel *quantityLabel;

/// Called when any of the buttons are tapped
@property (nonatomic, copy, nullable) PPCartCellActionBlock onAction;

/// Configure the cell with a cart item
- (void)configureWithItem:(CartItem *)item;
- (void)pp_setCardHighlighted:(BOOL)highlighted animated:(BOOL)animated;
- (void)pp_applyPressTargetsToButton:(UIButton *)button;
- (void)pp_buttonTouchDown:(UIButton *)button;
- (void)pp_buttonTouchUp:(UIButton *)button;
@end

NS_ASSUME_NONNULL_END
