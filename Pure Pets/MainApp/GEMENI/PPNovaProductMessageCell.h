//
//  PPNovaProductMessageCell.h
//  Pure Pets
//

#import <UIKit/UIKit.h>
#import "ChatMessageModel.h"
#import "PPUniversalCell.h"
#import "PetAccessory.h"

NS_ASSUME_NONNULL_BEGIN

@protocol PPNovaProductMessageCellDelegate <NSObject>
- (void)novaProductCell_didTapAddToCart:(PetAccessory *)product;
- (void)novaProductCell_didTapProduct:(PetAccessory *)product;
@end

@interface PPNovaProductMessageCell : UITableViewCell

@property (nonatomic, weak) id<PPNovaProductMessageCellDelegate> delegate;

- (void)configureWithMessage:(ChatMessageModel *)messageModel
                    maxWidth:(CGFloat)maxWidth;

@end

NS_ASSUME_NONNULL_END
