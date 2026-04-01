//
//  PPCageCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 20/12/2025.
//


#import <UIKit/UIKit.h>
@class CageModel;
@class CardModel;


NS_ASSUME_NONNULL_BEGIN

@protocol PPCageCellDelegate <NSObject>
- (void)cageCellDidTapEdit:(CageModel *)cage;
- (void)cageCellDidTapBarcode:(CageModel *)cage;
- (void)cageCellDidTapAddChick:(CageModel *)cage;
- (void)cageCellDidTapSetFirstEggDate:(CageModel *)cage;
- (void)cageCellDidTapParentCard:(CardModel *)card
                         fromCage:(CageModel *)cage
                         isFather:(BOOL)isFather;

- (void)cageCellDidSellParent:(CageModel *)cage isFather:(BOOL)isFather;
- (void)cageCellDidArchiveParent:(CageModel *)cage isFather:(BOOL)isFather;
@end

@interface PPCageCell : UICollectionViewCell
@property (nonatomic, weak) id<PPCageCellDelegate> delegate;
- (void)configureWithCage:(CageModel *)cage;
+ (NSString *)reuseIdentifier;
@end

NS_ASSUME_NONNULL_END
