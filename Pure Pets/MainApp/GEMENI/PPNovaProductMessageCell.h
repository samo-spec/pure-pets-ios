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
- (void)novaProductCell_didTapAddToCart:(id)item;
- (void)novaProductCell_didTapProduct:(id)item;
@end

@interface PPNovaProductMessageCell : UITableViewCell

@property (nonatomic, weak) id<PPNovaProductMessageCellDelegate> delegate;

- (void)configureWithMessage:(ChatMessageModel *)messageModel
                    maxWidth:(CGFloat)maxWidth;
- (void)updateAvailableWidth:(CGFloat)maxWidth;

@end

NS_ASSUME_NONNULL_END
