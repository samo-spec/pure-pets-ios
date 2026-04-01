//NS_ASSUME_NONNULL_END
//
//  ArchCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 18/09/2024.
//



NS_ASSUME_NONNULL_BEGIN


@protocol ArchCellDelegate <NSObject>
-(void)deleteEditArchiveOptions:(long)index ArchiveData:(ArchiveModel *)ArchiveData cellView:(UIView *)cellView cellIndexPath:(NSIndexPath *)cellIndexPath;
@end

@interface ArchCell : UICollectionViewCell
@property ( strong,nonatomic) ArchiveModel *archiveData;
@property (weak, nonatomic) NSString *ID;
@property (weak, nonatomic) NSString *CageID;
@property (weak, nonatomic) NSString *ChildRingIDD;
@property (weak, nonatomic) NSIndexPath *childIndexPath;
@property (weak, nonatomic) NSIndexPath *cellIndexPath;
@property (nonatomic, weak) id <ArchCellDelegate> delegate;
@property (strong, nonatomic) IBOutlet UILabel *childRingID;
@property (strong, nonatomic) IBOutlet UILabel *archiveDate;
@property (strong, nonatomic) IBOutlet UILabel *archiveCount;
@property (strong, nonatomic) IBOutlet UIButton *delBTN;
@property (assign, nonatomic)  BOOL isEmpty;

@end

NS_ASSUME_NONNULL_END
