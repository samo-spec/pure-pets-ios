//
//  StepperCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 14/12/2024.
//


#import "PKYStepper.h"
NS_ASSUME_NONNULL_BEGIN

@protocol StepperDelegate <NSObject>
-(void)daysCount:(NSInteger)count;
@end

@interface StepperCell : UITableViewCell
@property(nonatomic, strong) PKYStepper *plainStepper;
@property (nonatomic, weak) id <StepperDelegate> delegate;
@property NSIndexPath *currentInexPath;
@end

NS_ASSUME_NONNULL_END
