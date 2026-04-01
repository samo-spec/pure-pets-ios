//
//  selectTableViewCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 26/07/2024.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface selectTableViewCell : UITableViewCell

@property (strong, nonatomic) UIView *containerView;
@property (strong, nonatomic) UILabel *attributeLabel;
@property (strong, nonatomic) UILabel *classificationLabel;
@property (strong, nonatomic) UILabel *birdIdLabel;
@property (strong, nonatomic) UILabel *sexualLabel;
@property (strong, nonatomic) UIImageView *mainImageView;
@property (strong, nonatomic) UIImageView *sexualImageView;

@end

NS_ASSUME_NONNULL_END
