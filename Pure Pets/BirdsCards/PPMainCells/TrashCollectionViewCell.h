//
//  TrashCollectionViewCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 13/12/2025.
//


//
//  TrashCollectionViewCell.h
//  Pure Pets
//

#import <UIKit/UIKit.h>
@class TrashModel;

NS_ASSUME_NONNULL_BEGIN

@protocol TrashCollectionViewCellDelegate <NSObject>
- (void)trashRestore:(TrashModel *)trash;
- (void)trashCellDidTapDeleteForever:(NSIndexPath *)indexPath;
@end

@interface TrashCollectionViewCell : UICollectionViewCell

@property (nonatomic, weak) id<TrashCollectionViewCellDelegate> delegate;
@property (nonatomic, strong) TrashModel *trash;
@property (nonatomic, strong) NSIndexPath *indexPath;

- (void)configureWithTrash:(TrashModel *)trash;

@end

NS_ASSUME_NONNULL_END
