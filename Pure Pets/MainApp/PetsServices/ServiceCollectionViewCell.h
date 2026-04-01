//
//  ServiceCollectionViewCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 14/07/2025.
//


#import <UIKit/UIKit.h>

@class ServiceModel;
@class FavoriteButton;
@class ServiceCollectionViewCell;

@protocol ServiceCollectionViewCellDelegate <NSObject>
- (void)serviceCellDidTapShare:(ServiceCollectionViewCell *)cell;
- (void)serviceCellDidTapDelete:(ServiceCollectionViewCell *)cell;
- (void)serviceCellDidTapEdit:(ServiceCollectionViewCell *)cell;;
@end

@interface ServiceCollectionViewCell : UICollectionViewCell
@property (nonatomic, strong) UIViewController *ParentVC;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *priceLabel;
@property (nonatomic, assign) BOOL isOwnedByUser;

@property (nonatomic, strong) UIButton *shareButton;
@property (nonatomic, strong) UIButton *deleteButton;

@property (nonatomic, strong) FavoriteButton *favButton;

@property (nonatomic, weak) id<ServiceCollectionViewCellDelegate> delegate;

- (void)configureWithService:(ServiceModel *)service;
- (void)configureWithService:(ServiceModel *)service isUserOwned:(BOOL)isOwned;
@end
