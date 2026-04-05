//
//  PPHomeActionCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 26/12/2025.
//


#import <UIKit/UIKit.h>
#import "PPHomeModels.h"


NS_ASSUME_NONNULL_BEGIN

@interface PPHomeActionCell : UICollectionViewCell

+ (NSString *)reuseIdentifier;

@property (nonatomic, copy, nullable) void (^onTap)(void);
@property (nonatomic, strong) UIButton *actionButton;
/// Configure with SF Symbol name + title
- (void)configureWithTitle:(NSString *)title
                systemIcon:(NSString *)systemIconName;
- (void)configureWithQuickAction:(PPHomeQuickActionModel *)quickAction;

@end

NS_ASSUME_NONNULL_END
