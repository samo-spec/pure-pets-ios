//
//  PPHomeServicesCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/12/2025.
//


#import <UIKit/UIKit.h>
#import "PPHomeServiceItem.h"
NS_ASSUME_NONNULL_BEGIN

@interface PPHomeServicesCell : UICollectionViewCell

@property (class, nonatomic, readonly) NSString *reuseIdentifier;
@property (nonatomic, copy, nullable) void (^onTap)(void);
/// Configure service shortcut
- (void)configureWithService:(PPHomeServiceItem *)service;
@property (nonatomic, copy, nullable) void (^onTapMenu)(PPHomeServiceItem *service, MainKindsModel *mainKindModel);
@property (nonatomic, strong) UIButton *cardView;
- (void)configureSkeleton;
@end

NS_ASSUME_NONNULL_END
