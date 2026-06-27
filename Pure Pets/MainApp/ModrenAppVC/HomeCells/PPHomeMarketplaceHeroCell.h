//
//  PPHomeMarketplaceHeroCell.h
//  Pure Pets
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPHomeMarketplaceHeroCell : UICollectionViewCell

+ (NSString *)reuseIdentifier;

@property (nonatomic, copy, nullable) void (^onTap)(void);

- (void)configureDefaultContent;
- (void)refreshThemeAppearance;

@end

NS_ASSUME_NONNULL_END
