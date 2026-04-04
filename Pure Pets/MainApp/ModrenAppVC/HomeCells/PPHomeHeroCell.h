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

/// Shows / hides a slim one-line order peek strip below the hero card.
- (void)configureOrderPeekWithReference:(nullable NSString *)reference
                            statusTitle:(nullable NSString *)statusTitle
                            statusColor:(nullable UIColor *)statusColor
                        previewImageURL:(nullable NSString *)previewImageURL
                               animated:(BOOL)animated;
- (void)hideOrderPeek:(BOOL)animated;

@property (nonatomic, copy, nullable) void (^onLocationTap)(void);
@property (nonatomic, copy, nullable) void (^onLocationActionTap)(void);
@property (nonatomic, copy, nullable) void (^onOrderPeekTap)(void);
@end
