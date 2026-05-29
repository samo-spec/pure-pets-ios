//
//  NovaConfirmationCell.h
//  Pure Pets
//

#import <UIKit/UIKit.h>
#import "ChatMessageModel.h"
#import "PetAccessory.h"

NS_ASSUME_NONNULL_BEGIN

@class NovaConfirmationCell;

@protocol NovaConfirmationCellDelegate <NSObject>
- (void)novaConfirmationCellDidConfirm:(NovaConfirmationCell *)cell product:(PetAccessory *)product;
- (void)novaConfirmationCellDidCancel:(NovaConfirmationCell *)cell;
@end

@interface NovaConfirmationCell : UITableViewCell

@property (nonatomic, weak, nullable) id<NovaConfirmationCellDelegate> delegate;

+ (NSString *)reuseIdentifier;

- (void)configureWithMessage:(ChatMessageModel *)messageModel
                    maxWidth:(CGFloat)maxWidth;

@end

NS_ASSUME_NONNULL_END
