//
//  MainCollectionViewCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 27/07/2024.
//



NS_ASSUME_NONNULL_BEGIN

@interface MainCollectionViewCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UIImageView *mainImageView;
@property (weak, nonatomic) IBOutlet UIView *bottomCellView;
@property (weak, nonatomic) IBOutlet UILabel *animalsKindLabel;

@end

NS_ASSUME_NONNULL_END
