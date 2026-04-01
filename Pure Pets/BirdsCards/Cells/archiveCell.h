//
//  archiveCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 18/09/2024.
//



NS_ASSUME_NONNULL_BEGIN


@protocol ArchiveDelegate <NSObject>
-(void)RestoreChild:(NSString *)CageID ChildRingID:(NSString *)ChildRingID childIndexPath:(NSIndexPath *)childIndexPath childID:(NSString *)childID ;
-(void)deleteEditArchiveOptions:(long)index ArchiveData:(ArchiveModel *)ArchiveData cellView:(UIView *)cellView cellIndexPath:(NSIndexPath *)cellIndexPath;
@end

@interface archiveCell : UICollectionViewCell
@property ( nonatomic) ArchiveModel *archiveData;
@property (copy, nonatomic) NSString *ID;
@property (copy, nonatomic) NSString *CageID;
@property (copy, nonatomic) NSString *ChildRingIDD;
@property (copy, nonatomic) NSIndexPath *childIndexPath;
@property (copy, nonatomic) NSIndexPath *cellIndexPath;
@property (nonatomic, weak) id <ArchiveDelegate> delegate;
@property (strong, nonatomic) IBOutlet UILabel *childRingID;
@property (strong, nonatomic) IBOutlet UILabel *archiveDate;
@property (strong, nonatomic) IBOutlet UILabel *archiveCount;
@property (strong, nonatomic) IBOutlet UIButton *delBTN;

@end

NS_ASSUME_NONNULL_END
