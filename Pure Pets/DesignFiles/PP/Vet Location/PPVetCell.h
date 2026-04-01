//
//  PPVetCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 21/09/2025.
//


// PPVetCell.h
//
//  PPVetCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 21/09/2025.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPVetCell : UITableViewCell

@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *descLabel;
@property (nonatomic, strong) UIButton *callButton;
@property (nonatomic, strong) UIButton *dirButton;

/// Callbacks (avoid tags in VC)
@property (nonatomic, copy, nullable) void (^onCall)(PPVetCell *cell);
@property (nonatomic, copy, nullable) void (^onDirections)(PPVetCell *cell);

+ (NSString *)reuseIdentifier;
- (void)configureWithName:(NSString *)name
              description:(NSString *)desc
                 hasPhone:(BOOL)hasPhone;

@end

NS_ASSUME_NONNULL_END
