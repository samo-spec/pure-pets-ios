//
//  PPChildCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 21/12/2025.
//


//
//  PPChildCell.h
//  Pure Pets
//

#import <UIKit/UIKit.h>
@class ChildModel;
NS_ASSUME_NONNULL_BEGIN
@protocol PPChildCellDelegate <NSObject>
@optional
-(void)goToNewCard:(NSString *)RingID fromVC:(NSString *)fromVc isFound:(int )isFound ImagesArr:(NSArray<ImageModel *> *)ImagesArr cardID:(NSString *)cardID;
-(void)DeleteChild:(ChildModel *)childModel FromCageWithID:(NSString *)CageID;
- (void)addChildToArchive:(ChildModel *)childModel cardID:(CardModel *)card;
- (void)transferChild:(ChildModel *)childModel cardID:(CardModel *)card;
- (void)sellChild:(ChildModel *)childModel cardID:(CardModel *)card;
-(void)archiveCardData:(CardModel *)CardData Child:(nullable ChildModel *)child;

- (void)childCellDidTapOptions:(ChildModel *)child;
@end

@interface PPChildCell : UITableViewCell

@property (nonatomic, weak) id<PPChildCellDelegate> delegate;

- (void)configureWithChild:(ChildModel *)child;

+ (NSString *)reuseIdentifier;

@end

NS_ASSUME_NONNULL_END
