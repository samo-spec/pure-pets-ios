//
//  PPHomeProviderCategoryPillCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 6/25/26.
//
NS_ASSUME_NONNULL_BEGIN


static UIColor *PPHomeProviderCategoryDynamicColor(UIColor *lightColor, UIColor *darkColor)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
        }];
    }
    return lightColor;
}


typedef NS_ENUM(NSInteger, PPHomeProviderCategoryRoute) {
    PPHomeProviderCategoryRouteServices = 0,
    PPHomeProviderCategoryRouteNearbyServices,
    PPHomeProviderCategoryRouteVeterinarians
};

@interface PPHomeProviderCategoryItem : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *titleKey;
@property (nonatomic, copy) NSString *subtitleKey;
@property (nonatomic, copy) NSString *systemIconName;
@property (nonatomic, assign) PPHomeProviderCategoryRoute route;
+ (instancetype)itemWithIdentifier:(NSString *)identifier
                          titleKey:(NSString *)titleKey
                       subtitleKey:(NSString *)subtitleKey
                        systemIcon:(NSString *)systemIconName
                             route:(PPHomeProviderCategoryRoute)route;
@end


@interface PPHomeProviderCategoryPillCell : UICollectionViewCell
@property (nonatomic, copy, nullable) void (^onTap)(PPHomeProviderCategoryItem *item);
@property (nonatomic, copy, nullable) void (^onFavTap)(PPHomeProviderCategoryItem *item);
- (void)configureWithItem:(PPHomeProviderCategoryItem *)item selected:(BOOL)selected;
+ (NSString *)reuseIdentifier;
@end
NS_ASSUME_NONNULL_END


 
