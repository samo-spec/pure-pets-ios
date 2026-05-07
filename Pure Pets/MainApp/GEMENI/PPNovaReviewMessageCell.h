//
//  PPNovaReviewMessageCell.h
//  Pure Pets
//

#import <UIKit/UIKit.h>
#import "ChatMessageModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface PPNovaReviewMessageCell : UITableViewCell

+ (NSString *)reuseIdentifier;

- (void)configureWithMessage:(ChatMessageModel *)messageModel maxWidth:(CGFloat)maxWidth;

@end

NS_ASSUME_NONNULL_END
