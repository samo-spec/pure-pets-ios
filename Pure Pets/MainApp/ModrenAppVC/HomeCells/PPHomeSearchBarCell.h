//
//  PPHomeSearchBarCell.h
//  Pure Pets
//
//  Premium minimal search bar — one surface, one icon, one statement.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPHomeSearchBarCell : UICollectionViewCell

+ (NSString *)reuseIdentifier;

@property (nonatomic, copy, nullable) void (^onTap)(void);

- (void)configureWithTrendingQuery:(nullable NSString *)query;
- (void)setQueryText:(nullable NSString *)text animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
