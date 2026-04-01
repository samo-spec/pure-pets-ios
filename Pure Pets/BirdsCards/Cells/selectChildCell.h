//
//  selectChildCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 26/07/2024.
//


#import "importantFiles.h"
#import "FTPopOverMenu.h"
#import <Pure_Pets-Swift.h>
#import "ImageModel.h"
#import "ChildModel.h"
#import "CardModel.h"
#import "ImageModel.h"

 
NS_ASSUME_NONNULL_BEGIN

@protocol goToNewCardDelegate <NSObject>
@optional
-(void)goToNewCard:(NSString *)RingID fromVC:(NSString *)fromVc isFound:(int )isFound ImagesArr:(NSArray<ImageModel *> *)ImagesArr cardID:(NSString *)cardID;
-(void)DeleteChild:(ChildModel *)childModel FromCageWithID:(NSString *)CageID;
- (void)addChildToArchive:(ChildModel *)childModel cardID:(CardModel *)card;
- (void)transferChild:(ChildModel *)childModel cardID:(CardModel *)card;
- (void)sellChild:(ChildModel *)childModel cardID:(CardModel *)card;
-(void)archiveCardData:(CardModel *)CardData Child:(nullable ChildModel *)child;

@end

@interface selectChildCell : UITableViewCell

@property (copy, nonatomic) NSString *ID;
@property (copy, nonatomic) NSString *CageID;
@property (copy, nonatomic) NSIndexPath *indexPath;
@property (copy, nonatomic) NSString *ChildRingID;
@property  NSInteger childIndex;
@property (copy, nonatomic) NSString *BirdRingID;
@property (nonatomic, weak) id <goToNewCardDelegate> delegate;
@property (copy, nonatomic) NSString *cardID;
@property int isFound;
@property (copy, nonatomic) NSArray<ImageModel *> *ImagesArr;
@property (strong, nonatomic) CardModel  *cardModel;
@property (strong, nonatomic) ChildModel  *childModel;
@property (weak, nonatomic) IBOutlet UIView *centerView;
@property (weak, nonatomic) IBOutlet UILabel *RingID;
@property (strong, nonatomic) IBOutlet UIImageView *MainImageView;
@property (strong, nonatomic) IBOutlet UIButton *showCardBTN;
@property (strong, nonatomic) IBOutlet UIButton *optionsBTN;
@property (strong, nonatomic) IBOutlet UILabel *title_label;

@end

NS_ASSUME_NONNULL_END



