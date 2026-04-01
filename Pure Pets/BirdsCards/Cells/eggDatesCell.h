//
//  eggDatesCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 12/12/2024.
//



NS_ASSUME_NONNULL_BEGIN


@protocol eggDelegate <NSObject>
-(void)showDatePicKer:(NSIndexPath *)currentInexPath;
@end

@interface eggDatesCell : UITableViewCell
@property (strong, nonatomic) UILabel *dateLabel;
@property (nonatomic, weak) id <eggDelegate> delegate;
@property NSIndexPath *currentInexPath;

@property (strong, nonatomic) UILabel *selectedDateLabel;

@property (strong, nonatomic) UILabel *cellLabel;

@end

NS_ASSUME_NONNULL_END
