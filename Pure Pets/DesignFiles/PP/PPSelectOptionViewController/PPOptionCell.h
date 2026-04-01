//
//  PPOptionCell.h
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 24/08/2025.
//


// PPOptionCell.h
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
//NS_ASSUME_NONNULL_END
@interface PPOptionCell : UITableViewCell
@property (nonatomic, strong) UIImageView * _Nullable circleImageView;
@property (nonatomic, strong) UILabel * _Nullable titleLabel;
@property (nonatomic, strong) UILabel * _Nullable subtitleLabel;
- (void)configureWithTitle:(NSString * _Nullable)title subtitle:(NSString * _Nullable)subtitle image:(UIImage * _Nullable)image;
- (void)configureWithTitle:(NSString * _Nullable)title subtitle:(NSString * _Nullable)subtitle imageUrl:(NSString * _Nullable)imageUrl;
- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle imageNamed:(NSString *)imageNamed ;
@end

NS_ASSUME_NONNULL_END
