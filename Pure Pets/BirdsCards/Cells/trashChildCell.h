//
//  trashChildCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 18/09/2024.
//



#import "FTPopOverMenu.h"
#import "ChildModel.h"
NS_ASSUME_NONNULL_BEGIN


@protocol trashDelegate <NSObject>
-(void)RestoreChild:(NSString *)CageID ChildRingID:(NSString *)ChildRingID childIndexPath:(NSIndexPath *)childIndexPath childID:(NSString *)childID cardData:(CardModel *)cardData cameFrom:(NSInteger)cameFrom;
-(void)DetaildsFromTrash:(CardModel *)cardData;
@end

@interface trashChildCell : UICollectionViewCell
@property (strong, nonatomic) CardModel *cardData;
@property (copy, nonatomic) NSString *ID;
@property (copy, nonatomic) NSString *CageID;
@property (copy, nonatomic) NSString *ChildRingIDD;
@property (copy, nonatomic) NSIndexPath *childIndexPath;
@property (nonatomic, weak) id <trashDelegate> delegate;
@property (strong, nonatomic) IBOutlet UILabel *childRingID;
@property (strong, nonatomic) IBOutlet UIButton *returnButton;
@property (strong, nonatomic) IBOutlet UIButton *showCardDetaildsBTN;
@property (strong, nonatomic) IBOutlet UILabel *subKindLabel;
@property (strong, nonatomic) IBOutlet UIImageView *mainImaheView;
- (IBAction)optionsBTN:(id)sender;
@property (strong, nonatomic) IBOutlet UILabel *subkindLabel;
@property (strong, nonatomic) IBOutlet UIButton *optionsButton;
@property (nonatomic, assign) CameFrom cameFrom;
@end

NS_ASSUME_NONNULL_END
