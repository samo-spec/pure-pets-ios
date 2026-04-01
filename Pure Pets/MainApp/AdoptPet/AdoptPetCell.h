//
//  AdoptPetCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 13/08/2025.
//


#import <UIKit/UIKit.h>
@class AdoptPetModel;
@class AdoptPetCell;
@protocol AdoptCollectionViewCellDelegate <NSObject>

@optional
// Legacy (kept)
- (void)adoptCellDidTapFavorite:(AdoptPetCell *_Nullable)cell;
- (void)adoptCellDidTapShare:(AdoptPetCell *_Nullable)cell;

- (void)adoptCellDidTapEdit:(AdoptPetCell *_Nullable)cell onModel:(AdoptPetModel *_Nullable)adoptModel;
- (void)adoptCellDidTapDelete:(AdoptPetCell *_Nullable)cell onModel:(AdoptPetModel *_Nullable)adoptModel;

@end


@interface AdoptPetCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *_Nullable imageView;
@property (nonatomic, strong) UILabel *_Nullable titleLabel;
- (void)configureWithName:(NSString *_Nullable )name imageURL:(NSString * _Nullable)urlString;
- (void)configureWithName:(NSString *_Nullable)name imageURL:(NSString *_Nullable)url subtitle:(NSString *_Nullable)subtitle  adoptPetModel:(AdoptPetModel *)adoptPetModel;

@property (nonatomic, strong) AdoptPetModel *_Nullable adoptModel;
@property (nonatomic, weak) id<AdoptCollectionViewCellDelegate> delegate;


@property (nonatomic, strong) UIButton *_Nullable shareButton;
@property (nonatomic, strong) FavoriteButton *_Nullable favButton;
@property (nonatomic, strong) UIButton *_Nullable deleteButton;
@property (nonatomic, strong) UIButton *_Nullable editButton;
- (void)pp_applyOwnerMode:(BOOL)isOwner animated:(BOOL)animated;
@property (nonatomic, strong) UIView *_Nullable topView;
@property (nonatomic, strong) UIView *_Nullable bottomView;
-(void)setFavForCollection:(NSString *_Nullable)collection andID:(NSString *_Nullable)ID;
@end
