//
//  PPBannersManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 09/09/2025.
//


// PPBannersManager.h

#import <Foundation/Foundation.h>
#import "EnumValues.h"

NS_ASSUME_NONNULL_BEGIN

@class MainBannerModel;

@interface PPHomePromoCarouselCard : NSObject

@property (nonatomic, copy) NSString *cardID;
@property (nonatomic, assign) BOOL visible;
@property (nonatomic, assign) NSInteger sortOrder;

@property (nonatomic, copy) NSString *badgeTextEn;
@property (nonatomic, copy) NSString *badgeTextAr;
@property (nonatomic, copy) NSString *titleTextEn;
@property (nonatomic, copy) NSString *titleTextAr;
@property (nonatomic, copy) NSString *subtitleTextEn;
@property (nonatomic, copy) NSString *subtitleTextAr;

@property (nonatomic, copy) NSString *primaryButtonTitleEn;
@property (nonatomic, copy) NSString *primaryButtonTitleAr;
@property (nonatomic, copy) NSString *secondaryButtonTitleEn;
@property (nonatomic, copy) NSString *secondaryButtonTitleAr;
@property (nonatomic, assign) BOOL hidePrimaryButton;
@property (nonatomic, assign) BOOL hideSecondaryButton;

@property (nonatomic, copy, nullable) NSURL *characterImageURL;
@property (nonatomic, copy, nullable) NSURL *backgroundImageURL;
@property (nonatomic, copy) NSString *startColorHex;
@property (nonatomic, copy) NSString *endColorHex;
@property (nonatomic, copy) NSString *accentColorHex;
@property (nonatomic, assign) PPBannerTextStyle textStyle;

@property (nonatomic, assign) PPBannerOnTapAction cardTapAction;
@property (nonatomic, copy) NSString *cardTapValue;
@property (nonatomic, assign) PPBannerOnTapAction primaryButtonTapAction;
@property (nonatomic, copy) NSString *primaryButtonTapValue;
@property (nonatomic, assign) PPBannerOnTapAction secondaryButtonTapAction;
@property (nonatomic, copy) NSString *secondaryButtonTapValue;

@property (nonatomic, assign) NSTimeInterval autoScrollInterval;

- (instancetype)initWithDictionary:(NSDictionary *)dict documentID:(nullable NSString *)documentID;
- (NSDictionary *)toDictionary;

- (NSString *)localizedBadgeText;
- (NSString *)localizedTitleText;
- (NSString *)localizedSubtitleText;
- (NSString *)localizedPrimaryButtonTitle;
- (NSString *)localizedSecondaryButtonTitle;
- (BOOL)showsPrimaryButton;
- (BOOL)showsSecondaryButton;

@end

@interface PPHomePromoCarouselManager : NSObject

+ (instancetype)sharedManager;

@property (nonatomic, copy, readonly) NSArray<PPHomePromoCarouselCard *> *cards;

- (void)startListeningWithCompletion:(void (^)(NSArray<PPHomePromoCarouselCard *> * _Nullable cards,
                                              NSError * _Nullable error))completion;
- (void)stopListening;
- (void)fetchOnceWithCompletion:(void (^)(NSArray<PPHomePromoCarouselCard *> * _Nullable cards,
                                         NSError * _Nullable error))completion;

@end

@interface PPBannersManager : NSObject

/// Shared singleton instance for global access.
+ (instancetype)sharedManager;

/// Current list of banner groups fetched from Firestore.
@property (nonatomic, copy, readonly) NSArray<MainBannerModel *> *bannerGroups;

/// Start listening to the banners collection in Firestore. 
/// The completion block is called on initial load and on every update with the full list or an error.
- (void)startListeningForBannersWithCompletion:(void (^)(NSArray<MainBannerModel *> * _Nullable bannerGroups, NSError * _Nullable error))completion ;
/// Stop listening to Firestore updates (remove the snapshot listener).
- (void)stopListening;

/// Add a new banner group to Firestore.
- (void)addBannerGroup:(MainBannerModel *)bannerGroup completion:(void (^)(NSError * _Nullable error))completion;

/// Modify an existing banner group in Firestore.
- (void)updateBannerGroup:(MainBannerModel *)bannerGroup completion:(void (^)(NSError * _Nullable error))completion;

/// Delete a banner group from Firestore.
- (void)deleteBannerGroup:(MainBannerModel *)bannerGroup completion:(void (^)(NSError * _Nullable error))completion;

/// (Optional) Functions to manage individual child banners could be added here, 
/// e.g., addBannerItem:toGroup:, updateBannerItem:, deleteBannerItem: 
/// depending on app requirements.
- (void)fetchBannersOnceWithCompletion:(void (^)(NSArray<MainBannerModel *> * _Nullable bannerGroups, NSError * _Nullable error))completion ;
@end

NS_ASSUME_NONNULL_END
