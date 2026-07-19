//
//  VetCollectionViewCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 15/07/2025.
//


#import <UIKit/UIKit.h>
@class VetModel;
@class VetCollectionViewCell;

@protocol VetCollectionViewCellDelegate <NSObject>
- (void)vetCellDidTapEdit:(VetCollectionViewCell *)cell;
- (void)vetCellDidTapDelete:(VetCollectionViewCell *)cell;
- (void)vetCellDidTapShare:(VetCollectionViewCell *)cell;
@end

@interface VetCollectionViewCell : UICollectionViewCell
@property (nonatomic, strong) UIViewController *ParentVC;
@property (nonatomic, strong) UIImageView *logoImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *typeLabel;
@property (nonatomic, strong) UIButton *shareButton;
@property (nonatomic, strong) UIButton *deleteButton;
@property (nonatomic, strong) UIButton *favButton;
@property (nonatomic, weak) id<VetCollectionViewCellDelegate> delegate;

- (void)configureWithVet:(VetModel *)vet isUserOwned:(BOOL)isOwned;

@end
