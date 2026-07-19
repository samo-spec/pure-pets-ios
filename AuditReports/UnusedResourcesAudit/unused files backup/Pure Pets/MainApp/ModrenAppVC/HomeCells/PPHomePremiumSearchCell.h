//
//  PPHomePremiumSearchCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/3/26.
//


//
//  PPHomePremiumSearchCell.h
//  Pure Pets
//
//  Created by Kilo on 02/05/2026.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPHomePremiumSearchCell : UICollectionViewCell

+ (NSString *)reuseIdentifier;

@property (nonatomic, copy, nullable) void (^onTap)(void);

- (void)configureWithTrendingQuery:(nullable NSString *)query;

- (void)setQueryText:(nullable NSString *)text animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
