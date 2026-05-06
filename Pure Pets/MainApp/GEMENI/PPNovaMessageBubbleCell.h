//
//  PPNovaMessageBubbleCell.h
//  Pure Pets
//

#import <UIKit/UIKit.h>
#import "ChatMessageModel.h"

NS_ASSUME_NONNULL_BEGIN

@class PPNovaMessageBubbleCell;

@protocol PPNovaMessageBubbleCellDelegate <NSObject>
@optional
- (void)novaMessageCell:(PPNovaMessageBubbleCell *)cell
   didTapActionAtIndex:(NSInteger)index
                  title:(NSString *)title
           messageModel:(nullable ChatMessageModel *)messageModel;
@end

@interface PPNovaMessageBubbleCell : UITableViewCell

@property (nonatomic, weak, nullable) id<PPNovaMessageBubbleCellDelegate> delegate;

+ (NSString *)reuseIdentifier;

- (void)configureWithMessage:(ChatMessageModel *)messageModel
                    maxWidth:(CGFloat)maxWidth;

- (void)configureTypingWithMaxWidth:(CGFloat)maxWidth;
- (void)setActionTitles:(nullable NSArray<NSString *> *)actionTitles;

@end

NS_ASSUME_NONNULL_END
