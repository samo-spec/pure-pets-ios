//
//  DetailsTableViewCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/07/2024.
//


#import "ZMJTipView.h"
#import "YYAnimatedImageView.h"
NS_ASSUME_NONNULL_BEGIN

@protocol showParentData <NSObject>
-(void)showData:(NSString *)parentID rowIndex:(long)rowIndex;
@end

@interface DetailsTableViewCell : UITableViewCell
@property (strong, nonatomic)  UIImageView *warningImageView;
@property (nonatomic, weak) id <showParentData> delegate;
@property (copy, nonatomic) NSString *parentID;
@property (copy, nonatomic) NSString *deleteReason;
@property  long cellRowIndex;
@property (strong, nonatomic) UILabel *titleLablel;
@property (strong, nonatomic) UIButton *detailsButton;
@property (strong, nonatomic) UIButton *showParentDetails;
@property (strong, nonatomic) UIButton *showParentDetailsAction;
@property (nonatomic, strong) ZMJTipView *tipView;
@property (strong, nonatomic) UIButton *deleteInfoBTN;
-(void)setButtonEnabled:(BOOL)enabled;
@end

NS_ASSUME_NONNULL_END
