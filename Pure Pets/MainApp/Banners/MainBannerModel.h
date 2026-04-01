//  MainBannerModel.h
//  Pure Pets

#import <Foundation/Foundation.h>
#import "PPBannerViewModel.h"


NS_ASSUME_NONNULL_BEGIN
// MARK: - Holder
typedef NS_ENUM(NSInteger, PPBannerHolder) {
    PPBannerHolderMainView = 0,
    PPBannerHolderAccessoriesView,
    PPBannerHolderAdsView,
    PPBannerHolderFoodView,
    PPBannerHolderVetsView
};


@interface MainBannerModel : NSObject

@property (nonatomic, copy)   NSString *bannerViewID;
@property (nonatomic, assign) BOOL bannerViewVisible;
@property (nonatomic, assign) PPBannerHolder bannerViewHolder;
@property (nonatomic, assign) PPBannerPosition bannerViewPosition;
@property (nonatomic, assign) PPBannerTransaction bannerViewTransaction;
@property (nonatomic, strong) NSArray<PPBannerViewModel *> *childBanners;

- (instancetype)initWithID:(NSString *)bannerViewID
                   visible:(BOOL)visible
                    holder:(PPBannerHolder)holder
                  position:(PPBannerPosition)position
               transaction:(PPBannerTransaction)transaction
                   banners:(NSArray<PPBannerViewModel *> *)banners NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (instancetype)init;

/// 🔥 Convert model → Firestore dictionary
- (NSDictionary *)toDictionary;

@end
NS_ASSUME_NONNULL_END
