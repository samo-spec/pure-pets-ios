//
//  PPHomeMarketplaceHeroCell.h
//  Pure Pets
//

#import <UIKit/UIKit.h>

@class MainKindsModel;

NS_ASSUME_NONNULL_BEGIN

@interface PPHomeMarketplaceHeroCell : UICollectionViewCell

+ (NSString *)reuseIdentifier;

@property (nonatomic, copy, nullable) void (^onTap)(void);

- (void)configureDefaultContent;
- (void)configureWithMainKind:(nullable MainKindsModel *)mainKind
                     animated:(BOOL)animated;
- (void)refreshThemeAppearance;

@end

NS_ASSUME_NONNULL_END
