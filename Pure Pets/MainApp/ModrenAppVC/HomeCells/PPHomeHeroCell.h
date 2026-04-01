//
//  PPHomeHeroCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 2/10/26.
//


typedef NS_ENUM(NSInteger, PPHomeHeroLocationState) {
    PPHomeHeroLocationStateUnset = 0,
    PPHomeHeroLocationStateLoading,
    PPHomeHeroLocationStateReady,
    PPHomeHeroLocationStateDenied
};

@interface PPHomeHeroCell : UICollectionViewCell
+ (NSString *)reuseIdentifier;
- (void)configureWithGreeting:(NSString *)greeting
                     userName:(NSString *)userName
                     location:(NSString *)location
                locationState:(PPHomeHeroLocationState)locationState
                  actionTitle:(nullable NSString *)actionTitle;
@property (nonatomic, copy, nullable) void (^onLocationTap)(void);
@property (nonatomic, copy, nullable) void (^onLocationActionTap)(void);
@end
