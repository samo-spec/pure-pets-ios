//
//  PPPetsTitleView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 14/01/2026.
//


#import <UIKit/UIKit.h>
@class PPInfoPill;
NS_ASSUME_NONNULL_BEGIN

@interface PPPetsTitleView : UIView

@property (nonatomic, copy, nullable) void (^onShareTapped)(void);
@property (nonatomic, copy, nullable) void (^onFavoriteTapped)(BOOL isFavorite);

- (void)animatePillsIn;
@property (nonatomic, copy) NSString *price;
/// Main title (e.g. ad title)
@property (nonatomic, copy) NSString *title;

/// Secondary location text (e.g. city name)
@property (nonatomic, copy) NSString *location;

/// Configure in one call (recommended)
- (void)configureWithTitle:(NSString *)title
                  location:(nullable NSString *)location
                     price:(nullable NSString *)price;

- (void)configureWithTitle:(NSString *)title
                  location:(nullable NSString *)location
                     price:(nullable NSString *)price
                  category:(nullable NSString *)category;

- (void)updateMetaPillsWithItems:(NSArray<PPInfoPill *> *)items;

@end

NS_ASSUME_NONNULL_END
